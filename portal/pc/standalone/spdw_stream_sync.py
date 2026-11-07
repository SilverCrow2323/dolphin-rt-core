#!/usr/bin/env python3
"""
SPDW Stream Sync v2 - PC side of "Dolphin Stream" (muOS).

1. Scans the GameCube / Wii ROM folders
2. Prepares covers (file next to the ROM, otherwise GameTDB)
3. Writes library.tsv + covers/ to the output folder
4. Adds one Sunshine app per game: Dolphin starts FULLSCREEN, no desktop/panel visible,
   and (X11) the display switches to a 4:3 mode so the stream fills the handheld screen
5. (optional) serves the folder over HTTP so the handheld can download it

First time:
  python3 spdw_stream_sync.py --gc ~/roms/gc --wii ~/roms/wii --serve
Afterwards:
  python3 spdw_stream_sync.py --serve        (config is saved in <out>/config.json)
"""
import argparse, functools, http.server, json, os, re, shutil, sys, urllib.request
from pathlib import Path

IS_WIN = sys.platform.startswith("win")
EXTS = {".iso", ".gcm", ".rvz", ".wbfs", ".ciso", ".gcz", ".wia"}
REGION = {"E": "US", "P": "EN", "D": "DE", "F": "FR", "S": "ES", "I": "IT",
          "J": "JA", "K": "KO", "U": "EN", "X": "EN", "Y": "EN"}
ID_RE = re.compile(r"^[A-Z0-9]{6}$")
PREFIX = {"gc": "GC - ", "wii": "Wii - "}

# Fullscreen Dolphin: -C <System>.<Section>.<Key>=<Value> overrides Dolphin.ini for this instance
FULLSCREEN_ARGS = ("-C Dolphin.Display.Fullscreen=True "
                   "-C Dolphin.Display.RenderToMain=False "
                   "-C Dolphin.Display.KeepWindowOnTop=True "
                   "-C Dolphin.Interface.ConfirmStop=False")
DISPLAY_SCRIPT = Path(__file__).resolve().with_name("display-mode.sh")
ASPECT = {"auto": None, "16:9": 1, "4:3": 2, "stretch": 3}   # Graphics.Settings.AspectRatio


def default_sunshine():
    if IS_WIN:
        return str(Path(os.environ.get("ProgramFiles", r"C:\Program Files")) / "Sunshine" / "config" / "apps.json")
    return "~/.config/sunshine/apps.json"


DEFAULTS = {
    "gc": [], "wii": [],
    "dolphin": "Dolphin.exe" if IS_WIN else "dolphin-emu",
    "dolphin_args": FULLSCREEN_ARGS,
    "aspect": "auto",
    "display_mode": "1280x960",   # 4:3 mode while streaming ("" = keep the current mode, X11 only)
    "prep_do": "", "prep_undo": "",
    "sunshine": default_sunshine(), "port": 8765,
}


def id_from_name(name):
    m = re.search(r"[\[\(\{]([A-Z0-9]{6})[\]\)\}]", name)
    return m.group(1) if m else ""


def read_game_id(path):
    """Game ID from the disc header (iso/gcm/wbfs/rvz/wia), otherwise from [ID] in the file name."""
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


def scan(dirs, kind):
    games = []
    for d in dirs:
        root = Path(d).expanduser()
        if not root.is_dir():
            print(f"  ! folder not found: {root}")
            continue
        for p in sorted(root.rglob("*")):
            if p.is_file() and p.suffix.lower() in EXTS:
                games.append({"kind": kind, "path": p.resolve(),
                              "title": clean_title(p.stem), "id": read_game_id(p)})
    seen = {}
    for g in games:
        base = PREFIX[kind] + g["title"]
        seen[base] = seen.get(base, 0) + 1
        g["app"] = base if seen[base] == 1 else f"{base} ({seen[base]})"
        g["slug"] = slug(g["title"]) + (f"_{g['id']}" if g["id"] else "")
    return games


