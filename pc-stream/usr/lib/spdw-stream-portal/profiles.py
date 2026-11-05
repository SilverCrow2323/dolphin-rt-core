"""profiles - controller profiles for Dolphin (GCPad / Wiimote / Hotkeys).

* Packaged profiles live in <share>/dolphin-profiles/<Kind>/<name>.ini
* They are copied into Dolphin's own Profiles/<Kind>/ folder, which is the editable source of truth
* The *active* profile of each kind is written into GCPadNew.ini / WiimoteNew.ini / Hotkeys.ini
  (whole section replaced, so switching profile never leaves stale keys behind)
* Everything the handheld may change goes through set_value(), which validates names, keys and values
"""
import os
import re
import shutil
import time
from pathlib import Path

HOME = Path.home()
SELF = Path(__file__).resolve()

KINDS = {                                   # kind: (ini file, section for port 1)
    "GCPad": ("GCPadNew.ini", "GCPad1"),
    "Wiimote": ("WiimoteNew.ini", "Wiimote1"),
    "Hotkeys": ("Hotkeys.ini", "Hotkeys1"),
}
DEFAULT_ACTIVE = {"GCPad": "muos", "Wiimote": "muos", "Hotkeys": "muos"}

# only the "muos*" family can be edited or reset remotely
NAME_RE = re.compile(r"^muos[A-Za-z0-9_-]{0,24}$")
VALUE_RE = re.compile(r"^[A-Za-z0-9 +\-&`._/=,]{1,80}$")
KEY_RE = re.compile(r"^[A-Za-z0-9 +\-/_.]{1,60}$")

# values offered by the handheld editor (what the Sunshine virtual Xbox pad can send)
BUTTONS = ["SOUTH", "EAST", "WEST", "NORTH", "TL", "TR", "SELECT", "START", "MODE", "THUMBL", "THUMBR"]

SRC_DIRS = [
    Path("/usr/share/spdw-stream-portal/dolphin-profiles"),
    SELF.parent.parent.parent / "share" / "spdw-stream-portal" / "dolphin-profiles",
    SELF.parent.parent / "profiles",
    SELF.parent / "profiles",
]


def say(msg):
    print(msg, flush=True)


# ------------------------------------------------------------------ locations
def src_dir():
    for d in SRC_DIRS:
        if (d / "GCPad").is_dir():
            return d
    return None


def cfg_dir(cfg=None):
    """Folder holding Dolphin.ini / GCPadNew.ini / Profiles/ (native, Flatpak or legacy)."""
    native = HOME / ".config" / "dolphin-emu"
    flat = HOME / ".var" / "app" / "org.DolphinEmu.dolphin-emu" / "config" / "dolphin-emu"
    legacy = HOME / ".dolphin-emu" / "Config"
    order = [native, flat, legacy]
    if cfg and "flatpak" in str(cfg.get("dolphin", "")):
        order = [flat, native, legacy]
    for c in order:
        if c.is_dir():
            return c
    return order[0]


def profile_dir(cfg, kind):
    return cfg_dir(cfg) / "Profiles" / kind


def packaged(kind):
    d = src_dir()
    return sorted(p for p in (d / kind).glob("*.ini")) if d and (d / kind).is_dir() else []


# ------------------------------------------------------------------ ini helpers
def pairs(path):
    out = []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        line = line.rstrip()
        if not line or line.startswith("#") or line.startswith("["):
            continue
        if " = " in line:
            k, v = line.split(" = ", 1)
            out.append((k.strip(), v.strip()))
    return out


def ini_set(path, section, key, value):
    path = Path(path)
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    hdr = f"[{section}]"
    out, in_sec, done, found = [], False, False, False
    for l in lines:
        s = l.strip()
        if s.startswith("["):
            if in_sec and not done:
                out.append(f"{key} = {value}")
                done = True
            in_sec = (s == hdr)
            found = found or in_sec
        elif in_sec and s.split("=", 1)[0].strip() == key:
            if not done:
                out.append(f"{key} = {value}")
                done = True
            continue
        out.append(l)
    if in_sec and not done:
        out.append(f"{key} = {value}")
    if not found:
        if out and out[-1].strip():
            out.append("")
        out += [hdr, f"{key} = {value}"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(out) + "\n", encoding="utf-8")


def ini_replace_section(path, section, items):
    """Replace the whole [section] with `items` (list of (key, value)); other sections untouched."""
    path = Path(path)
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    hdr = f"[{section}]"
    out, skipping = [], False
    for l in lines:
        s = l.strip()
        if s.startswith("["):
            skipping = (s == hdr)
            if skipping:
                continue
        if not skipping:
            out.append(l)
    while out and not out[-1].strip():
        out.pop()
    if out:
        out.append("")
    out.append(hdr)
    out += [f"{k} = {v}" for k, v in items]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(out) + "\n", encoding="utf-8")


# ------------------------------------------------------------------ install / list
def install(cfg, log=say, force=False):
    """Copy packaged profiles into Dolphin's Profiles/ folder (never overwrites edits unless force)."""
    if not src_dir():
        log("! profile files not found (reinstall the package)")
        return False
    n = 0
    for kind in KINDS:
        for p in packaged(kind):
            dest = profile_dir(cfg, kind) / p.name
            if dest.exists() and not force:
                continue
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(p, dest)
            n += 1
            log(f"   profile installed: {dest}")
    if n == 0:
        log("   profiles already installed")
    return True


