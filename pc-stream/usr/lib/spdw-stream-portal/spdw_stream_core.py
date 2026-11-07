#!/usr/bin/env python3
"""
SPDW Stream core - PC side of "Dolphin Stream" (muOS handheld).

  * scans GameCube / Wii ROM folders, prepares cover art
  * writes library.tsv + covers/ and one Sunshine app per game
  * serves the library over HTTP so the handheld can sync
  * XDG autostart helpers (Sunshine / library server / portal), optional LightDM autologin
  * Sunshine helpers (start/stop/install)

CLI:  spdw-stream {build,serve,status,autostart,autologin}
"""
import argparse, functools, getpass, http.server, json, os, re, shutil, signal
import hmac, socket, subprocess, sys, time, urllib.parse, urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import profiles as prof

VERSION = "4.1.0"
HOME = Path.home()
CONF_DIR = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "spdw-stream"
CONF_FILE = CONF_DIR / "config.json"
PID_FILE = CONF_DIR / "serve.pid"
AUTOSTART_DIR = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "autostart"
AUTOLOGIN_FILE = Path("/etc/lightdm/lightdm.conf.d/50-spdw-autologin.conf")
SELF = Path(__file__).resolve()
PANEL_SCRIPT = SELF.parent / "panel-hide.sh"
DISPLAY_SCRIPT = SELF.parent / "display-mode.sh"

EXTS = {".iso", ".gcm", ".rvz", ".wbfs", ".ciso", ".gcz", ".wia"}
REGION = {"E": "US", "P": "EN", "D": "DE", "F": "FR", "S": "ES", "I": "IT",
          "J": "JA", "K": "KO", "U": "EN", "X": "EN", "Y": "EN"}
ID_RE = re.compile(r"^[A-Z0-9]{6}$")
PREFIX = {"gc": "GC - ", "wii": "Wii - "}

# Dolphin a schermo intero, senza finestra principale: -C <Sistema>.<Sezione>.<Chiave>=<Valore>
FULLSCREEN_ARGS = ("-C Dolphin.Display.Fullscreen=True -C Dolphin.Display.RenderToMain=False "
                   "-C Dolphin.Display.KeepWindowOnTop=True -C Dolphin.Interface.ConfirmStop=False")
ASPECT = {"auto": None, "16:9": 1, "4:3": 2, "stretch": 3}   # Graphics.Settings.AspectRatio

DEFAULTS = {
    "gc": [], "wii": [],
    "dolphin": "dolphin-emu",
    "dolphin_args": FULLSCREEN_ARGS,
    "aspect": "auto",
    "hide_panel": True,
    "scan_on_start": True,          # rescan ROM folders every time the portal opens
    "display_mode": "1280x960",     # 4:3 mode while streaming ("" = keep the current mode)
    "prep_do": "", "prep_undo": "",
    "show_splash": True,
    "sunshine_apps": "~/.config/sunshine/apps.json",
    "port": 8765,
    "library": "~/.local/share/spdw-stream/library",
    "download_covers": True,
    "profiles": dict(prof.DEFAULT_ACTIVE),   # active controller profile per kind
    "token": "",                            # lets the handheld edit muos* profiles (shown in the portal)
}

AUTOSTART = {
    "sunshine": ("spdw-stream-sunshine.desktop", "SPDW Sunshine",
                 "Start Sunshine game-stream host",
                 'sh -c "pgrep -x sunshine >/dev/null || { sleep 4; exec sunshine; }"'),
    "server": ("spdw-stream-server.desktop", "SPDW Stream Library Server",
               "Refresh library + serve it to the handheld",
               "spdw-stream serve --refresh"),
    "portal": ("spdw-stream-portal.desktop", "SPDW Stream Portal",
               "Dolphin Stream Portal window",
               "spdw-stream-portal --minimized"),
}


def say(msg):
    print(msg, flush=True)


# ------------------------------------------------------------------ config
def load_config():
    cfg = json.loads(json.dumps(DEFAULTS))
    try:
        cfg.update(json.loads(CONF_FILE.read_text(encoding="utf-8")))
    except Exception:
        pass
    return cfg


def save_config(cfg):
    CONF_DIR.mkdir(parents=True, exist_ok=True)
    tmp = CONF_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(cfg, indent=2), encoding="utf-8")
    tmp.replace(CONF_FILE)


def lib_dir(cfg):
    return Path(cfg["library"]).expanduser()


# ------------------------------------------------------------------ library
def id_from_name(name):
    m = re.search(r"[\[\(\{]([A-Z0-9]{6})[\]\)\}]", name)
    return m.group(1) if m else ""


def read_game_id(path):
    ext = path.suffix.lower()
    try:
        with open(path, "rb") as f:
            if ext in (".iso", ".gcm"):
                f.seek(0)
            elif ext == ".wbfs":
                f.seek(0x200)
            elif ext in (".rvz", ".wia"):
                if f.read(4) not in (b"RVZ\x01", b"WIA\x01"):
                    raise ValueError("magic")
                f.seek(0x58)
            else:
                raise ValueError("ext")
            gid = f.read(6).decode("ascii")
        if ID_RE.match(gid):
            return gid
    except Exception:
        pass
    return id_from_name(path.stem)


