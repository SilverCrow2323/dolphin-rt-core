"""DolphinUI Live Menu - key injector.
Creates a virtual keyboard via /dev/uinput and sends key combinations.
No external dependencies (uses raw ioctl).

NOTE: Dolphin must have its Hotkeys.ini configured to listen on
keyboard (Device = SDL/0/Keyboard Mouse) for these to work.
"""
import os
import struct
import fcntl
import time
import logging
from contextlib import contextmanager
from typing import Iterable

log = logging.getLogger("livemenu.injector")

UINPUT = "/dev/uinput"

# Linux input constants
EV_SYN        = 0x00
EV_KEY        = 0x01
SYN_REPORT    = 0

# ioctl numbers for uinput
UI_SET_EVBIT   = 0x40045564
UI_SET_KEYBIT  = 0x40045565
UI_DEV_CREATE  = 0x5501
UI_DEV_DESTROY = 0x5502

# Key codes we care about (Linux input-event-codes.h)
KEYMAP = {
    "ESC":   1,
    "F1":    59,  "F2": 60,  "F3": 61,  "F4": 62,
    "F5":    63,  "F6": 64,  "F7": 65,  "F8": 66,
    "F9":    67,  "F10": 68, "F11": 69, "F12": 70,
    "SHIFT": 42,
    "CTRL":  29,
    "ALT":   56,
}

def _emit(fd: int, ev_type: int, code: int, value: int) -> None:
    os.write(fd, struct.pack("llHHi", 0, 0, ev_type, code, value))

@contextmanager
def virtual_keyboard():
    """Context manager that creates a virtual keyboard device via uinput."""
    try:
        fd = os.open(UINPUT, os.O_WRONLY | os.O_NONBLOCK)
    except Exception as e:
        log.error("cannot open uinput: %s", e)
        raise
    try:
        fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
        for code in KEYMAP.values():
            fcntl.ioctl(fd, UI_SET_KEYBIT, code)

        # struct uinput_user_dev
        name = b"dolphinui-inject"
        dev = struct.pack("80sHHHHI", name, 0x03, 0x1234, 0x5678, 1, 0)
        dev += b"\x00" * (4 * 64 * 4)
        os.write(fd, dev)
        fcntl.ioctl(fd, UI_DEV_CREATE)
        time.sleep(0.12)      # let the kernel register the device
        yield fd
    finally:
        try:
            fcntl.ioctl(fd, UI_DEV_DESTROY)
        except Exception:
            pass
        try:
            os.close(fd)
        except Exception:
            pass

def send_combo(*keys: str, hold_ms: int = 60) -> bool:
    """Send a combo of named keys. Releases in reverse order."""
    codes = []
    for k in keys:
        name = k.upper()
        if name not in KEYMAP:
            log.warning("unknown key: %s", name)
            return False
        codes.append(KEYMAP[name])
    if not codes:
        return False
    try:
        with virtual_keyboard() as fd:
            for c in codes:
                _emit(fd, EV_KEY, c, 1)
            _emit(fd, EV_SYN, SYN_REPORT, 0)
            time.sleep(hold_ms / 1000.0)
            for c in reversed(codes):
                _emit(fd, EV_KEY, c, 0)
            _emit(fd, EV_SYN, SYN_REPORT, 0)
            time.sleep(0.04)
        return True
    except Exception as e:
        log.error("send_combo failed: %s", e)
        return False

# Convenience shortcuts
def save_state(n: int) -> bool:
    return send_combo("SHIFT", f"F{n}")

def load_state(n: int) -> bool:
    return send_combo(f"F{n}")

def reset_game() -> bool:
    return send_combo("SHIFT", "F5")

def toggle_fps() -> bool:
    return send_combo("F6")

def toggle_speed() -> bool:
    return send_combo("F7")

def toggle_framecount() -> bool:
    return send_combo("F8")

def toggle_input() -> bool:
    return send_combo("F9")

def toggle_pause() -> bool:
    return send_combo("F10")
