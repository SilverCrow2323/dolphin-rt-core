#!/usr/bin/env python3
"""Local-first Dolphin Rt:Stream PC Companion.

The browser control plane binds to loopback only. Streaming, library sync and
optional SFTP file management remain separate services.
"""
import argparse
import json
import os
import posixpath
import re
import secrets
import selectors
import shutil
import socket
import subprocess
import sys
import threading
import time
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

HERE = Path(__file__).resolve().parent
WEB = HERE / "web"
sys.path.insert(0, str(HERE))
import spdw_stream_core as core
import profiles as prof

TOKEN = secrets.token_urlsafe(32)
LOCK = threading.RLock()
TRANSFER_LOCK = threading.Lock()
JOBS = {}
JOBS_LOCK = threading.RLock()
EXTS = {".iso", ".gcm", ".rvz", ".wbfs", ".ciso", ".gcz", ".wia"}
COMPAT_URL = "https://raw.githubusercontent.com/SilverCrow2323/dolphin-rt-core/main/data/games_data.json"
CACHE_ROOT = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "spdw-stream-portal"
COMPAT_CACHE = CACHE_ROOT / "games_data.json"
ALLOWED_ASPECTS = {"auto", "4:3", "16:9", "stretch"}
ALLOWED_DISPLAY_MODES = {"", "640x480", "800x600", "1024x768", "1280x960", "1600x1200"}


def local_host_allowed(value):
    try:
        host = urlparse("//" + str(value or "")).hostname
    except ValueError:
        return False
    return host in ("127.0.0.1", "localhost")


def local_origin_allowed(value):
    if not value:
        return True
    try:
        parsed = urlparse(value)
    except ValueError:
        return False
    return (
        parsed.scheme == "http"
        and parsed.hostname in ("127.0.0.1", "localhost")
        and parsed.username is None
        and parsed.password is None
        and parsed.path in ("", "/")
        and parsed.params == ""
        and parsed.query == ""
        and parsed.fragment == ""
    )


def remote_path(value):
    value = str(value or "").strip()
    if not value.startswith("/") or any(part in (".", "..") for part in value.split("/")):
        raise ValueError("Remote paths must be absolute and cannot contain dot segments.")
    if any(c in value for c in "\r\n\x00"):
        raise ValueError("Invalid remote path.")
    return posixpath.normpath(value)


def within_remote(root, target):
    root = remote_path(root).rstrip("/") or "/"
    target = remote_path(target)
    return target == root or target.startswith(root.rstrip("/") + "/")


def device(cfg):
    d = cfg.get("device") or {}
    return {
        "host": str(d.get("host", "")),
        "port": int(d.get("port", 22)),
        "user": str(d.get("user", "")),
        "rom_path": str(d.get("rom_path", "")),
    }


def sftp_target(d):
    host = d["host"]
    if ":" in host and not host.startswith("["):
        host = "[" + host + "]"
    return d["user"] + "@" + host


def quote_path(value):
    value = str(value)
    if any(c in value for c in "\r\n\x00"):
        raise ValueError("Invalid path.")
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def sftp_command(cfg, commands, timeout=30, quiet=True):
    d = device(cfg)
    if not re.fullmatch(r"[A-Za-z0-9_.:\[\]-]{1,253}", d["host"]):
        raise ValueError("Configure a valid device host or IP.")
    if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", d["user"]):
        raise ValueError("Configure a valid SSH username.")
    if not 1 <= d["port"] <= 65535:
        raise ValueError("SFTP port must be between 1 and 65535.")
    if not shutil.which("sftp"):
        raise RuntimeError("OpenSSH sftp client is not installed.")
    args = ["sftp"]
    if quiet:
        args.append("-q")
    args += [
        "-P", str(d["port"]), "-oBatchMode=yes", "-oConnectTimeout=8",
        "-oStrictHostKeyChecking=yes", "-b", "-", sftp_target(d),
    ]
    proc = subprocess.run(
        args, input="\n".join(commands) + "\n", text=True,
        capture_output=True, timeout=timeout,
    )
    if proc.returncode:
        detail = (proc.stderr or proc.stdout or "SFTP operation failed").strip()
        raise RuntimeError(detail[-1400:])
    return proc.stdout.strip()