def clean_title(stem):
    t = re.sub(r"\s*[\(\[\{][^)\]}]*[\)\]\}]", "", stem).strip()
    t = t.replace('"', "").replace("\t", " ")
    return t or stem


def slug(s):
    return re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_")[:48] or "game"


def scan(dirs, kind, log=say):
    games = []
    for d in dirs:
        root = Path(d).expanduser()
        if not root.is_dir():
            log(f"  ! folder not found: {root}")
            continue
        for p in sorted(root.rglob("*")):
            if p.is_file() and p.suffix.lower() in EXTS:
                games.append({"kind": kind, "path": str(p.resolve()),
                              "title": clean_title(p.stem), "id": read_game_id(p)})
    seen = {}
    for g in games:
        base = PREFIX[kind] + g["title"]
        seen[base] = seen.get(base, 0) + 1
        g["app"] = base if seen[base] == 1 else f"{base} ({seen[base]})"
        g["slug"] = slug(g["title"]) + (f"_{g['id']}" if g["id"] else "")
    return games


def shrink(path, maxh=280, log=say):
    try:
        from PIL import Image
        im = Image.open(path).convert("RGBA")
        if im.height > maxh:
            im = im.resize((round(im.width * maxh / im.height), maxh), Image.LANCZOS)
        im.save(path, "PNG")
    except Exception as e:
        log(f"  ! cover shrink failed {Path(path).name}: {e}")


def local_cover(g):
    p = Path(g["path"])
    for folder in (p.parent, p.parent / "covers"):
        for ext in (".png", ".jpg", ".jpeg"):
            c = folder / (p.stem + ext)
            if c.exists():
                return c
    return None


def download_cover(gid, dest):
    regions = []
    for r in (REGION.get(gid[3]), "US", "EN"):
        if r and r not in regions:
            regions.append(r)
    for reg in regions:
        url = f"https://art.gametdb.com/wii/cover/{reg}/{gid}.png"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "spdw-stream/" + VERSION})
            with urllib.request.urlopen(req, timeout=15) as r:
                data = r.read()
            if data[:4] == b"\x89PNG":
                dest.write_bytes(data)
                return True
        except Exception:
            continue
    return False


def prepare_covers(games, out, refresh, online, log=say):
    cdir = out / "covers"
    cdir.mkdir(parents=True, exist_ok=True)
    ok = 0
    for g in games:
        dest = cdir / (g["slug"] + ".png")
        g["cover"] = ""
        got = dest.exists() and not refresh
        if not got:
            src = local_cover(g)
            if src:
                if src.suffix.lower() == ".png":
                    shutil.copyfile(src, dest)
                    got = True
                else:
                    try:
                        from PIL import Image
                        Image.open(src).convert("RGBA").save(dest, "PNG")
                        got = True
                    except Exception:
                        log(f"  ! {src.name}: install python3-pil to use JPG covers")
            if not got and online and g["id"]:
                got = download_cover(g["id"], dest)
            if got:
                shrink(dest, log=log)
        if got:
            g["cover"] = f"covers/{dest.name}"
            ok += 1
        else:
            log(f"  - no cover: {g['title']} ({g['id'] or 'no ID'})")
    return ok


def write_manifest(games, out):
    lines = ["# kind\ttitle\tapp\tcover\tid\trom"]
    for g in games:
        lines.append("\t".join([g["kind"], g["title"], g["app"], g["cover"], g["id"], g["path"]]))
    tmp = out / "library.tsv.tmp"
    tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    tmp.replace(out / "library.tsv")


def load_library(cfg):
    """Read the manifest written by the last build (no rescan)."""
    games = []
    try:
        text = (lib_dir(cfg) / "library.tsv").read_text(encoding="utf-8")
    except Exception:
        return games
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        f = (line.split("\t") + [""] * 6)[:6]
        games.append({"kind": f[0], "title": f[1], "app": f[2], "cover": f[3],
                      "id": f[4], "path": f[5]})
    return games


def build_cmd(cfg, rom):
    """Comando eseguito da Sunshine: Dolphin in batch, a schermo intero, senza finestra principale."""
    parts = [cfg["dolphin"], "-b", "-e", f'"{rom}"']
    extra = str(cfg.get("dolphin_args", "")).strip()
    if extra:
        parts.append(extra)
    asp = ASPECT.get(cfg.get("aspect", "auto"))
    if asp is not None:
        parts.append(f"-C Graphics.Settings.AspectRatio={asp}")
    return " ".join(parts)


