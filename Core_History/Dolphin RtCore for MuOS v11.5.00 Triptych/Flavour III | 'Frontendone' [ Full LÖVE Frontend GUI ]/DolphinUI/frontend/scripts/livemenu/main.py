#!/usr/bin/env python3
"""DolphinUI Live Menu — unified entry point.

Replaces the separate watcher.py + overlay.py invocations with a single
controllable process. Handles:

  * Joystick polling (MENU+START combo → open overlay, MENU alone → exit)
  * Overlay UI (curses) with save/load states, reset, quick toggles
  * Dolphin pause/resume via SIGSTOP/SIGCONT
  * Key injection via uinput (save states, reset, toggles)

Modes:
  daemon   (default) — watcher loop; spawns the overlay in-process when
                       the combo fires. This is what launch_game.sh calls.
  watch              — watcher only (debug)
  overlay            — attach to a running Dolphin PID and open the UI
  test               — no Dolphin, no uinput; prints events as they come

Usage:
  python3 main.py daemon --dolphin-pid 1234
  python3 main.py watch
  python3 main.py overlay --dolphin-pid 1234
  python3 main.py test

Environment:
  DOLPHINUI_LOG   — override log path (default: <app>/data/logs/livemenu.log)
  DOLPHINUI_DEBUG — set to 1 for verbose logging
"""

from __future__ import annotations

import argparse
import atexit
import curses
import logging
import os
import select
import signal
import struct
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

# ── Path bootstrap ────────────────────────────────────────────
_THIS = Path(__file__).resolve()
_SCRIPTS_DIR = _THIS.parent
_APP_DIR = _SCRIPTS_DIR.parent.parent
sys.path.insert(0, str(_SCRIPTS_DIR))

# Local modules (same directory)
try:
    from common import (
        load_config, setup_logging, find_dolphin_pid,
        find_joystick, app_dir, ensure_dir,
        play_sound, list_save_states, format_size,
        JS_EVENT_BUTTON, JS_EVENT_INIT,
    )
except ImportError as e:
    print(f"FATAL: cannot import common.py from {_SCRIPTS_DIR}: {e}",
          file=sys.stderr)
    sys.exit(2)

try:
    import injector
except ImportError:
    injector = None

log = logging.getLogger("livemenu.main")

# ── Constants ─────────────────────────────────────────────────
BTN_A      = 3
BTN_B      = 4
BTN_Y      = 5
BTN_X      = 6
BTN_L1     = 7
BTN_R1     = 8
BTN_SELECT = 9
BTN_START  = 10
BTN_MENU   = 11
BTN_L2     = 13
BTN_R2     = 14

HAT_UP, HAT_RIGHT, HAT_DOWN, HAT_LEFT = 1, 2, 4, 8

C_TITLE, C_SELECT, C_ACTIVE, C_INFO = 1, 2, 3, 4
C_WARN,  C_DIM,   C_OK,     C_FOOTER = 5, 6, 7, 8


def init_colors():
    curses.start_color()
    curses.use_default_colors()
    curses.init_pair(C_TITLE,  curses.COLOR_YELLOW, -1)
    curses.init_pair(C_SELECT, curses.COLOR_BLACK,  curses.COLOR_YELLOW)
    curses.init_pair(C_ACTIVE, curses.COLOR_BLACK,  curses.COLOR_GREEN)
    curses.init_pair(C_INFO,   curses.COLOR_CYAN,   -1)
    curses.init_pair(C_WARN,   curses.COLOR_RED,    -1)
    curses.init_pair(C_DIM,    curses.COLOR_WHITE,  -1)
    curses.init_pair(C_OK,     curses.COLOR_GREEN,  -1)
    curses.init_pair(C_FOOTER, curses.COLOR_YELLOW, -1)