def sftp_canonical_directory(cfg, value):
    """Resolve a directory using portable OpenSSH SFTP cd/pwd commands."""
    path = remote_path(value)
    output = sftp_command(cfg, ["cd " + quote_path(path), "pwd"])
    matches = [line.split(":", 1)[1].strip() for line in output.splitlines()
               if line.strip().lower().startswith("remote working directory:")]
    if len(matches) != 1 or not matches[0].startswith("/"):
        raise RuntimeError("SFTP server did not return one canonical working directory.")
    return remote_path(matches[0])


def confined_remote_directory(cfg, value):
    """Return canonical (ROM root, requested directory), refusing symlink escapes."""
    root = sftp_canonical_directory(cfg, _remote_root(cfg))
    if root == "/":
        raise ValueError("The configured ROM directory resolves to the filesystem root; refusing access.")
    target = sftp_canonical_directory(cfg, value)
    if not within_remote(root, target):
        raise ValueError("The resolved remote path escapes the configured ROM directory.")
    return root, target


def remote_entry(cfg, directory, name):
    """Find one entry in a parsed long listing; fail closed on unknown listing rows."""
    raw = sftp_command(cfg, ["ls -la " + quote_path(directory)])
    entries = _parse_sftp_listing(raw, directory)
    if any(row["type"] == "unknown" for row in entries):
        raise RuntimeError("SFTP listing format is not recognised; refusing the file operation.")
    matches = [row for row in entries if row["name"] == name]
    if len(matches) > 1:
        raise RuntimeError("SFTP listing returned an ambiguous remote filename.")
    return matches[0] if matches else None


def confined_remote_file(cfg, value, allow_missing=False):
    """Confine a regular file by resolving its parent and rejecting symlink entries."""
    path = remote_path(value)
    name = posixpath.basename(path)
    if not name:
        raise ValueError("A remote ROM filename is required.")
    parent = posixpath.dirname(path) or "/"
    root, parent_real = confined_remote_directory(cfg, parent)
    entry = remote_entry(cfg, parent_real, name)
    target = posixpath.join(parent_real, name)
    if entry is None:
        if allow_missing:
            return root, target, None
        raise ValueError("The selected remote ROM does not exist.")
    if entry["type"] == "symlink":
        raise ValueError("Symbolic links are not allowed for remote ROM operations.")
    if entry["type"] != "file":
        raise ValueError("The selected remote ROM is not a regular file.")
    return root, target, entry


def _parse_sftp_listing(raw, base):
    entries = []
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("sftp>") or line.startswith("Connected to") or line.lower().startswith("total "):
            continue
        # OpenSSH's long listing has permissions, link count, owner, group, size,
        # date/time and filename. Unknown lines are preserved as non-actionable.
        cols = line.split(None, 8)
        if len(cols) < 9 or not re.match(r"^[bcdlps-][rwxStTs-]{9}", cols[0]):
            entries.append({"name": line, "path": "", "type": "unknown", "actionable": False})
            continue
        mode, size = cols[0], cols[4]
        name = cols[8]
        if name in (".", ".."):
            continue
        kind = "directory" if mode.startswith("d") else "symlink" if mode.startswith("l") else "file"
        if kind == "symlink" and " -> " in name:
            name = name.split(" -> ", 1)[0]
        safe_name = not any(c in name for c in "\r\n\x00") and name not in (".", "..")
        full = posixpath.join(base, name) if safe_name else ""
        entries.append({
            "name": name,
            "path": full,
            "type": kind,
            "size": int(size) if size.isdigit() else None,
            "actionable": bool(safe_name and kind in ("directory", "file")),
            "extension": Path(name).suffix.lower(),
        })
    return sorted(entries, key=lambda x: (x["type"] != "directory", x["name"].lower()))