def installed(cfg=None):
    return all((profile_dir(cfg, k) / "muos.ini").exists() for k in KINDS if any(p.name == "muos.ini" for p in packaged(k)))


def available(cfg, kind):
    names = {p.stem for p in packaged(kind)}
    d = profile_dir(cfg, kind)
    if d.is_dir():
        names |= {p.stem for p in d.glob("*.ini")}
    return sorted(names, key=lambda n: (not n.startswith("muos"), n))


def profile_path(cfg, kind, name):
    inst = profile_dir(cfg, kind) / f"{name}.ini"
    if inst.exists():
        return inst
    for p in packaged(kind):
        if p.stem == name:
            return p
    return None


def read(cfg, kind, name):
    p = profile_path(cfg, kind, name)
    return pairs(p) if p else []


def active(cfg):
    a = dict(DEFAULT_ACTIVE)
    a.update({k: v for k, v in (cfg.get("profiles") or {}).items() if k in KINDS})
    return a


def set_active(cfg, kind, name):
    if kind not in KINDS or not profile_path(cfg, kind, name):
        raise ValueError(f"unknown profile {kind}/{name}")
    cur = dict(cfg.get("profiles") or {})
    cur[kind] = name
    cfg["profiles"] = cur
    return cfg


# ------------------------------------------------------------------ apply to Dolphin
def apply(cfg, log=say, backup=False):
    """Write the active profile of each kind into Dolphin's config. Dolphin must not be running."""
    install(cfg, log=lambda *_: None)
    base = cfg_dir(cfg)
    act = active(cfg)
    if backup:
        ts = time.strftime("%Y%m%d-%H%M%S")
        for fname in ("GCPadNew.ini", "WiimoteNew.ini", "Hotkeys.ini", "Dolphin.ini"):
            f = base / fname
            if f.exists():
                shutil.copyfile(f, base / f"{fname}.spdw-{ts}.bak")
        log(f"   backups: *.spdw-{ts}.bak")
    changed = 0
    for kind, (fname, section) in KINDS.items():
        items = read(cfg, kind, act[kind])
        if not items:
            log(f"! profile {kind}/{act[kind]} not found")
            continue
        if kind == "Wiimote":
            items = [("Source", "1")] + [kv for kv in items if kv[0] != "Source"]   # 1 = emulated Wii Remote
        before = (base / fname).read_text(encoding="utf-8") if (base / fname).exists() else ""
        ini_replace_section(base / fname, section, items)
        after = (base / fname).read_text(encoding="utf-8")
        changed += before != after
        log(f"   {kind}: {act[kind]}")
    ini_set(base / "Dolphin.ini", "Core", "SIDevice0", "6")                    # standard GC controller on port 1
    return changed


# ------------------------------------------------------------------ remote editing (validated)
def set_value(cfg, kind, name, key, value):
    """Change one existing key of a muos* profile. Raises ValueError with a short reason."""
    if kind not in KINDS:
        raise ValueError("bad kind")
    if not NAME_RE.match(name or ""):
        raise ValueError("only muos* profiles can be edited")
    if not KEY_RE.match(key or ""):
        raise ValueError("bad key")
    if not VALUE_RE.match(value or ""):
        raise ValueError("bad value")
    src = profile_path(cfg, kind, name)
    if not src:
        raise ValueError("unknown profile")
    dest = profile_dir(cfg, kind) / f"{name}.ini"
    if not dest.exists():
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dest)
    lines = dest.read_text(encoding="utf-8").splitlines()
    out, hit, old = [], False, None
    for l in lines:
        if " = " in l and not l.startswith(("#", "[")) and l.split(" = ", 1)[0].strip() == key:
            old = l.split(" = ", 1)[1].strip()
            l = f"{key} = {value}"
            hit = True
        out.append(l)
    if not hit:
        raise ValueError("unknown key")
    dest.write_text("\n".join(out) + "\n", encoding="utf-8")
    return old


def reset(cfg, kind, name):
    if kind not in KINDS or not NAME_RE.match(name or ""):
        raise ValueError("cannot reset this profile")
    for p in packaged(kind):
        if p.stem == name:
            dest = profile_dir(cfg, kind) / p.name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(p, dest)
            return True
    raise ValueError("no packaged copy to restore")


# ------------------------------------------------------------------ export for the handheld
def export_tsv(cfg):
    """profiles.tsv: '@active<TAB>kind<TAB>name' then 'kind<TAB>profile<TAB>key<TAB>value' rows."""
    lines = ["# profiles.tsv v1"]
    act = active(cfg)
    for kind in KINDS:
        lines.append(f"@active\t{kind}\t{act[kind]}")
    for kind in KINDS:
        for name in available(cfg, kind):
            for k, v in read(cfg, kind, name):
                if k == "Device":
                    continue
                lines.append(f"{kind}\t{name}\t{k}\t{v}")
    return "\n".join(lines) + "\n"


# ------------------------------------------------------------------ token for remote editing
def new_token():
    import secrets
    alphabet = "abcdefghijkmnpqrstuvwxyz23456789"
    return "".join(secrets.choice(alphabet) for _ in range(10))


def ensure_token(cfg):
    if not cfg.get("token"):
        cfg["token"] = new_token()
        return True
    return False