# ═══════════════════════════════════════════════════════════════
#  DOLPHIN CONTROLLER (pause / resume / terminate)
# ═══════════════════════════════════════════════════════════════
class DolphinController:
    """Manages the Dolphin process lifecycle."""

    def __init__(self, pid: Optional[int], cfg: dict):
        self.pid = pid
        self.cfg = cfg
        self.paused = False
        self._restored = False

    def is_alive(self) -> bool:
        if not self.pid:
            return False
        try:
            os.kill(self.pid, 0)
            return True
        except ProcessLookupError:
            return False
        except PermissionError:
            return True

    def pause(self) -> bool:
        if self.paused or not self.cfg["overlay"]["pause_dolphin"]:
            return True
        if not self.is_alive():
            return False
        try:
            os.kill(self.pid, signal.SIGSTOP)
            self.paused = True
            log.info("dolphin %d paused", self.pid)
            return True
        except Exception as e:
            log.error("pause failed: %s", e)
            return False

    def resume(self) -> bool:
        if not self.paused:
            return True
        if not self.is_alive():
            self.paused = False
            return False
        try:
            os.kill(self.pid, signal.SIGCONT)
            self.paused = False
            log.info("dolphin %d resumed", self.pid)
            return True
        except Exception as e:
            log.error("resume failed: %s", e)
            return False

    def terminate(self, force: bool = False) -> None:
        if not self.is_alive():
            return
        self.resume()
        time.sleep(0.05)
        sig = signal.SIGKILL if force else signal.SIGTERM
        try:
            os.kill(self.pid, sig)
            log.info("sent signal %s to %d", sig, self.pid)
        except Exception as e:
            log.error("terminate failed: %s", e)
        self._restored = True

    def restore(self) -> None:
        """Called on process exit. Resumes Dolphin if we left it paused."""
        if self._restored:
            return
        self._restored = True
        if self.paused:
            self.resume()


# ═══════════════════════════════════════════════════════════════
#  JOYSTICK READER
# ═══════════════════════════════════════════════════════════════
class Joystick:
    def __init__(self):
        self.path: Optional[str] = None
        self.fd: Optional[int] = None
        self.btn_state: dict[int, int] = {}

    def open(self) -> bool:
        self.path = find_joystick()
        if not self.path:
            log.error("no joystick device found")
            return False
        try:
            self.fd = os.open(self.path, os.O_RDONLY | os.O_NONBLOCK)
            log.info("opened joystick %s", self.path)
            return True
        except Exception as e:
            log.error("cannot open %s: %s", self.path, e)
            return False

    def close(self) -> None:
        if self.fd is not None:
            try:
                os.close(self.fd)
            except Exception:
                pass
            self.fd = None

    def read_events(self, timeout: float = 0.02) -> list[tuple[int, int]]:
        """Returns [(button, value), ...] for button events only.
        Auto-reopens the device on EOF (unplug/replug)."""
        if self.fd is None:
            return []
        try:
            r, _, _ = select.select([self.fd], [], [], timeout)
            if not r:
                return []
            buf = os.read(self.fd, 8 * 64)
        except OSError as e:
            log.warning("joystick read error: %s — reopening", e)
            self.close()
            time.sleep(0.5)
            self.open()
            return []
        except Exception:
            return []

        if not buf:
            log.warning("joystick EOF — reopening")
            self.close()
            time.sleep(0.5)
            self.open()
            return []

        events = []
        i = 0
        while i + 8 <= len(buf):
            _t, value, etype, number = struct.unpack("IhBB", buf[i:i + 8])
            i += 8
            if etype & JS_EVENT_INIT:
                continue
            if (etype & 0x7F) == JS_EVENT_BUTTON:
                self.btn_state[number] = value
                events.append((number, value))
        return events

    def drain(self, timeout: float = 0.1) -> None:
        """Consume pending events (used after overlay returns)."""
        deadline = time.time() + timeout
        while time.time() < deadline:
            events = self.read_events(timeout=0.02)
            if not events:
                return