def prep_cmds(cfg):
    """Commands run around each stream: hide the XFCE panel, switch to a 4:3 display mode, user commands."""
    out = [{"do": f'"{sys.executable}" "{SELF}" profiles apply', "undo": "", "elevated": "false"}]
    if cfg.get("hide_panel") and PANEL_SCRIPT.exists():
        out.append({"do": f'sh "{PANEL_SCRIPT}" hide', "undo": f'sh "{PANEL_SCRIPT}" show', "elevated": "false"})
    dm = str(cfg.get("display_mode", "")).strip()
    if dm and DISPLAY_SCRIPT.exists():
        out.append({"do": f'sh "{DISPLAY_SCRIPT}" set {dm}', "undo": f'sh "{DISPLAY_SCRIPT}" restore', "elevated": "false"})
    if cfg.get("prep_do"):
        out.append({"do": cfg["prep_do"], "undo": cfg.get("prep_undo", ""), "elevated": "false"})
    return out


def update_sunshine_apps(cfg, games, log=say):
    p = Path(cfg["sunshine_apps"]).expanduser()
    data = {"env": {}, "apps": []}
    if p.exists():
        data = json.loads(p.read_text(encoding="utf-8"))
        bak = p.with_name(p.name + ".bak")
        if not bak.exists():
            shutil.copyfile(p, bak)
    apps = [a for a in data.get("apps", [])
            if not str(a.get("name", "")).startswith(tuple(PREFIX.values()))]
    out = lib_dir(cfg)
    for g in games:
        e = {"name": g["app"], "cmd": build_cmd(cfg, g["path"]),
             "auto-detach": "true", "wait-all": "true", "exit-timeout": "5"}
        prep = prep_cmds(cfg)
        if prep:
            e["prep-cmd"] = prep
        if g.get("cover"):
            e["image-path"] = str(out / g["cover"])
        apps.append(e)
    data["apps"] = apps
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_name(p.name + ".tmp")
    tmp.write_text(json.dumps(data, indent=4, ensure_ascii=False), encoding="utf-8")
    tmp.replace(p)
    log(f"   Sunshine apps.json updated ({len(games)} games): {p}")


def build(cfg, refresh_covers=False, sunshine=True, log=say):
    out = lib_dir(cfg)
    out.mkdir(parents=True, exist_ok=True)
    if not cfg["gc"] and not cfg["wii"]:
        log("! no ROM folders configured")
        return []
    log(">> scanning ROM folders")
    games = scan(cfg["gc"], "gc", log) + scan(cfg["wii"], "wii", log)
    log(f"   {sum(g['kind'] == 'gc' for g in games)} GameCube, "
        f"{sum(g['kind'] == 'wii' for g in games)} Wii")
    log(">> covers")
    n = prepare_covers(games, out, refresh_covers, cfg.get("download_covers", True), log)
    log(f"   {n}/{len(games)} covers ready")
    write_manifest(games, out)
    log(f">> manifest written: {out / 'library.tsv'}")
    if sunshine:
        try:
            update_sunshine_apps(cfg, games, log)
        except Exception as e:
            log(f"  ! Sunshine apps.json not updated: {e}")
    return games


# ------------------------------------------------------------------ server
def server_pid():
    try:
        pid = int(PID_FILE.read_text().strip())
        os.kill(pid, 0)
        if b"spdw_stream" in Path(f"/proc/{pid}/cmdline").read_bytes():
            return pid
    except Exception:
        pass
    return None


def server_running():
    return server_pid() is not None


def _port_free(port):
    """True if the TCP port is not already bound on 127.0.0.1."""
    import socket as _sock
    s = _sock.socket(_sock.AF_INET, _sock.SOCK_STREAM)
    try:
        s.setsockopt(_sock.SOL_SOCKET, _sock.SO_REUSEADDR, 1)
        s.bind(("127.0.0.1", int(port)))
        return True
    except OSError:
        return False
    finally:
        s.close()