def shrink(path, maxh=280):
    try:
        from PIL import Image
    except ImportError:
        return
    try:
        im = Image.open(path).convert("RGBA")
        if im.height > maxh:
            im = im.resize((round(im.width * maxh / im.height), maxh), Image.LANCZOS)
        im.save(path, "PNG")
    except Exception as e:
        print(f"  ! cover could not be processed {path.name}: {e}")


def local_cover(g):
    for folder in (g["path"].parent, g["path"].parent / "covers"):
        for ext in (".png", ".jpg", ".jpeg"):
            c = folder / (g["path"].stem + ext)
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
            req = urllib.request.Request(url, headers={"User-Agent": "spdw-stream-sync/2.0"})
            with urllib.request.urlopen(req, timeout=15) as r:
                data = r.read()
            if data[:4] == b"\x89PNG":
                dest.write_bytes(data)
                return True
        except Exception:
            continue
    return False


def prepare_covers(games, out, refresh, online):
    cdir = out / "covers"
    cdir.mkdir(parents=True, exist_ok=True)
    ok = 0
    for g in games:
        dest = cdir / (g["slug"] + ".png")
        g["cover"], g["cover_abs"] = "", None
        if dest.exists() and not refresh:
            got = True
        else:
            src = local_cover(g)
            got = False
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
                        print(f"  ! {src.name}: install Pillow to use JPG covers")
            if not got and online and g["id"]:
                got = download_cover(g["id"], dest)
            if got:
                shrink(dest)
        if got:
            g["cover"], g["cover_abs"] = f"covers/{dest.name}", dest
            ok += 1
        else:
            print(f"  - no cover: {g['title']} ({g['id'] or 'no ID'})")
    return ok


def write_manifest(games, out):
    lines = ["# kind\ttitle\tapp\tcover\tid"]
    for g in games:
        lines.append(f"{g['kind']}\t{g['title']}\t{g['app']}\t{g['cover']}\t{g['id']}")
    (out / "library.tsv").write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_cmd(cfg, rom):
    """Command Sunshine runs: Dolphin in batch mode, fullscreen, no main window."""
    parts = [cfg["dolphin"], "-b", "-e", f'"{rom}"']
    extra = str(cfg.get("dolphin_args", "")).strip()
    if extra:
        parts.append(extra)
    asp = ASPECT.get(cfg.get("aspect", "auto"))
    if asp is not None:
        parts.append(f"-C Graphics.Settings.AspectRatio={asp}")
    return " ".join(parts)


def update_sunshine(cfg, games):
    p = Path(cfg["sunshine"]).expanduser()
    data = {"env": {}, "apps": []}
    if p.exists():
        data = json.loads(p.read_text(encoding="utf-8"))
        bak = p.with_name(p.name + ".bak")
        if not bak.exists():
            shutil.copyfile(p, bak)
    apps = [a for a in data.get("apps", [])
            if not str(a.get("name", "")).startswith(tuple(PREFIX.values()))]
    for g in games:
        e = {"name": g["app"], "cmd": build_cmd(cfg, g["path"]),
             "auto-detach": "true", "wait-all": "true", "exit-timeout": "5"}
        prep = []
        dm = str(cfg.get("display_mode", "")).strip()
        if dm and DISPLAY_SCRIPT.exists() and not IS_WIN:
            prep.append({"do": f'sh "{DISPLAY_SCRIPT}" set {dm}', "undo": f'sh "{DISPLAY_SCRIPT}" restore', "elevated": "false"})
        if cfg.get("prep_do"):
            prep.append({"do": cfg["prep_do"], "undo": cfg.get("prep_undo", ""), "elevated": "false"})
        if prep:
            e["prep-cmd"] = prep
        if g.get("cover_abs"):
            e["image-path"] = str(g["cover_abs"])
        apps.append(e)
    data["apps"] = apps
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, indent=4, ensure_ascii=False), encoding="utf-8")
    return p