def discover_devices(port=22):
    """Find known LAN neighbors and online Tailscale peers; never sweep subnets."""
    candidates = {}

    def add(host, label, source, online=True):
        host = str(host or "").strip().strip("[]")
        if not host or host in ("127.0.0.1", "::1") or not online:
            return
        item = candidates.setdefault(host, {"host": host, "name": label or host, "sources": []})
        if source not in item["sources"]:
            item["sources"].append(source)
        if label and item["name"] == host:
            item["name"] = label

    if shutil.which("ip"):
        try:
            proc = subprocess.run(["ip", "-j", "neigh", "show"], capture_output=True,
                                  text=True, timeout=4)
            if proc.returncode == 0:
                for row in json.loads(proc.stdout or "[]"):
                    raw_states = row.get("state", [])
                    states = {raw_states} if isinstance(raw_states, str) else set(raw_states)
                    if states.intersection({"FAILED", "INCOMPLETE", "NOARP"}):
                        continue
                    add(row.get("dst"), row.get("lladdr", ""), "LAN neighbor")
        except (OSError, ValueError, subprocess.TimeoutExpired):
            pass

    if shutil.which("tailscale"):
        try:
            proc = subprocess.run(["tailscale", "status", "--json"], capture_output=True,
                                  text=True, timeout=5)
            if proc.returncode == 0:
                status = json.loads(proc.stdout or "{}")
                self_ips = set((status.get("Self") or {}).get("TailscaleIPs", []))
                for peer in (status.get("Peer") or {}).values():
                    if not peer.get("Online"):
                        continue
                    name = peer.get("HostName") or peer.get("DNSName") or "Tailscale peer"
                    for address in peer.get("TailscaleIPs", []):
                        if address not in self_ips and ":" not in address:
                            add(address, name, "Tailscale")
        except (OSError, ValueError, subprocess.TimeoutExpired):
            pass

    found = []
    for item in candidates.values():
        try:
            with socket.create_connection((item["host"], int(port)), timeout=0.45):
                item["sftp_port_open"] = True
        except OSError:
            item["sftp_port_open"] = False
        found.append(item)
    return sorted(found, key=lambda x: (not x["sftp_port_open"], x["name"].lower()))


def _compat_source():
    packaged = Path("/usr/share/spdw-stream-portal/data/games_data.json")
    for candidate in (packaged, COMPAT_CACHE):
        if candidate.is_file():
            try:
                data = json.loads(candidate.read_text(encoding="utf-8"))
                if data.get("schema_version") == 2 and isinstance(data.get("games"), list):
                    return data
            except (OSError, ValueError, AttributeError):
                continue
    return None


def refresh_compatibility():
    request = urllib.request.Request(COMPAT_URL, headers={"User-Agent": "Dolphin-RtStream-PC-Companion/5"})
    with urllib.request.urlopen(request, timeout=20) as response:
        raw = response.read(24 * 1024 * 1024 + 1)
    if len(raw) > 24 * 1024 * 1024:
        raise RuntimeError("Compatibility database exceeds the 24 MiB safety limit.")
    data = json.loads(raw.decode("utf-8"))
    if data.get("schema_version") != 2 or not isinstance(data.get("games"), list):
        raise RuntimeError("Downloaded compatibility database has an unsupported schema.")
    CACHE_ROOT.mkdir(parents=True, exist_ok=True)
    temp = COMPAT_CACHE.with_suffix(".tmp")
    temp.write_bytes(raw)
    temp.replace(COMPAT_CACHE)
    return {"games": len(data["games"]), "last_update": data.get("last_update", "")}


def _compat_index():
    data = _compat_source()
    if not data:
        return {}
    out = {}
    for group in data["games"]:
        info = group.get("game_info") or {}
        game_id = str(info.get("game_id", "")).upper()
        system = str(info.get("system", "")).lower()
        if not re.fullmatch(r"[A-Z0-9]{6}", game_id):
            continue
        rows = []
        for entry in group.get("entries", []):
            review = entry.get("test_review") or {}
            if isinstance(review.get("rating"), int):
                rows.append(review["rating"])
        if rows:
            out[(game_id, system)] = {
                "reports": len(rows),
                "average_rating": round(sum(rows) / len(rows), 1),
                "rating_max": 5,
                "last_update": data.get("last_update", ""),
            }
    return out


def _library(cfg, include_compat=True):
    games = core.load_library(cfg)
    if include_compat:
        index = _compat_index()
        for game in games:
            kind = "gc" if str(game.get("kind", "")).lower() == "gc" else "wii"
            game["compatibility"] = index.get((str(game.get("id", "")).upper(), kind))
    return games