def server_start():
    """Start the library server, wait up to 3s for it to bind the port."""
    if server_running():
        return True
    cfg = load_config()
    port = int(cfg.get("port", 8765))
    if not _port_free(port):
        say(f"! port {port} is already in use by another process")
        return False
    subprocess.Popen([sys.executable, str(SELF), "serve"], start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    import time as _t
    for _ in range(30):
        if not _port_free(port):
            return True
        _t.sleep(0.1)
    say(f"! server did not bind port {port} within 3s")
    return False


def server_stop():
    pid = server_pid()
    if pid:
        os.kill(pid, signal.SIGTERM)


def _raise_interrupt(*_):
    raise KeyboardInterrupt()


def serve(cfg, refresh=False):
    if refresh:
        try:
            build(cfg)
        except Exception as e:
            say(f"! refresh failed: {e}")
    out = lib_dir(cfg)
    out.mkdir(parents=True, exist_ok=True)

    class Quiet(http.server.SimpleHTTPRequestHandler):
        """Solo library.tsv e covers/*: config e percorsi restano privati."""
        def log_message(self, *a):
            pass

        def _allowed(self):
            path = self.path.split("?")[0]
            if path in ("/", "/library.tsv"):
                self.path = "/library.tsv"
                return True
            return path.startswith("/covers/") and ".." not in path

        def _text(self, code, body):
            data = body.encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _ctl(self):
            """Remote controller-profile editing: needs the token shown in the portal."""
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)

            def get(k):
                return (q.get(k) or [""])[0]
            live = load_config()
            tok = str(live.get("token", "")).lower()
            if not tok or not hmac.compare_digest(get("token").lower().encode(), tok.encode()):
                time.sleep(1.0)                                # slow down guessing
                return self._text(200, "ERR bad token")
            try:
                op, kind, name = get("op"), get("kind"), get("profile")
                if op == "set":
                    old = prof.set_value(live, kind, name, get("key"), get("value"))
                    msg = f"OK {get('key')}: {old} -> {get('value')}"
                elif op == "active":
                    prof.set_active(live, kind, name)
                    save_config(live)
                    msg = f"OK active {kind}: {name}"
                elif op == "reset":
                    prof.reset(live, kind, name)
                    msg = f"OK reset {kind}/{name}"
                else:
                    raise ValueError("unknown op")
            except ValueError as e:
                return self._text(200, f"ERR {e}")
            return self._text(200, msg + " (applies at the next game launch)")

        def do_GET(self):
            path = self.path.split("?")[0]
            if path == "/profiles.tsv":
                return self._text(200, prof.export_tsv(load_config()))
            if path == "/ctl":
                return self._ctl()
            if self._allowed():
                return super().do_GET()
            self.send_error(404)

        def do_HEAD(self):
            if self._allowed():
                return super().do_HEAD()
            self.send_error(404)

    handler = functools.partial(Quiet, directory=str(out))
    try:
        srv = http.server.ThreadingHTTPServer(("0.0.0.0", int(cfg["port"])), handler)
    except OSError as e:
        sys.exit(f"cannot bind port {cfg['port']}: {e}")
    CONF_DIR.mkdir(parents=True, exist_ok=True)
    PID_FILE.write_text(str(os.getpid()))
    signal.signal(signal.SIGTERM, _raise_interrupt)
    say(f"serving {out} on :{cfg['port']}")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()
        try:
            PID_FILE.unlink()
        except Exception:
            pass


# ------------------------------------------------------------------ sunshine
def sunshine_installed():
    return shutil.which("sunshine") is not None


def sunshine_running():
    return subprocess.run(["pgrep", "-x", "sunshine"], capture_output=True).returncode == 0


