"""DolphinUI Live Menu - shared utilities.
Internal module: no dependency on muOS task/ or emulator/rtdata/.
"""
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import threading
import time
import logging
from pathlib import Path
from typing import Optional, Dict, Any, List

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
def app_dir() -> str:
    """Absolute path to DolphinUI/ root."""
    here = Path(__file__).resolve().parent      # .../scripts/livemenu/
    return str(here.parent.parent)              # .../DolphinUI/

def script_dir() -> str:
    return str(Path(__file__).resolve().parent)

# ---------------------------------------------------------------------------
# Default config (merged with JSON on disk)
# ---------------------------------------------------------------------------
DEFAULT_CONFIG: Dict[str, Any] = {
    "watcher": {
        "menu_buttons": [8, 13],
        "start_button": 7,
        "combo_window_ms": 500,
        "menu_alone_timeout_ms": 2000,
        "kill_on_menu_alone": True,
        "poll_interval_ms": 20,
    },
    "overlay": {
        "pause_dolphin": True,
        "inject_delay_ms": 150,
        "resume_wait_ms": 300,
    },
    "paths": {
        "state_saves": "dolphin-emu/StateSaves",
        "config_dir":  "dolphin-emu/Config",
        "dolphin_ini": "dolphin-emu/Config/Dolphin.ini",
        "gfx_ini":     "dolphin-emu/Config/GFX.ini",
        "hotkeys_ini": "dolphin-emu/Config/Hotkeys.ini",
        "log":         "data/logs/livemenu.log",
    },
    "logging": {
        "level": "INFO",
    },
}

def load_config() -> Dict[str, Any]:
    """Load livemenu_config.json, merging with defaults."""
    cfg = json.loads(json.dumps(DEFAULT_CONFIG))  # deep copy
    path = os.path.join(app_dir(), "data", "livemenu_config.json")
    if os.path.exists(path):
        try:
            with open(path, "r") as f:
                user = json.load(f)
            _deep_merge(cfg, user)
        except Exception:
            pass
    return cfg

def _deep_merge(base: Dict, override: Dict) -> None:
    for k, v in override.items():
        if k in base and isinstance(base[k], dict) and isinstance(v, dict):
            _deep_merge(base[k], v)
        else:
            base[k] = v

def ensure_dir(path: str) -> None:
    try:
        os.makedirs(path, exist_ok=True)
    except Exception:
        pass

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
def setup_logging(cfg: Dict[str, Any], name: str = "livemenu") -> logging.Logger:
    log_rel = cfg.get("paths", {}).get("log", "data/logs/livemenu.log")
    log_path = os.path.join(app_dir(), log_rel)
    ensure_dir(os.path.dirname(log_path))
    level = getattr(logging, cfg.get("logging", {}).get("level", "INFO").upper(),
                    logging.INFO)
    logging.basicConfig(
        filename=log_path,
        level=level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        filemode="a",
    )
    return logging.getLogger(name)

# ---------------------------------------------------------------------------
# Process helpers
# ---------------------------------------------------------------------------
def find_dolphin_pid() -> Optional[int]:
    """Return the PID of the running Dolphin process, or None."""
    try:
        out = subprocess.check_output(
            ["pgrep", "-x", "dolphin"], text=True, stderr=subprocess.DEVNULL
        ).strip()
        if out:
            return int(out.split()[0])
    except Exception:
        pass
    # fallback: scan /proc
    try:
        for entry in os.listdir("/proc"):
            if not entry.isdigit():
                continue
            try:
                with open(f"/proc/{entry}/comm", "r") as f:
                    comm = f.read().strip()
                if comm == "dolphin":
                    return int(entry)
            except Exception:
                continue
    except Exception:
        pass
    return None

def read_dolphin_rom_from_pid(pid: int) -> Optional[str]:
    """Read cmdline of a running Dolphin to find the ROM path passed with -e."""
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            parts = f.read().split(b"\x00")
        parts = [p.decode("utf-8", "replace") for p in parts if p]
        for i, p in enumerate(parts):
            if p == "-e" and i + 1 < len(parts):
                return parts[i + 1]
    except Exception:
        pass
    return None

def extract_game_id(rom_path: str) -> str:
    """Read bytes 0-5 of a GameCube/Wii ISO to extract the game ID."""
    if not rom_path or not os.path.isfile(rom_path):
        return "UNKNOWN"
    try:
        with open(rom_path, "rb") as f:
            head = f.read(6)
        gid = "".join(chr(b) for b in head if 32 <= b < 127)
        gid = re.sub(r"[^A-Za-z0-9]", "", gid)
        return gid or "UNKNOWN"
    except Exception:
        return "UNKNOWN"

def extract_game_title(rom_path: str) -> str:
    """Read bytes 0x20-0x60 of an ISO to extract the internal game title."""
    if not rom_path or not os.path.isfile(rom_path):
        return os.path.basename(rom_path or "unknown")
    try:
        with open(rom_path, "rb") as f:
            f.seek(0x20)
            raw = f.read(64)
        title = raw.split(b"\x00")[0].decode("ascii", "replace").strip()
        return title or os.path.basename(rom_path)
    except Exception:
        return os.path.basename(rom_path or "unknown")