def _new_job(kind, filename, total, worker):
    job_id = uuid.uuid4().hex[:12]
    row = {
        "id": job_id, "kind": kind, "filename": filename,
        "state": "queued", "progress": 0, "progress_known": False,
        "bytes_total": int(total or 0), "message": "Queued",
        "created": time.time(), "updated": time.time(),
    }
    with JOBS_LOCK:
        JOBS[job_id] = row

    def run():
        with JOBS_LOCK:
            JOBS[job_id]["state"] = "running"
            JOBS[job_id]["message"] = "Waiting for SFTP transfer slot"
            JOBS[job_id]["updated"] = time.time()
        try:
            with TRANSFER_LOCK:
                worker(job_id)
            with JOBS_LOCK:
                JOBS[job_id]["state"] = "completed"
                JOBS[job_id]["progress"] = 100
                JOBS[job_id]["progress_known"] = True
                JOBS[job_id]["message"] = "Transfer completed"
                JOBS[job_id]["updated"] = time.time()
        except Exception as exc:
            with JOBS_LOCK:
                JOBS[job_id]["state"] = "failed"
                JOBS[job_id]["message"] = str(exc)[-1200:]
                JOBS[job_id]["updated"] = time.time()

    threading.Thread(target=run, name="rtstream-transfer-" + job_id, daemon=True).start()
    return {"job_id": job_id}


def _run_sftp_transfer(job_id, cfg, command, timeout):
    d = device(cfg)
    host = sftp_target(d)
    args = [
        "sftp", "-P", str(d["port"]), "-oBatchMode=yes", "-oConnectTimeout=8",
        "-oStrictHostKeyChecking=yes", "-b", "-", host,
    ]
    proc = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, bufsize=4096)
    try:
        proc.stdin.write((command + "\n").encode())
        proc.stdin.close()
        start = time.monotonic()
        tail = ""
        selector = selectors.DefaultSelector()
        selector.register(proc.stdout, selectors.EVENT_READ)
        while True:
            if time.monotonic() - start > timeout:
                proc.kill()
                raise TimeoutError("SFTP transfer timed out; any partial file has been retained for resume.")
            events = selector.select(timeout=0.25)
            for key, _mask in events:
                chunk = key.fileobj.read1(1024)
                if not chunk:
                    selector.unregister(key.fileobj)
                    continue
                text = chunk.decode("utf-8", "replace")
                tail = (tail + text)[-2400:]
                matches = re.findall(r"(?<!\d)(\d{1,3})%", text)
                if matches:
                    percent = max(0, min(99, int(matches[-1])))
                    with JOBS_LOCK:
                        JOBS[job_id]["progress"] = percent
                        JOBS[job_id]["progress_known"] = True
                        JOBS[job_id]["message"] = "Transferring…"
                        JOBS[job_id]["updated"] = time.time()
            if proc.poll() is not None and not selector.get_map():
                break
        selector.close()
        tail += proc.stdout.read().decode("utf-8", "replace")
        rc = proc.wait(timeout=5)
        if rc:
            raise RuntimeError(tail.strip()[-1200:] or "SFTP transfer failed.")
        return tail.strip()
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait(timeout=3)


def _remote_root(cfg):
    root = device(cfg)["rom_path"]
    if not root:
        raise ValueError("Set the handheld ROM destination path first.")
    root = remote_path(root)
    if root == "/":
        raise ValueError("Use a dedicated ROM directory; the filesystem root is not allowed.")
    return root


def _validate_remote_rom(cfg, value):
    path = remote_path(value)
    # Confinement is checked after server-side realpath resolution; a device ROM
    # root may itself be a symlink and the browser returns canonical paths.
    if Path(path).suffix.lower() not in EXTS:
        raise ValueError("Only supported GameCube/Wii ROM file extensions are allowed.")
    return path


def _validate_local_rom(cfg, value):
    src = Path(str(value or "")).expanduser().resolve(strict=True)
    if not src.is_file() or src.suffix.lower() not in EXTS:
        raise ValueError("Choose an existing GameCube/Wii ROM file.")
    roots = [Path(x).expanduser().resolve() for x in cfg.get("gc", []) + cfg.get("wii", [])]
    if not any(src == root or root in src.parents for root in roots):
        raise ValueError("ROM must be inside a configured library folder.")
    return src