def serve(out, port):
    class Handler(http.server.SimpleHTTPRequestHandler):
        """Only library.tsv and covers/*: config.json (with your paths) stays private."""
        def log_message(self, *a):
            pass

        def _allowed(self):
            path = self.path.split("?")[0]
            if path in ("/", "/library.tsv"):
                self.path = "/library.tsv"
                return True
            return path.startswith("/covers/") and ".." not in path

        def do_GET(self):
            if self._allowed():
                return super().do_GET()
            self.send_error(404)

        def do_HEAD(self):
            if self._allowed():
                return super().do_HEAD()
            self.send_error(404)

    handler = functools.partial(Handler, directory=str(out))
    srv = http.server.ThreadingHTTPServer(("0.0.0.0", port), handler)
    print(f"\nServing {out} on port {port} - on the handheld press SELECT in Dolphin Stream.")
    print("Ctrl+C to stop.")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nbye")


def main():
    ap = argparse.ArgumentParser(description="Dolphin Stream - PC side")
    ap.add_argument("--gc", action="append", help="GameCube ROM folder (repeatable)")
    ap.add_argument("--wii", action="append", help="Wii ROM folder (repeatable)")
    ap.add_argument("--out", default="~/spdw-stream-lib", help="output folder")
    ap.add_argument("--dolphin", help='Dolphin command (es. dolphin-emu, oppure "flatpak run org.DolphinEmu.dolphin-emu")')
    ap.add_argument("--dolphin-args", dest="dolphin_args",
                    help='extra Dolphin arguments. Default: fullscreen. "" = none (normal window)')
    ap.add_argument("--aspect", choices=list(ASPECT), help="force Dolphin's aspect ratio (default auto)")
    ap.add_argument("--display-mode", dest="display_mode",
                    help='4:3 display mode during the stream (default 1280x960); "" keeps the current mode')
    ap.add_argument("--prep-do", dest="prep_do", help="command run by Sunshine BEFORE the stream (e.g. resolution change)")
    ap.add_argument("--prep-undo", dest="prep_undo", help="command run AFTER the stream (restore resolution)")
    ap.add_argument("--sunshine", help="path of Sunshine's apps.json, or 'none'")
    ap.add_argument("--port", type=int, help="HTTP sync port")
    ap.add_argument("--serve", action="store_true", help="serve the library over HTTP when done")
    ap.add_argument("--refresh-covers", action="store_true")
    ap.add_argument("--offline", action="store_true", help="do not download covers")
    a = ap.parse_args()

    out = Path(a.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    cfg_path = out / "config.json"
    cfg = dict(DEFAULTS)
    if cfg_path.exists():
        cfg.update(json.loads(cfg_path.read_text(encoding="utf-8")))
    for k in ("gc", "wii", "dolphin", "dolphin_args", "aspect", "display_mode", "prep_do", "prep_undo", "sunshine", "port"):
        v = getattr(a, k)
        if v is not None:
            cfg[k] = v
    cfg_path.write_text(json.dumps(cfg, indent=2), encoding="utf-8")

    if not cfg["gc"] and not cfg["wii"]:
        sys.exit("No ROM folder: use --gc DIR and/or --wii DIR")

    print("Scanning ROMs...")
    games = scan(cfg["gc"], "gc") + scan(cfg["wii"], "wii")
    print(f"  {sum(g['kind'] == 'gc' for g in games)} GameCube, {sum(g['kind'] == 'wii' for g in games)} Wii")

    print("Cover...")
    n = prepare_covers(games, out, a.refresh_covers, not a.offline)
    print(f"  {n}/{len(games)} covers ready")

    write_manifest(games, out)
    print(f"Manifest: {out / 'library.tsv'}")

    if str(cfg["sunshine"]).lower() != "none":
        try:
            p = update_sunshine(cfg, games)
            print(f"Sunshine apps updated: {p}  (restart Sunshine if they do not show up)")
            if games:
                print(f"  example command: {build_cmd(cfg, games[0]['path'])}")
        except Exception as e:
            print(f"  ! could not update Sunshine apps.json: {e}")

    if a.serve:
        serve(out, int(cfg["port"]))


if __name__ == "__main__":
    main()