# ---------------------------------------------------------------------------
# Joystick helpers
# ---------------------------------------------------------------------------
JS_EVENT_BUTTON = 0x01
JS_EVENT_AXIS   = 0x02
JS_EVENT_INIT   = 0x80

def find_joystick() -> Optional[str]:
    """Return the first /dev/input/jsN path."""
    import glob
    devs = sorted(glob.glob("/dev/input/js*"))
    if devs:
        return devs[0]
    return None

def read_js_events(fd: int, size: int = 8 * 64) -> List[tuple]:
    """Read a batch of joystick events from fd.
    Returns list of (value, type, number)."""
    import select
    out = []
    try:
        r, _, _ = select.select([fd], [], [], 0)
        if not r:
            return out
        buf = os.read(fd, size)
    except Exception:
        return out
    i = 0
    while i + 8 <= len(buf):
        _time, value, etype, number = struct.unpack("IhBB", buf[i:i + 8])
        i += 8
        if etype & JS_EVENT_INIT:
            continue
        out.append((value, etype, number))
    return out

# ---------------------------------------------------------------------------
# Sound (best-effort, non-blocking, muOS-friendly)
# ---------------------------------------------------------------------------
# Per-extension player preference. Ordered: first available wins.
# `shutil.which` is called once per extension and cached.
_PLAYERS_BY_EXT: Dict[str, tuple] = {
    ".ogg":  ("ogg123", "ffplay", "pw-play", "paplay", "play"),
    ".opus": ("opusdec", "ffplay", "pw-play", "paplay", "play"),
    ".mp3":  ("mpg123", "ffplay", "pw-play", "paplay", "play"),
    ".wav":  ("aplay", "pw-play", "paplay", "play", "ffplay"),
    ".m4a":  ("ffplay", "paplay", "pw-play"),
}

_PLAYER_CACHE: Dict[str, Optional[str]] = {}
_LAST_PLAY_TIME: Dict[str, float] = {}
_PLAYER_LOCK = threading.Lock()
_MIN_INTERVAL = 0.04   # 40 ms — skip duplicate sounds played too fast

def _find_player(ext: str) -> Optional[str]:
    if ext in _PLAYER_CACHE:
        return _PLAYER_CACHE[ext]
    for cand in _PLAYERS_BY_EXT.get(ext, ()):
        p = shutil.which(cand)
        if p:
            _PLAYER_CACHE[ext] = p
            return p
    _PLAYER_CACHE[ext] = None
    return None

def _build_args(player: str, path: str) -> List[str]:
    name = os.path.basename(player)
    if name == "ffplay":
        return [player, "-nodisp", "-autoexit", "-loglevel", "quiet", path]
    if name in ("aplay", "mpg123"):
        return [player, "-q", path]
    # ogg123, opusdec, pw-play, paplay, play all accept (path)
    return [player, path]

def play_sound(name: str) -> None:
    """Play a sound from assets/sfx/ (root or wii_aud/) if it exists.
    Non-blocking, best-effort. Formats tried: ogg, mp3, wav, opus.
    Repeated calls of the same sound within ~40ms are skipped to avoid
    stacking dozens of processes during fast UI navigation."""
    try:
        # Rate limit per sound name
        now = time.time()
        with _PLAYER_LOCK:
            last = _LAST_PLAY_TIME.get(name, 0.0)
            if now - last < _MIN_INTERVAL:
                return
            _LAST_PLAY_TIME[name] = now

        base = os.path.join(app_dir(), "assets", "sfx")
        candidates = []
        for ext in (".ogg", ".mp3", ".wav", ".opus"):
            candidates.append(os.path.join(base, f"{name}{ext}"))
            candidates.append(os.path.join(base, "wii_aud", f"{name}{ext}"))

        path = None
        for c in candidates:
            if os.path.isfile(c):
                path = c
                break
        if not path:
            return

        ext = os.path.splitext(path)[1].lower()
        player = _find_player(ext)
        if not player:
            return

        try:
            subprocess.Popen(
                _build_args(player, path),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass
    except Exception:
        pass

# ---------------------------------------------------------------------------
# Save state helpers
# ---------------------------------------------------------------------------
def list_save_states(cfg: Dict[str, Any], game_id: str) -> List[Dict[str, Any]]:
    """Return a list of save state slots for the given game ID."""
    state_dir = os.path.join(app_dir(), cfg["paths"]["state_saves"])
    out: List[Dict[str, Any]] = []
    if not os.path.isdir(state_dir):
        return out
    for name in sorted(os.listdir(state_dir)):
        if not name.startswith(f"{game_id}."):
            continue
        full = os.path.join(state_dir, name)
        try:
            st = os.stat(full)
            out.append({
                "name": name,
                "path": full,
                "mtime": st.st_mtime,
                "size": st.st_size,
                "date": time.strftime("%Y-%m-%d %H:%M",
                                      time.localtime(st.st_mtime)),
            })
        except Exception:
            continue
    out.sort(key=lambda x: x["name"])
    return out

def format_size(n: int) -> str:
    if n < 1024:
        return f"{n} B"
    if n < 1024 * 1024:
        return f"{n // 1024} KB"
    return f"{n / (1024 * 1024):.1f} MB"