def queue_upload(cfg, body):
    src = _validate_local_rom(cfg, body.get("local"))
    root = _remote_root(cfg)
    dest_dir = remote_path(body.get("remote") or root)
    try:
        resolved_root, dest_dir = confined_remote_directory(cfg, dest_dir)
    except ValueError as exc:
        raise ValueError("Upload destination must resolve inside the configured ROM directory.") from exc
    resolved_root, target, existing = confined_remote_file(
        cfg, posixpath.join(dest_dir, src.name), allow_missing=True,
    )
    exists = existing is not None
    resume = bool(body.get("resume"))
    overwrite = bool(body.get("overwrite"))
    if exists and not (resume or overwrite):
        raise ValueError("Target already exists. Choose Resume or confirm overwrite.")
    if exists and resume and overwrite:
        raise ValueError("Choose either resume or overwrite, not both.")
    command = "put " + ("-a " if resume else "") + quote_path(src) + " " + quote_path(target)

    def worker(job_id):
        _run_sftp_transfer(job_id, cfg, command, 3600)

    return _new_job("upload", src.name, src.stat().st_size, worker)


def queue_download(cfg, body):
    remote = _validate_remote_rom(cfg, body.get("remote"))
    _resolved_root, remote, _entry = confined_remote_file(cfg, remote)
    library_root = core.lib_dir(cfg).resolve()
    root = library_root / "received"
    root.mkdir(parents=True, exist_ok=True)
    if root.is_symlink() or root.resolve() != root:
        raise ValueError("The PC receive directory must not be a symbolic link.")
    name = Path(remote).name
    if name in ("", ".", ".."):
        raise ValueError("Remote ROM filename is invalid.")
    target = root / name
    partial = target.with_name(target.name + ".part")
    for candidate in (target, partial):
        if candidate.is_symlink():
            raise ValueError("Symbolic links are not allowed in the PC receive folder.")
        resolved = candidate.resolve()
        if root.resolve() not in resolved.parents:
            raise ValueError("Download destination escaped the receive folder.")
    resume = bool(body.get("resume"))
    overwrite = bool(body.get("overwrite"))
    if target.exists() and not (resume or overwrite):
        raise ValueError("Local file already exists. Choose Resume or confirm overwrite.")
    if target.exists() and resume:
        raise ValueError("The completed local file already exists; resume is only for a .part file.")
    if partial.exists() and not (resume or overwrite):
        raise ValueError("A partial download exists. Choose Resume or restart it.")
    if partial.exists() and overwrite:
        partial.unlink()
    command = "get " + ("-a " if resume else "") + quote_path(remote) + " " + quote_path(partial)

    def worker(job_id):
        _run_sftp_transfer(job_id, cfg, command, 3600)
        partial.replace(target)

    total = target.stat().st_size if target.exists() else 0
    return _new_job("download", name, total, worker)


def snapshot():
    cfg = core.load_config()
    games = _library(cfg)
    d = device(cfg)
    lib = core.lib_dir(cfg)
    lan, ts = core.lan_ip(), core.tailscale_ip()
    try:
        usage = shutil.disk_usage(lib if lib.exists() else lib.parent)
        disk = {"free": usage.free, "total": usage.total}
    except OSError:
        disk = {"free": 0, "total": 0}
    compat = _compat_source()
    return {
        "version": "5.1.0-dev",
        "sunshine": {"installed": core.sunshine_installed(), "running": core.sunshine_running()},
        "sync_server": {"running": core.server_running(), "port": int(cfg.get("port", 8765))},
        "network": {"lan": lan, "tailscale": ts, "sync_port": int(cfg.get("port", 8765))},
        "library": {
            "count": len(games), "gc": sum(g.get("kind") == "gc" for g in games),
            "wii": sum(g.get("kind") == "wii" for g in games), "path": str(lib),
            "gc_paths": cfg.get("gc", []), "wii_paths": cfg.get("wii", []), "disk": disk,
        },
        "device": {**d, "configured": bool(d["host"] and d["user"] and d["rom_path"])},
        "compatibility": {
            "available": bool(compat),
            "last_update": compat.get("last_update", "") if compat else "",
            "source": "official Rt:Core games_data.json" if compat else "not cached",
        },
        "checks": [{"label": a, "state": b, "detail": c} for a, b, c in core.system_checks(cfg)],
    }