# ═══════════════════════════════════════════════════════════════
#  WATCHER (background daemon)
# ═══════════════════════════════════════════════════════════════
class Watcher:
    """Watches for MENU+START combo and MENU-alone exit."""

    def __init__(self, cfg: dict, joy: Joystick, dolphin: DolphinController):
        self.cfg = cfg
        self.joy = joy
        self.dolphin = dolphin

        self.menu_btns = set(int(b) for b in cfg["watcher"]["menu_buttons"])
        self.start_btn = int(cfg["watcher"]["start_button"])
        self.alone_timeout = cfg["watcher"]["menu_alone_timeout_ms"] / 1000.0
        self.kill_on_alone = cfg["watcher"]["kill_on_menu_alone"]

        self.menu_armed = False
        self.menu_down_at = 0.0
        self.combo_fired = False
        self._running = True

    def stop(self, *_):
        self._running = False

    def _menu_down(self) -> bool:
        return any(self.joy.btn_state.get(b, 0) == 1 for b in self.menu_btns)

    def poll(self) -> Optional[str]:
        """Process one batch of events. Returns an action string:
        'combo' (open overlay), 'exit' (kill dolphin), or None."""
        for btn, value in self.joy.read_events():
            is_menu  = btn in self.menu_btns
            is_start = (btn == self.start_btn)

            if is_menu and value == 1:
                if not self.menu_armed and not self.combo_fired:
                    self.menu_armed = True
                    self.menu_down_at = time.time()
                continue

            if is_start and value == 1 and self._menu_down():
                if not self.combo_fired:
                    self.combo_fired = True
                    self.menu_armed = False
                    return "combo"
                continue

            if is_menu and value == 0 and not self._menu_down():
                if self.menu_armed and not self.combo_fired:
                    dt = time.time() - self.menu_down_at
                    if self.kill_on_alone and dt <= self.alone_timeout:
                        self.menu_armed = False
                        self.combo_fired = False
                        return "exit"
                self.menu_armed = False
                self.combo_fired = False

        return None

    def reset(self) -> None:
        self.menu_armed = False
        self.combo_fired = False
        self.joy.btn_state.clear()