def sunshine_start():
    if sunshine_installed() and not sunshine_running():
        subprocess.Popen(["sunshine"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def sunshine_stop():
    subprocess.run(["pkill", "-x", "sunshine"], capture_output=True)


def debian_codename():
    try:
        major = Path("/etc/debian_version").read_text().strip().split(".")[0]
        if major.isdigit():
            return {"11": "bullseye", "12": "bookworm", "13": "trixie"}.get(major, "")
        return "trixie" if ("sid" in major or "/" in major) else ""
    except Exception:
        return ""


def sunshine_install(log=say):
    """Download the matching Sunshine .deb from GitHub and install it with pkexec/apt."""
    code = debian_codename()
    if not code:
        log("! cannot detect the Debian release - use the releases page instead")
        return False
    log(f">> looking for a Sunshine .deb for Debian {code} (amd64)")
    req = urllib.request.Request(
        "https://api.github.com/repos/LizardByte/Sunshine/releases?per_page=10",
        headers={"User-Agent": "spdw-stream/" + VERSION})
    try:
        releases = json.loads(urllib.request.urlopen(req, timeout=20).read())
    except Exception as e:
        log(f"! GitHub API error: {e}")
        return False
    pat = re.compile(rf"debian-?{code}.*amd64\.deb$")
    pick = None
    for pre in (False, True):
        for r in releases:
            if bool(r.get("prerelease")) != pre:
                continue
            for a in r.get("assets", []):
                if pat.search(a["name"]):
                    pick = a
                    break
            if pick:
                break
        if pick:
            break
    if not pick:
        log(f"! no Debian {code} amd64 package in the latest releases")
        return False
    dest = Path("/tmp") / pick["name"]
    log(f">> downloading {pick['name']}")
    try:
        with urllib.request.urlopen(pick["browser_download_url"], timeout=60) as r, open(dest, "wb") as f:
            shutil.copyfileobj(r, f)
    except Exception as e:
        log(f"! download failed: {e}")
        return False
    log(">> installing (admin password required)")
    rc = subprocess.run(["pkexec", "apt-get", "install", "-y", str(dest)]).returncode
    log("   done" if rc == 0 else f"! apt exited with {rc}")
    return rc == 0


# ------------------------------------------------------------------ autostart
def autostart_path(key):
    return AUTOSTART_DIR / AUTOSTART[key][0]


def autostart_state(key):
    return autostart_path(key).exists()


def autostart_set(key, on):
    p = autostart_path(key)
    if on:
        _, name, comment, cmd = AUTOSTART[key]
        AUTOSTART_DIR.mkdir(parents=True, exist_ok=True)
        p.write_text(
            "[Desktop Entry]\nType=Application\n"
            f"Name={name}\nComment={comment}\nExec={cmd}\n"
            "Icon=spdw-stream-portal\nTerminal=false\n"
            "X-GNOME-Autostart-enabled=true\nHidden=false\n", encoding="utf-8")
    else:
        try:
            p.unlink()
        except FileNotFoundError:
            pass


def autologin_state():
    return AUTOLOGIN_FILE.exists()


def autologin_set(on, user):
    """Needs root (the GUI calls it through pkexec)."""
    if on:
        if os.geteuid() != 0:
            sys.exit("autologin needs root (use pkexec)")
        AUTOLOGIN_FILE.parent.mkdir(parents=True, exist_ok=True)
        AUTOLOGIN_FILE.write_text(
            f"[Seat:*]\nautologin-user={user}\nautologin-user-timeout=0\n", encoding="utf-8")
    else:
        if os.geteuid() != 0 and AUTOLOGIN_FILE.exists():
            sys.exit("autologin needs root (use pkexec)")
        try:
            AUTOLOGIN_FILE.unlink()
        except FileNotFoundError:
            pass



# ------------------------------------------------------------------ dolphin profiles
def profile_src():
    return prof.src_dir()


def dolphin_cfg_dir(cfg=None):
    return prof.cfg_dir(cfg)


def dolphin_profiles_installed(cfg=None):
    return prof.installed(cfg)


def _dolphin_running():
    return subprocess.run(["pgrep", "-x", "dolphin-emu"], capture_output=True).returncode == 0


def install_dolphin_profiles(cfg, activate=False, log=say):
    """Install the packaged profiles; with activate=True also write the active ones into Dolphin's config."""
    if activate and _dolphin_running():
        log("! Dolphin is running: close it before applying profiles (it would overwrite them on exit)")
        return False
    if not prof.install(cfg, log):
        return False
    if activate:
        prof.apply(cfg, log, backup=True)
        log("   activated on GC port 1 / Wiimote 1 / Hotkeys.")
    return True


def lan_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("10.255.255.255", 1))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return ""


def tailscale_ip():
    if not shutil.which("tailscale"):
        return ""
    try:
        r = subprocess.run(["tailscale", "ip", "-4"], capture_output=True, text=True, timeout=5)
        out = r.stdout.strip().splitlines()
        return out[0] if r.returncode == 0 and out else ""
    except Exception:
        return ""


def detect_dolphin():
    if shutil.which("dolphin-emu"):
        return "dolphin-emu"
    if shutil.which("flatpak"):
        r = subprocess.run(["flatpak", "info", "org.DolphinEmu.dolphin-emu"], capture_output=True)
        if r.returncode == 0:
            return "flatpak run org.DolphinEmu.dolphin-emu"
    return ""


def system_checks(cfg):
    """List of (label, state, detail); state = ok | warn | bad."""
    res = []
    sp = shutil.which("sunshine")
    res.append(("Sunshine installed", "ok" if sp else "bad", sp or "not found"))
    res.append(("Sunshine running", "ok" if sunshine_running() else "warn", ""))
    parts = cfg["dolphin"].split()
    first = parts[0] if parts else ""
    ok = bool(first and shutil.which(first))
    res.append(("Dolphin", "ok" if ok else "bad", cfg["dolphin"] if ok else f"'{cfg['dolphin']}' not found"))
    fs = "Fullscreen=True" in str(cfg.get("dolphin_args", ""))
    res.append(("Dolphin fullscreen", "ok" if fs else "warn", "on" if fs else "off: game launches windowed"))
    if cfg.get("hide_panel"):
        xf = shutil.which("xfconf-query")
        res.append(("Hide XFCE panel", "ok" if xf else "warn", "during stream" if xf else "xfconf-query missing"))
    dm = str(cfg.get("display_mode", "")).strip()
    if shutil.which("xrandr"):
        try:
            cur = subprocess.run([str(DISPLAY_SCRIPT), "status"], capture_output=True, text=True, timeout=5).stdout.split()
            curmode = cur[1] if len(cur) > 1 else "?"
        except Exception:
            curmode = "?"
        if dm:
            res.append(("Stream display mode", "ok", f"4:3 {dm} during stream (now {curmode})"))
        else:
            w, h = (curmode.split("x") + ["0"])[:2] if "x" in curmode else ("0", "0")
            wide = w.isdigit() and h.isdigit() and int(h) > 0 and int(w) / int(h) > 1.5
            res.append(("Stream display mode", "warn" if wide else "ok",
                        f"{curmode}: 16:9 gives black bars on the handheld" if wide else curmode))
    else:
        res.append(("Stream display mode", "warn", "xrandr missing: cannot switch to 4:3"))
    ts = tailscale_ip()
    res.append(("Tailscale", "ok" if ts else "warn", ts or "not running / not installed"))
    res.append(("LAN IP", "ok" if lan_ip() else "warn", lan_ip()))
    try:
        import PIL  # noqa: F401
        res.append(("Pillow (cover resize)", "ok", "available"))
    except ImportError:
        res.append(("Pillow (cover resize)", "warn", "install python3-pil"))
    pi = dolphin_profiles_installed(cfg)
    res.append(("Dolphin profiles (muos)", "ok" if pi else "warn",
                str(dolphin_cfg_dir(cfg) / "Profiles") if pi else "not installed"))
    res.append(("pkexec (admin actions)", "ok" if shutil.which("pkexec") else "warn",
                shutil.which("pkexec") or "missing"))
    return res


# ------------------------------------------------------------------ CLI
def _default_user():
    uid = os.environ.get("PKEXEC_UID")
    if uid:
        import pwd
        return pwd.getpwuid(int(uid)).pw_name
    return getpass.getuser()


def main():
    ap = argparse.ArgumentParser(prog="spdw-stream", description="Dolphin Stream - PC side")
    sub = ap.add_subparsers(dest="cmd", required=True)

    b = sub.add_parser("build", help="scan ROMs, covers, manifest, Sunshine apps")
    b.add_argument("--gc", action="append")
    b.add_argument("--wii", action="append")
    b.add_argument("--dolphin")
    b.add_argument("--dolphin-args", dest="dolphin_args", help='default: schermo intero; "" = finestra normale')
    b.add_argument("--aspect", choices=list(ASPECT))
    b.add_argument("--display-mode", dest="display_mode", help='4:3 mode during the stream, e.g. 1280x960; "" = keep the current mode')
    b.add_argument("--hide-panel", dest="hide_panel", choices=["on", "off"])
    b.add_argument("--refresh-covers", action="store_true")
    b.add_argument("--offline", action="store_true")
    b.add_argument("--no-sunshine", action="store_true")

    s = sub.add_parser("serve", help="serve the library to the handheld")
    s.add_argument("--refresh", action="store_true", help="rebuild library first")
    s.add_argument("--port", type=int)

    sub.add_parser("status", help="system checks")

    a = sub.add_parser("autostart", help="XDG autostart entries")
    a.add_argument("action", choices=["enable", "disable", "status"])
    a.add_argument("what", choices=list(AUTOSTART) + ["all"], nargs="?", default="all")

    dp = sub.add_parser("dolphin-profiles", help="install the 'muos' GCPad/Hotkeys profiles in Dolphin")
    dp.add_argument("action", choices=["install", "activate", "status"])

    pr = sub.add_parser("profiles", help="controller profiles: list / show / apply / set / active / reset / export")
    pr.add_argument("action", choices=["list", "show", "apply", "set", "active", "reset", "export"])
    pr.add_argument("args", nargs="*", help="show KIND [NAME] | set KIND NAME KEY VALUE | active KIND NAME | reset KIND NAME")
    pr.add_argument("--backup", action="store_true", help="apply: keep *.bak copies of Dolphin's ini files")

    tk = sub.add_parser("token", help="token that lets the handheld edit profiles")
    tk.add_argument("action", choices=["show", "new"], nargs="?", default="show")

    lg = sub.add_parser("autologin", help="LightDM autologin (root)")
    lg.add_argument("action", choices=["on", "off", "status"])
    lg.add_argument("--user", default=None)

    ce = sub.add_parser("config", help="export or import config.json")
    ce.add_argument("action", choices=["export", "import"])
    ce.add_argument("file", nargs="?", help="path (export: target; import: source; default: stdout/XDG)")

    cl = sub.add_parser("cleanup", help="remove orphan files")
    cl.add_argument("what", choices=["covers"], nargs="?", default="covers")

    sub.add_parser("preflight", help="run all system checks (exit 1 on critical failure)")
    sub.add_parser("test-connection", help="ping LAN/WAN, check ports, suggest tuning")

    args = ap.parse_args()
    cfg = load_config()

    if args.cmd == "build":
        for k in ("gc", "wii", "dolphin", "dolphin_args", "aspect", "display_mode"):
            v = getattr(args, k)
            if v is not None:
                cfg[k] = v
        if args.hide_panel:
            cfg["hide_panel"] = args.hide_panel == "on"
        if args.offline:
            cfg["download_covers"] = False
        save_config(cfg)
        build(cfg, args.refresh_covers, not args.no_sunshine)
    elif args.cmd == "serve":
        if args.port:
            cfg["port"] = args.port
        serve(cfg, args.refresh)
    elif args.cmd == "status":
        for label, state, detail in system_checks(cfg):
            print(f"[{state:>4}] {label}: {detail}")
        for k in AUTOSTART:
            print(f"[{'on' if autostart_state(k) else 'off':>4}] autostart {k}")
        print(f"[{'on' if autologin_state() else 'off':>4}] LightDM autologin")
    elif args.cmd == "autostart":
        keys = list(AUTOSTART) if args.what == "all" else [args.what]
        for k in keys:
            if args.action == "status":
                print(f"{k}: {'on' if autostart_state(k) else 'off'}")
            else:
                autostart_set(k, args.action == "enable")
                print(f"{k}: {args.action}d")
    elif args.cmd == "dolphin-profiles":
        if args.action == "status":
            print("installed" if dolphin_profiles_installed(cfg) else "not installed", dolphin_cfg_dir(cfg))
        else:
            install_dolphin_profiles(cfg, args.action == "activate")
    elif args.cmd == "profiles":
        a = args.args
        try:
            if args.action == "list":
                act = prof.active(cfg)
                for kind in prof.KINDS:
                    for n in prof.available(cfg, kind):
                        print(f"{kind:8} {n:16} {'*' if act[kind] == n else ' '}")
            elif args.action == "show":
                kind = a[0]
                name = a[1] if len(a) > 1 else prof.active(cfg)[kind]
                for k, v in prof.read(cfg, kind, name):
                    print(f"{k} = {v}")
            elif args.action == "apply":
                prof.apply(cfg, backup=args.backup)
            elif args.action == "set":
                old = prof.set_value(cfg, a[0], a[1], a[2], a[3])
                print(f"{a[2]}: {old} -> {a[3]}")
            elif args.action == "active":
                prof.set_active(cfg, a[0], a[1])
                save_config(cfg)
                print(f"active {a[0]}: {a[1]}")
            elif args.action == "reset":
                prof.reset(cfg, a[0], a[1])
                print(f"reset {a[0]}/{a[1]}")
            elif args.action == "export":
                sys.stdout.write(prof.export_tsv(cfg))
        except (ValueError, IndexError, KeyError) as e:
            sys.exit(f"error: {e}")
    elif args.cmd == "token":
        if args.action == "new" or prof.ensure_token(cfg):
            if args.action == "new":
                cfg["token"] = prof.new_token()
            save_config(cfg)
        print(cfg["token"])
    elif args.cmd == "autologin":
        if args.action == "status":
            print("on" if autologin_state() else "off")
        else:
            user = args.user or _default_user()
            autologin_set(args.action == "on", user)
            print(f"autologin {args.action} ({user})")
    elif args.cmd == "config":
        if args.action == "export":
            if args.file:
                shutil.copyfile(CONF_FILE, args.file)
                say(f"exported {CONF_FILE} -> {args.file}")
            else:
                sys.stdout.write(CONF_FILE.read_text(encoding="utf-8"))
        else:
            src = Path(args.file) if args.file else None
            if not src or not src.exists():
                sys.exit(f"! file not found: {src}")
            data = json.loads(src.read_text(encoding="utf-8"))
            merged = load_config()
            merged.update(data)
            save_config(merged)
            say(f"imported {src} -> {CONF_FILE}")
    elif args.cmd == "cleanup":
        cfg = load_config()
        out = lib_dir(cfg)
        covers_dir = out / "covers"
        if not covers_dir.exists():
            sys.exit("! no covers folder")
        keep = {Path(g["cover"]).name for g in load_library(cfg) if g.get("cover")}
        removed = 0
        freed = 0
        for f in covers_dir.glob("*.png"):
            if f.name not in keep:
                freed += f.stat().st_size
                f.unlink()
                removed += 1
        say(f"removed {removed} orphan cover(s), freed {freed // 1024} KB")
    elif args.cmd == "test-connection":
        sys.exit(connection_test_print(load_config()))
    elif args.cmd == "preflight":
        cfg = load_config()
        bad = 0
        for label, state, detail in system_checks(cfg):
            mark = "OK" if state == "ok" else ("WARN" if state == "warn" else "FAIL")
            print(f"[{mark:4}] {label}: {detail}")
            if state == "bad":
                bad += 1
        if bad:
            sys.exit(f"\n! {bad} critical issue(s)")
        say("\nall critical checks passed")




# ------------------------------------------------------------------ connection test
def connection_test(cfg, log=say):
    """Test local connectivity and give tuning advice.
    Returns (checks, advice) where checks is a list of (label, state, detail)
    and advice is a list of (severity, text) suggested settings."""
    checks = []
    advice = []

    # --- 1. ping gateway (LAN)
    import subprocess, socket as _sock
    def _ping(target, count=4, timeout=1):
        try:
            r = subprocess.run(["ping", "-c", str(count), "-W", str(timeout), target],
                               capture_output=True, text=True, timeout=count * (timeout + 1) + 2)
            out = r.stdout
            import re as _re
            m = _re.search(r"rtt min/avg/max/mdev = ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+)", out)
            loss_m = _re.search(r"(\d+(?:\.\d+)?)% packet loss", out)
            if m:
                return {"min": float(m.group(1)), "avg": float(m.group(2)),
                        "max": float(m.group(3)), "loss": float(loss_m.group(1)) if loss_m else 0.0}
            return {"error": "no rtt in output"}
        except FileNotFoundError:
            return {"error": "ping not installed"}
        except subprocess.TimeoutExpired:
            return {"error": "timeout"}

    # gateway
    try:
        out = subprocess.run(["ip", "route", "show", "default"], capture_output=True, text=True, timeout=2).stdout
        gw = out.split()[2] if out and len(out.split()) > 2 else ""
    except Exception:
        gw = ""
    if gw:
        g = _ping(gw, count=3)
        if "error" in g:
            checks.append(("LAN latency (gateway)", "warn", f"ping failed: {g['error']}"))
        else:
            state = "ok" if g["avg"] < 10 and g["loss"] == 0 else ("warn" if g["avg"] < 30 else "bad")
            checks.append(("LAN latency (gateway)", state,
                           f"avg {g['avg']:.1f}ms, loss {g['loss']:.0f}%"))
            if g["avg"] > 30:
                advice.append(("warn", f"LAN latency {g['avg']:.0f}ms > 30ms: check WiFi signal or switch to wired"))
            if g["loss"] > 0:
                advice.append(("bad", f"LAN packet loss {g['loss']:.0f}%: unstable WiFi, lower bitrate"))
    else:
        checks.append(("LAN latency (gateway)", "warn", "no default gateway"))
        advice.append(("warn", "cannot detect gateway, skip LAN test"))

    # WAN
    w = _ping("8.8.8.8", count=3)
    if "error" in w:
        checks.append(("WAN latency", "warn", f"ping failed: {w['error']}"))
    else:
        state = "ok" if w["avg"] < 30 and w["loss"] == 0 else ("warn" if w["avg"] < 100 else "bad")
        checks.append(("WAN latency", state, f"avg {w['avg']:.1f}ms, loss {w['loss']:.0f}%"))
        if w["avg"] > 100:
            advice.append(("bad", f"WAN latency {w['avg']:.0f}ms > 100ms: remote play will be laggy"))

    # --- 2. porte locali
    def _port_open(port, host="127.0.0.1"):
        try:
            with _sock.create_connection((host, int(port)), timeout=0.5):
                return True
        except OSError:
            return False

    srv_ok = _port_open(cfg.get("port", 8765))
    checks.append(("Library server", "ok" if srv_ok else "bad",
                   f"port {cfg.get('port', 8765)} {'listening' if srv_ok else 'closed'}"))
    if not srv_ok:
        advice.append(("bad", "Library server not running: SERVICES ▸ START"))

    sun_ok = _port_open(47989)
    checks.append(("Sunshine", "ok" if sun_ok else "bad",
                   "port 47989 listening" if sun_ok else "port 47989 closed"))
    if not sun_ok:
        advice.append(("bad", "Sunshine not running: SERVICES ▸ START SUNSHINE"))

    # --- 3. prerequisiti
    checks.append(("Dolphin installed", "ok" if shutil.which(cfg.get("dolphin", "").split()[0]) else "bad",
                   cfg.get("dolphin", "?")))
    if not shutil.which(cfg.get("dolphin", "").split()[0]):
        advice.append(("bad", "Dolphin not found on PATH: install it"))

    installed = prof.installed(cfg)
    checks.append(("Controller profiles", "ok" if installed else "warn",
                   "installed" if installed else "not installed"))
    if not installed:
        advice.append(("warn", "Controller profiles not installed: SYSTEM ▸ CONTROLLER PROFILES ▸ INSTALL"))

    # --- 4. consigli basati su bitrate corrente vs latenza
    try:
        br = int(cfg.get("bitrate", 10000)) if isinstance(cfg.get("bitrate"), (int, str)) else 10000
    except Exception:
        br = 10000
    wan_avg = w.get("avg", 0) if "error" not in w else 0
    if wan_avg > 50 and br > 8000:
        advice.append(("warn", f"WAN latency {wan_avg:.0f}ms + bitrate {br//1000}Mbps: try lowering to 6000Mbps"))
    if wan_avg > 100 and br > 4000:
        advice.append(("bad", f"WAN latency {wan_avg:.0f}ms > 100ms: switch to 30 fps and 4000Mbps"))

    return checks, advice


def connection_test_print(cfg):
    checks, advice = connection_test(cfg)
    print("=== Connection test ===")
    for label, state, detail in checks:
        tag = "OK" if state == "ok" else ("WARN" if state == "warn" else "FAIL")
        print(f"[{tag:4}] {label}: {detail}")
    if advice:
        print("")
        print("=== Advice ===")
        for sev, text in advice:
            tag = "WARN" if sev == "warn" else ("FAIL" if sev == "bad" else "INFO")
            print(f"[{tag:4}] {text}")
    else:
        print("")
        print("No issues — settings look fine.")
    return 0 if not any(s == "bad" for _, s, _ in checks) else 1


if __name__ == "__main__":
    main()