def action(body):
    cfg = core.load_config()
    op = body.get("action")
    if op == "save-device":
        d = {
            "host": str(body.get("host", "")).strip(),
            "user": str(body.get("user", "")).strip(),
            "port": int(body.get("port", 22)),
            "rom_path": str(body.get("rom_path", "")).strip(),
        }
        if d["host"] and not re.fullmatch(r"[A-Za-z0-9_.:\[\]-]{1,253}", d["host"]):
            raise ValueError("Invalid host or IP.")
        if d["user"] and not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", d["user"]):
            raise ValueError("Invalid username.")
        if not 1 <= d["port"] <= 65535:
            raise ValueError("Invalid SFTP port.")
        if d["rom_path"]:
            remote_path(d["rom_path"])
        cfg["device"] = d
        core.save_config(cfg)
        return {"saved": True}

    if op == "save-sources":
        def dirs(key):
            out = []
            for raw in body.get(key, []):
                path = Path(str(raw).strip()).expanduser()
                if not str(raw).strip():
                    continue
                if not path.is_dir():
                    raise ValueError("ROM source folder does not exist: " + str(path))
                value = str(path.resolve())
                if value not in out:
                    out.append(value)
            return out
        cfg["gc"], cfg["wii"] = dirs("gc"), dirs("wii")
        core.save_config(cfg)
        return {"gc": len(cfg["gc"]), "wii": len(cfg["wii"])}

    if op == "discover-devices":
        port = int(body.get("port", device(cfg)["port"]))
        if not 1 <= port <= 65535:
            raise ValueError("Invalid discovery port.")
        return {"devices": discover_devices(port)}

    if op == "sftp-test":
        root = _remote_root(cfg)
        canonical_root = sftp_canonical_directory(cfg, root)
        return {"message": "Connected · ROM root " + canonical_root, "rom_path": canonical_root}

    if op == "sftp-list":
        path = remote_path(body.get("path") or _remote_root(cfg))
        try:
            _resolved_root, path = confined_remote_directory(cfg, path)
        except ValueError as exc:
            raise ValueError("Browsing is restricted to the resolved configured ROM directory.") from exc
        raw = sftp_command(cfg, ["ls -la " + quote_path(path)])
        return {"path": path, "listing": raw, "entries": _parse_sftp_listing(raw, path)}

    if op == "sftp-upload":
        return queue_upload(cfg, body)

    if op == "sftp-download":
        return queue_download(cfg, body)

    if op == "sftp-delete":
        path = _validate_remote_rom(cfg, body.get("remote"))
        if not body.get("confirm"):
            raise ValueError("Deletion requires explicit confirmation.")
        _resolved_root, path, _entry = confined_remote_file(cfg, path)
        sftp_command(cfg, ["rm " + quote_path(path)])
        return {"deleted": path}

    if op == "sftp-mkdir":
        path = remote_path(body.get("remote"))
        parent = posixpath.dirname(path)
        name = posixpath.basename(path)
        if not name or name in (".", ".."):
            raise ValueError("A new folder name is required.")
        resolved_root, resolved_parent = confined_remote_directory(cfg, parent)
        target = posixpath.join(resolved_parent, name)
        if target == resolved_root or not within_remote(resolved_root, target):
            raise ValueError("New folders must be created below the configured ROM directory.")
        sftp_command(cfg, ["mkdir " + quote_path(target)])
        return {"created": path}

    if op == "scan":
        with LOCK:
            games = core.build(cfg, refresh_covers=bool(body.get("refresh")))
        return {"count": len(games)}

    if op == "refresh-compatibility":
        return refresh_compatibility()

    if op == "set-profile":
        kind, name = str(body.get("kind", "")), str(body.get("name", ""))
        if kind not in prof.KINDS:
            raise ValueError("Unknown controller profile type.")
        prof.set_active(cfg, kind, name)
        core.save_config(cfg)
        return {"active": prof.active(cfg)}

    if op == "apply-profiles":
        if not core.install_dolphin_profiles(cfg, activate=True):
            raise RuntimeError("Profiles could not be applied. Check Dolphin state and logs.")
        return {"applied": True}

    if op == "save-stream-settings":
        aspect = str(body.get("aspect", "auto"))
        display = str(body.get("display_mode", ""))
        if aspect not in ALLOWED_ASPECTS or display not in ALLOWED_DISPLAY_MODES:
            raise ValueError("Unsupported stream display setting.")
        cfg["aspect"] = aspect
        cfg["hide_panel"] = bool(body.get("hide_panel", True))
        cfg["display_mode"] = display
        cfg["dolphin_args"] = core.FULLSCREEN_ARGS if body.get("fullscreen", True) else ""
        core.save_config(cfg)
        games = core.load_library(cfg)
        if games:
            core.update_sunshine_apps(cfg, games)
        return {"saved": True, "sunshine_entries_updated": bool(games)}

    if op == "library-server-start":
        return {"running": core.server_start()}
    if op == "library-server-stop":
        core.server_stop()
        return {"running": core.server_running()}
    if op == "sunshine-start":
        core.sunshine_start()
        return {"running": core.sunshine_running()}
    if op == "sunshine-stop":
        core.sunshine_stop()
        return {"running": core.sunshine_running()}
    if op == "sunshine-restart":
        core.sunshine_stop()
        core.sunshine_start()
        return {"running": core.sunshine_running()}
    if op == "checks":
        return {"checks": [{"label": a, "state": b, "detail": c} for a, b, c in core.system_checks(cfg)]}
    if op == "open-sunshine":
        subprocess.Popen(["xdg-open", "https://localhost:47990"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {"opened": True}
    raise ValueError("Unknown action.")


class Handler(BaseHTTPRequestHandler):
    server_version = "RtStreamPortal/5.1"

    def log_message(self, *_):
        pass

    def reply(self, code, obj):
        data = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if not local_host_allowed(self.headers.get("Host", "")):
            return self.reply(403, {"error": "Local host header required."})
        path = urlparse(self.path).path
        if path == "/api/state":
            return self.reply(200, snapshot())
        if path == "/api/library":
            return self.reply(200, {"games": _library(core.load_config())})
        if path == "/api/profiles":
            cfg = core.load_config()
            return self.reply(200, {"active": prof.active(cfg), "profiles": {
                kind: prof.available(cfg, kind) for kind in prof.KINDS
            }})
        if path == "/api/settings":
            cfg = core.load_config()
            return self.reply(200, {
                "aspect": cfg.get("aspect", "auto"),
                "display_mode": cfg.get("display_mode", "1280x960"),
                "hide_panel": bool(cfg.get("hide_panel", True)),
                "fullscreen": "Fullscreen=True" in str(cfg.get("dolphin_args", "")),
            })
        if path == "/api/jobs":
            with JOBS_LOCK:
                rows = [dict(row) for row in JOBS.values()]
            return self.reply(200, {"jobs": sorted(rows, key=lambda x: x["created"], reverse=True)[:40]})
        if path.startswith("/api/jobs/"):
            job_id = path.rsplit("/", 1)[-1]
            with JOBS_LOCK:
                row = JOBS.get(job_id)
                return self.reply(200 if row else 404, dict(row) if row else {"error": "Job not found."})
        if path not in ("/", "/app.css", "/app.js"):
            return self.send_error(404)
        target = WEB / ("index.html" if path == "/" else path.lstrip("/"))
        if not target.is_file():
            return self.send_error(404)
        data = target.read_text(encoding="utf-8").replace("__TOKEN__", TOKEN).encode() if path == "/" else target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8" if path == "/" else
                         ("text/css; charset=utf-8" if path.endswith(".css") else "text/javascript; charset=utf-8"))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        if not local_host_allowed(self.headers.get("Host", "")):
            return self.reply(403, {"error": "Local host header required."})
        if self.headers.get("X-RtStream-Token", "") != TOKEN:
            return self.reply(403, {"error": "Invalid local session."})
        if not local_origin_allowed(self.headers.get("Origin", "")):
            return self.reply(403, {"error": "Cross-origin request blocked."})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length < 0 or length > 1024 * 1024:
                raise ValueError("Invalid request size.")
            body = json.loads(self.rfile.read(length) or b"{}")
            if not isinstance(body, dict):
                raise ValueError("Invalid request.")
            return self.reply(200, {"ok": True, "result": action(body)})
        except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired, TimeoutError) as exc:
            return self.reply(400, {"ok": False, "error": str(exc)})


def main():
    parser = argparse.ArgumentParser(description="Dolphin Rt:Stream PC Companion")
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("port must be between 1 and 65535")
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.daemon_threads = True
    url = "http://127.0.0.1:%d/" % args.port
    print("Dolphin Rt:Stream PC Companion: " + url, flush=True)
    if not args.no_browser:
        import webbrowser
        webbrowser.open(url)
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