# ═══════════════════════════════════════════════════════════════
#  OVERLAY (curses UI)
# ═══════════════════════════════════════════════════════════════
class Overlay:
    MAIN_MENU = [
        ("Save State",       "save"),
        ("Load State",       "load"),
        ("Reset Game",       "reset"),
        ("Quick Toggles",    "toggle"),
        ("Exit to Frontend", "exit"),
        ("Close Emulator",   "kill"),
    ]
    TOGGLES = [
        ("FPS Counter",    "fps"),
        ("Speed %",        "speed"),
        ("Frame Counter",  "framecount"),
        ("Input Display",  "input"),
        ("Pause / Resume", "pause"),
    ]

    def __init__(self, dolphin: DolphinController, cfg: dict, joy: Joystick):
        self.dolphin = dolphin
        self.cfg = cfg
        self.joy = joy

        self.state = "MAIN"
        self.sel = 0
        self.running = True
        self.exit_code = 0
        self.dirty = True
        self.confirm_action = None
        self.confirm_msg = ""
        self.message = ""
        self.message_until = 0.0

        # Metadata
        self.rom_path = self._read_rom()
        self.game_id, self.game_title = self._read_game_info()
        self.save_slots = self._scan_saves()
        self.start_time = time.time()

    # ── Metadata ─────────────────────────────────────────────
    def _read_rom(self) -> str:
        if not self.dolphin.pid:
            return ""
        try:
            with open(f"/proc/{self.dolphin.pid}/cmdline", "rb") as f:
                parts = f.read().split(b"\x00")
            parts = [p.decode("utf-8", "replace") for p in parts if p]
            for i, p in enumerate(parts):
                if p == "-e" and i + 1 < len(parts):
                    return parts[i + 1]
        except Exception:
            pass
        return ""

    def _read_game_info(self) -> tuple[str, str]:
        from common import extract_game_id, extract_game_title
        return (
            extract_game_id(self.rom_path) if self.rom_path else "UNKNOWN",
            extract_game_title(self.rom_path) if self.rom_path else "Unknown",
        )

    def _scan_saves(self) -> list[dict]:
        if self.game_id == "UNKNOWN":
            return []
        all_slots = list_save_states(self.cfg, self.game_id)
        by_slot: dict[int, dict] = {}
        for s in all_slots:
            m = s["name"].rsplit(".s", 1)
            if len(m) == 2 and m[1].isdigit():
                by_slot[int(m[1])] = s
        return [by_slot[n] for n in (1, 2, 3) if n in by_slot]

    # ── Actions ──────────────────────────────────────────────
    def _flash(self, msg: str, secs: float = 1.6) -> None:
        self.message = msg
        self.message_until = time.time() + secs
        self.dirty = True

    def _go_back(self) -> None:
        if self.state == "CONFIRM":
            self.state = "MAIN"; self.sel = 0; self.dirty = True
            return
        if self.state in ("SAVE", "LOAD", "TOGGLE"):
            self.state = "MAIN"; self.sel = 0; self.dirty = True
            play_sound("HOMESE_CANCEL")
            return
        self.exit_code = 0
        self.running = False

    def _activate(self) -> None:
        if self.state == "MAIN":
            key = self.MAIN_MENU[self.sel][1]
            if key == "save":
                self.state = "SAVE"; self.sel = 0; self.dirty = True
            elif key == "load":
                self.state = "LOAD"; self.sel = 0; self.dirty = True
            elif key == "toggle":
                self.state = "TOGGLE"; self.sel = 0; self.dirty = True
            elif key == "reset":
                self.confirm_action = "reset"
                self.confirm_msg = "Reset the game?\nUnsaved progress will be lost."
                self.state = "CONFIRM"; self.sel = 0; self.dirty = True
            elif key == "exit":
                self.exit_code = 0
                self.running = False
                self.dolphin.terminate(force=False)
            elif key == "kill":
                self.confirm_action = "kill"
                self.confirm_msg = "Force-close the emulator?"
                self.state = "CONFIRM"; self.sel = 0; self.dirty = True

        elif self.state == "SAVE":
            if self.sel < 3:
                if injector and injector.save_state(self.sel + 1):
                    self._flash(f"Saved to slot {self.sel + 1}")
                    play_sound("WIIL_SE_COPY_FINISH")
                    self.save_slots = self._scan_saves()
                else:
                    self._flash("Save failed")
            else:
                self._go_back()

        elif self.state == "LOAD":
            if self.sel < 3:
                if injector and injector.load_state(self.sel + 1):
                    self._flash(f"Loaded slot {self.sel + 1}")
                    play_sound("WIIL_SE_BOARD_SELECT")
            else:
                self._go_back()

        elif self.state == "TOGGLE":
            if self.sel < len(self.TOGGLES):
                fn_name = self.TOGGLES[self.sel][1]
                fn = getattr(injector, f"toggle_{fn_name}", None) if injector else None
                if fn:
                    fn()
                    self._flash("Toggled")
                    play_sound("WIIL_SE_BOARD_SELECT")
            else:
                self._go_back()

        elif self.state == "CONFIRM":
            if self.sel == 0:
                if self.confirm_action == "reset":
                    self.dolphin.resume()
                    time.sleep(0.15)
                    if injector:
                        injector.reset_game()
                    time.sleep(0.4)
                    self.dolphin.pause()
                    self._flash("Game reset")
                elif self.confirm_action == "kill":
                    self.dolphin.terminate(force=True)
                    self.exit_code = 1
                    self.running = False
            self.state = "MAIN"; self.sel = 0; self.confirm_action = None
            self.dirty = True

    def _move(self, delta: int) -> None:
        if self.state == "MAIN":
            n = len(self.MAIN_MENU)
        elif self.state in ("SAVE", "LOAD"):
            n = 4
        elif self.state == "TOGGLE":
            n = len(self.TOGGLES) + 1
        elif self.state == "CONFIRM":
            n = 2
        else:
            return
        old = self.sel
        self.sel = (self.sel + delta) % n
        if self.sel != old:
            play_sound("WSD_SELECT")
            self.dirty = True

    # ── Rendering ────────────────────────────────────────────
    def render(self, stdscr) -> None:
        stdscr.erase()
        h, w = stdscr.getmaxyx()
        try:
            self._draw_header(stdscr, w)
            if self.state == "MAIN":      self._draw_main(stdscr)
            elif self.state == "SAVE":    self._draw_slots(stdscr, w, "save")
            elif self.state == "LOAD":    self._draw_slots(stdscr, w, "load")
            elif self.state == "TOGGLE":  self._draw_toggles(stdscr)
            elif self.state == "CONFIRM": self._draw_confirm(stdscr, h, w)
            self._draw_footer(stdscr, h, w)
            self._draw_flash(stdscr, h, w)
        except curses.error:
            pass
        stdscr.noutrefresh()
        curses.doupdate()
        self.dirty = False

    def _draw_header(self, s, w: int) -> None:
        title = " DOLPHINUI  ·  LIVE MENU "
        try:
            s.addstr(0, max(0, (w - len(title)) // 2), title,
                     curses.color_pair(C_TITLE) | curses.A_BOLD)
        except curses.error:
            pass
        try:
            s.addstr(1, 0, "─" * w, curses.color_pair(C_DIM))
        except curses.error:
            pass

        gline = f"  {self.game_title[:44]:<44} {self.game_id:>8}  "
        try:
            s.addstr(2, 0, gline, curses.color_pair(C_INFO))
        except curses.error:
            pass

        elapsed = int(time.time() - self.start_time)
        mm, ss = divmod(elapsed, 60)
        hh, mm = divmod(mm, 60)
        status = f"  Playing {hh:02d}:{mm:02d}:{ss:02d}  ·  PID {self.dolphin.pid}  "
        try:
            s.addstr(3, 0, status, curses.color_pair(C_DIM))
        except curses.error:
            pass

        try:
            s.addstr(4, 0, "─" * w, curses.color_pair(C_DIM))
        except curses.error:
            pass

    def _draw_main(self, s) -> None:
        y0 = 6
        for i, (label, _) in enumerate(self.MAIN_MENU):
            y = y0 + i
            if i == self.sel:
                s.addstr(y, 8, "▶  " + label.ljust(34),
                         curses.color_pair(C_SELECT) | curses.A_BOLD)
            else:
                s.addstr(y, 8, "   " + label.ljust(34),
                         curses.color_pair(C_DIM))

    def _draw_slots(self, s, w: int, mode: str) -> None:
        title = "SAVE STATE" if mode == "save" else "LOAD STATE"
        s.addstr(6, 4, title, curses.color_pair(C_TITLE) | curses.A_BOLD)

        for i in range(3):
            y = 8 + i * 2
            info = None
            for slot in self.save_slots:
                if slot["name"].endswith(f".s{i+1:03d}"):
                    info = slot
                    break
            focused = (i == self.sel)
            right = f"{info['date']}  {format_size(info['size'])}" if info else "(empty)"
            line = f"  Slot {i+1}".ljust(12) + right
            if focused:
                s.addstr(y, 6, "▶ " + line.ljust(w - 12),
                         curses.color_pair(C_SELECT) | curses.A_BOLD)
            else:
                s.addstr(y, 6, "  " + line, curses.color_pair(C_DIM))

        y = 8 + 3 * 2 + 1
        focused = (self.sel == 3)
        if focused:
            s.addstr(y, 6, "▶  Back".ljust(w - 12),
                     curses.color_pair(C_SELECT) | curses.A_BOLD)
        else:
            s.addstr(y, 6, "   Back", curses.color_pair(C_DIM))

    def _draw_toggles(self, s) -> None:
        s.addstr(6, 4, "QUICK TOGGLES", curses.color_pair(C_TITLE) | curses.A_BOLD)
        for i, (label, _) in enumerate(self.TOGGLES):
            y = 8 + i
            focused = (i == self.sel)
            line = "▶  " + label.ljust(34) if focused else "   " + label
            pair = (C_SELECT | curses.A_BOLD) if focused else C_DIM
            s.addstr(y, 6, line, curses.color_pair(pair))
        y = 8 + len(self.TOGGLES) + 1
        focused = (self.sel == len(self.TOGGLES))
        line = "▶  Back".ljust(34) if focused else "   Back"
        pair = (C_SELECT | curses.A_BOLD) if focused else C_DIM
        s.addstr(y, 6, line, curses.color_pair(pair))

    def _draw_confirm(self, s, h: int, w: int) -> None:
        lines = self.confirm_msg.split("\n")
        box_w = max(len(l) for l in lines) + 6
        box_w = max(box_w, 40)
        box_h = len(lines) + 4
        x0 = max(2, (w - box_w) // 2)
        y0 = max(6, (h - box_h) // 2)

        s.addstr(y0, x0, "┌" + "─" * (box_w - 2) + "┐", curses.color_pair(C_WARN))
        for i, l in enumerate(lines):
            s.addstr(y0 + 1 + i, x0, "│ " + l.ljust(box_w - 4) + " │",
                     curses.color_pair(C_WARN))
        y_btn = y0 + 1 + len(lines) + 1
        yes, no = "[ YES ]", "[ NO ]"
        gap = 6
        bx = x0 + (box_w - (len(yes) + gap + len(no))) // 2
        for i, label in enumerate((yes, no)):
            pos = bx + i * (len(yes) + gap)
            pair = (C_SELECT | curses.A_BOLD) if self.sel == i else C_DIM
            s.addstr(y_btn, pos, label, curses.color_pair(pair))
        s.addstr(y0 + box_h - 1, x0, "└" + "─" * (box_w - 2) + "┘",
                 curses.color_pair(C_WARN))

    def _draw_footer(self, s, h: int, w: int) -> None:
        try:
            s.addstr(h - 2, 0, "─" * w, curses.color_pair(C_DIM))
        except curses.error:
            pass
        hints = "[D-Pad] Navigate   [A] Select   [B] Back   [START] Resume"
        try:
            s.addstr(h - 1, max(0, (w - len(hints)) // 2), hints,
                     curses.color_pair(C_FOOTER) | curses.A_BOLD)
        except curses.error:
            pass

    def _draw_flash(self, s, h: int, w: int) -> None:
        if not self.message or time.time() > self.message_until:
            return
        try:
            s.addstr(h - 3, max(0, (w - len(self.message)) // 2),
                     self.message, curses.color_pair(C_OK) | curses.A_BOLD)
        except curses.error:
            pass

    # ── Main loop ────────────────────────────────────────────
    def run(self, stdscr) -> int:
        curses.curs_set(0)
        init_colors()
        stdscr.nodelay(True)
        stdscr.keypad(True)

        self.dolphin.pause()

        last_draw = 0.0
        while self.running:
            now = time.time()
            if self.dirty or (now - last_draw) > 0.5:
                self.render(stdscr)
                last_draw = now

            # Keyboard fallback (useful for testing via SSH)
            ch = stdscr.getch()
            if ch != -1:
                if ch in (curses.KEY_UP, ord('w')):     self._move(-1)
                elif ch in (curses.KEY_DOWN, ord('s')): self._move(1)
                elif ch in (10, 13, ord(' '), ord('a'), ord('A')): self._activate()
                elif ch in (27, ord('b'), ord('B'), ord('q')):     self._go_back()

            # Joystick events
            for btn, value in self.joy.read_events():
                if value != 1:
                    continue
                if btn == BTN_B:
                    self._go_back()
                elif btn == BTN_START:
                    self.exit_code = 0
                    self.running = False
                elif btn in (BTN_A, BTN_MENU):
                    self._activate()
                elif btn == BTN_L1:
                    if self.state == "CONFIRM":
                        self.sel = 0; self.dirty = True
                elif btn == BTN_R1:
                    if self.state == "CONFIRM":
                        self.sel = 1; self.dirty = True
                elif btn in (BTN_X, BTN_Y):
                    self._move(1 if btn == BTN_Y else -1)

            time.sleep(0.02)

        if self.exit_code == 1:
            self.dolphin.terminate(force=True)
        else:
            self.dolphin.resume()
        return self.exit_code


# ═══════════════════════════════════════════════════════════════
#  CLI ENTRY POINTS
# ═══════════════════════════════════════════════════════════════
def cmd_daemon(args) -> int:
    """Watcher loop + in-process overlay spawn."""
    cfg = load_config()

    dolphin = DolphinController(args.dolphin_pid, cfg)
    if not dolphin.is_alive():
        log.error("dolphin PID %s not running", args.dolphin_pid)
        return 1

    joy = Joystick()
    if not joy.open():
        return 1

    watcher = Watcher(cfg, joy, dolphin)

    def on_signal(signum, _frame):
        log.info("signal %d received, stopping", signum)
        watcher.stop()

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT,  on_signal)

    log.info("daemon starting (pid=%d)", args.dolphin_pid)
    try:
        while watcher._running:
            action = watcher.poll()
            if action == "combo":
                log.info("combo detected — pausing dolphin and opening overlay")
                dolphin.pause()
                joy.drain()
                rc = _run_overlay(dolphin, cfg, joy)
                if rc == 1:
                    log.info("overlay requested termination")
                    dolphin.terminate(force=False)
                    break
                watcher.reset()
            elif action == "exit":
                log.info("MENU alone — terminating dolphin")
                dolphin.terminate(force=False)
                break
            time.sleep(0.02)
    finally:
        joy.close()
        dolphin.restore()
    return 0


def _run_overlay(dolphin, cfg, joy) -> int:
    overlay = Overlay(dolphin, cfg, joy)
    try:
        return curses.wrapper(overlay.run) or 0
    except Exception as e:
        log.error("overlay crashed: %s", e)
        dolphin.resume()
        return 0


def cmd_watch(args) -> int:
    """Watcher only — for debugging."""
    cfg = load_config()
    dolphin = DolphinController(args.dolphin_pid, cfg)
    joy = Joystick()
    if not joy.open():
        return 1
    watcher = Watcher(cfg, joy, dolphin)

    signal.signal(signal.SIGTERM, watcher.stop)
    signal.signal(signal.SIGINT, watcher.stop)

    try:
        while watcher._running:
            action = watcher.poll()
            if action:
                print(f"ACTION: {action}")
            time.sleep(0.02)
    finally:
        joy.close()
    return 0


def cmd_overlay(args) -> int:
    """Overlay only — attach to a running Dolphin PID."""
    cfg = load_config()
    dolphin = DolphinController(args.dolphin_pid, cfg)
    if not dolphin.is_alive():
        log.error("dolphin PID %s not running", args.dolphin_pid)
        return 1
    joy = Joystick()
    joy.open()
    try:
        return _run_overlay(dolphin, cfg, joy)
    finally:
        joy.close()
        dolphin.restore()


def cmd_test(args) -> int:
    """No Dolphin, no uinput — prints joystick events as they come."""
    cfg = load_config()
    joy = Joystick()
    if not joy.open():
        return 1
    log.info("test mode — press buttons. Ctrl+C to exit.")
    try:
        while True:
            events = joy.read_events(timeout=0.2)
            for btn, value in events:
                names = {
                    3: "A", 4: "B", 5: "Y", 6: "X",
                    7: "L1", 8: "R1", 9: "SELECT", 10: "START",
                    11: "MENU", 13: "L2", 14: "R2",
                }
                name = names.get(btn, f"#{btn}")
                print(f"  {name:<8} value={value}")
    except KeyboardInterrupt:
        pass
    finally:
        joy.close()
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="mode", required=False)

    p_daemon = sub.add_parser("daemon", help="watcher + overlay")
    p_daemon.add_argument("--dolphin-pid", type=int, required=True)
    p_daemon.set_defaults(func=cmd_daemon)

    p_watch = sub.add_parser("watch", help="watcher only (debug)")
    p_watch.add_argument("--dolphin-pid", type=int, default=None)
    p_watch.set_defaults(func=cmd_watch)

    p_overlay = sub.add_parser("overlay", help="overlay only")
    p_overlay.add_argument("--dolphin-pid", type=int, required=True)
    p_overlay.set_defaults(func=cmd_overlay)

    p_test = sub.add_parser("test", help="print joystick events")
    p_test.set_defaults(func=cmd_test)

    args = ap.parse_args()
    if not getattr(args, "func", None):
        ap.print_help()
        return 1

    setup_logging(load_config(), "main")
    if os.environ.get("DOLPHINUI_DEBUG") == "1":
        log.setLevel(logging.DEBUG)

    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())