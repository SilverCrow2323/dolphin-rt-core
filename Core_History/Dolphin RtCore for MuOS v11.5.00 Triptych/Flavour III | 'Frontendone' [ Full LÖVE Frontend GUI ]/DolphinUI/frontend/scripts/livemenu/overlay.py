#!/usr/bin/env python3
"""DolphinUI Live Menu - in-game curses overlay.

Reads joystick events directly, controls Dolphin via SIGSTOP/SIGCONT,
and injects hotkeys via uinput.

Exit codes:
  0 = resume game normally
  1 = user requested Dolphin to be terminated (frontend should exit emulator)
"""
import argparse
import curses
import os
import signal
import struct
import subprocess
import sys
import time
import logging
import select
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (
    load_config, setup_logging, find_joystick,
    read_dolphin_rom_from_pid, extract_game_id, extract_game_title,
    list_save_states, format_size, play_sound, app_dir,
    JS_EVENT_BUTTON, JS_EVENT_INIT,
)
import injector

log = logging.getLogger("livemenu.overlay")

# ---------------------------------------------------------------------------
# Button indices on the muOS pad (raw kernel numbering, js interface)
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Curses color pairs
# ---------------------------------------------------------------------------
C_TITLE   = 1
C_SELECT  = 2
C_ACTIVE  = 3
C_INFO    = 4
C_WARN    = 5
C_DIM     = 6
C_OK      = 7
C_FOOTER  = 8

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

# ---------------------------------------------------------------------------
# Overlay app
# ---------------------------------------------------------------------------
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
        ("FPS Counter",     "fps"),
        ("Speed %",         "speed"),
        ("Frame Counter",   "framecount"),
        ("Input Display",   "input"),
        ("Pause / Resume",  "pause"),
    ]

    def __init__(self, dolphin_pid, cfg):
        self.dolphin_pid = dolphin_pid
        self.cfg = cfg
        self.state = "MAIN"          # MAIN | SAVE | LOAD | TOGGLE | CONFIRM
        self.sel = 0
        self.paused = False
        self.js_fd = None
        self.js_path = None
        self.exit_code = 0
        self.dirty = True
        self.running = True
        self.confirm_action = None
        self.confirm_msg = ""
        self.message = ""
        self.message_until = 0.0

        # game metadata
        self.rom_path = read_dolphin_rom_from_pid(dolphin_pid) or ""
        self.game_id = extract_game_id(self.rom_path)
        self.game_title = extract_game_title(self.rom_path)
        self.save_slots = []
        self.toggles_state = {}
        self.start_time = time.time()

        self._scan_saves()

    # ---- game info ---------------------------------------------------
    def _scan_saves(self):
        """Load save slots for the current game, keep the first 3 (1..3)."""
        all_slots = list_save_states(self.cfg, self.game_id)
        # Only slots matching .sNNN are Dolphin save states.
        self.save_slots = [
            s for s in all_slots
            if s["name"].endswith(".s001")
            or s["name"].endswith(".s002")
            or s["name"].endswith(".s003")
        ]
        # Ensure deterministic order: s001, s002, s003
        self.save_slots.sort(key=lambda s: s["name"])
        self.save_slots = self.save_slots[:3]

    def _slot_info(self, n):
        """Return dict with slot info, or None if empty. n in 1..3."""
        suffix = ".s%03d" % n
        for s in self.save_slots:
            if s["name"].endswith(suffix):
                return s
        return None

    # ---- pause / resume ----------------------------------------------
    def pause(self):
        if self.paused or not self.cfg["overlay"]["pause_dolphin"]:
            return
        try:
            os.kill(self.dolphin_pid, signal.SIGSTOP)
            self.paused = True
            log.info("paused dolphin")
        except Exception as e:
            log.error("pause failed: %s", e)

    def resume(self):
        if not self.paused:
            return
        try:
            os.kill(self.dolphin_pid, signal.SIGCONT)
            self.paused = False
            log.info("resumed dolphin")
        except Exception as e:
            log.error("resume failed: %s", e)

    def inject_with_resume(self, fn, *args):
        """Temporarily resume Dolphin, inject a key, re-pause."""
        self.resume()
        time.sleep(self.cfg["overlay"]["inject_delay_ms"] / 1000.0)
        ok = fn(*args)
        time.sleep(self.cfg["overlay"]["resume_wait_ms"] / 1000.0)
        self.pause()
        return ok

    # ---- joystick ----------------------------------------------------
    def open_js(self):
        self.js_path = find_joystick()
        if not self.js_path:
            log.error("no joystick")
            return False
        try:
            self.js_fd = os.open(self.js_path, os.O_RDONLY | os.O_NONBLOCK)
            return True
        except Exception as e:
            log.error("open js failed: %s", e)
            return False

    def close_js(self):
        if self.js_fd is not None:
            try:
                os.close(self.js_fd)
            except Exception:
                pass
            self.js_fd = None

    def poll_js(self):
        """Return list of ('btn', n) events from the joystick."""
        if self.js_fd is None:
            return []
        try:
            r, _, _ = select.select([self.js_fd], [], [], 0.05)
            if not r:
                return []
            buf = os.read(self.js_fd, 8 * 64)
        except Exception:
            return []
        out = []
        i = 0
        while i + 8 <= len(buf):
            _t, value, etype, number = struct.unpack("IhBB", buf[i:i + 8])
            i += 8
            if etype & JS_EVENT_INIT:
                continue
            if (etype & 0x7F) == JS_EVENT_BUTTON:
                if value == 1:
                    out.append(("btn", number))
        return out

    # ---- input handlers ----------------------------------------------
    def on_btn(self, n):
        if n == BTN_B:
            self._go_back()
            return
        if n == BTN_START:
            # force resume from anywhere
            self.exit_code = 0
            self.running = False
            return
        if n in (BTN_A, BTN_MENU):
            self._activate()
            return

    def on_hat(self, direction):
        if direction == HAT_UP:
            self._move(-1)
        elif direction == HAT_DOWN:
            self._move(1)

    def _move(self, delta):
        if self.state == "MAIN":
            n = len(self.MAIN_MENU)
        elif self.state in ("SAVE", "LOAD"):
            n = 3 + 1     # 3 slots + Back
        elif self.state == "TOGGLE":
            n = len(self.TOGGLES) + 1
        elif self.state == "CONFIRM":
            n = 2          # Yes / No
        else:
            return
        old = self.sel
        self.sel = (self.sel + delta) % n
        if self.sel != old:
            play_sound("WSD_SELECT")
            self.dirty = True

    def _go_back(self):
        if self.state == "CONFIRM":
            self.state = "MAIN"; self.sel = 0; self.dirty = True
            return
        if self.state in ("SAVE", "LOAD", "TOGGLE"):
            self.state = "MAIN"; self.sel = 0; self.dirty = True
            play_sound("HOMESE_CANCEL")
            return
        # in MAIN -> exit overlay, resume game
        self.exit_code = 0
        self.running = False

    def _activate(self):
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
                self._term()
            elif key == "kill":
                self.confirm_action = "kill"
                self.confirm_msg = "Force-close the emulator?\nThis bypasses the safe exit path."
                self.state = "CONFIRM"; self.sel = 0; self.dirty = True

        elif self.state == "SAVE":
            if self.sel < 3:
                slot = self.sel + 1
                if injector.save_state(slot):
                    self._flash(f"Saved to slot {slot}")
                    play_sound("WIIL_SE_COPY_FINISH")
                    self._scan_saves()
                else:
                    self._flash("Save failed")
            else:
                self._go_back()

        elif self.state == "LOAD":
            if self.sel < 3:
                slot = self.sel + 1
                if injector.load_state(slot):
                    self._flash(f"Loaded slot {slot}")
                    play_sound("WIIL_SE_BOARD_SELECT")
            else:
                self._go_back()

        elif self.state == "TOGGLE":
            if self.sel < len(self.TOGGLES):
                fn_name = self.TOGGLES[self.sel][1]
                fn = getattr(injector, "toggle_" + fn_name, None)
                if fn:
                    fn()
                    self._flash("Toggled")
                    play_sound("WIIL_SE_BOARD_SELECT")
            else:
                self._go_back()

        elif self.state == "CONFIRM":
            if self.sel == 0:      # Yes
                act = self.confirm_action
                if act == "reset":
                    self.resume()
                    time.sleep(0.15)
                    injector.reset_game()
                    time.sleep(0.4)
                    self.pause()
                    self._flash("Game reset")
                elif act == "kill":
                    self._term(force=True)
                    self.exit_code = 1
                    self.running = False
            self.state = "MAIN"; self.sel = 0; self.confirm_action = None
            self.dirty = True

    def _flash(self, msg, secs=1.6):
        self.message = msg
        self.message_until = time.time() + secs
        self.dirty = True

    def _term(self, force=False):
        """Signal Dolphin to terminate.
        Set paused=False so the watcher does not SIGCONT a dead process."""
        if not self.paused:
            return
        try:
            os.kill(self.dolphin_pid, signal.SIGCONT)
            self.paused = False
        except Exception:
            pass
        time.sleep(0.05)
        sig = signal.SIGKILL if force else signal.SIGTERM
        try:
            os.kill(self.dolphin_pid, sig)
            log.info("sent signal %s", sig)
        except Exception as e:
            log.error("term failed: %s", e)

    # ---- rendering ---------------------------------------------------
    def render(self, stdscr):
        stdscr.erase()
        h, w = stdscr.getmaxyx()
        try:
            self._draw_header(stdscr, w)
            if self.state == "MAIN":
                self._draw_main(stdscr, h, w)
            elif self.state == "SAVE":
                self._draw_slots(stdscr, h, w, "save")
            elif self.state == "LOAD":
                self._draw_slots(stdscr, h, w, "load")
            elif self.state == "TOGGLE":
                self._draw_toggles(stdscr, h, w)
            elif self.state == "CONFIRM":
                self._draw_confirm(stdscr, h, w)
            self._draw_footer(stdscr, h, w)
            self._draw_flash(stdscr, h, w)
        except curses.error:
            pass
        stdscr.noutrefresh()
        curses.doupdate()
        self.dirty = False

    def _draw_header(self, s, w):
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
        status = f"  Playing {hh:02d}:{mm:02d}:{ss:02d}  ·  PID {self.dolphin_pid}  "
        try:
            s.addstr(3, 0, status, curses.color_pair(C_DIM))
        except curses.error:
            pass

        try:
            s.addstr(4, 0, "─" * w, curses.color_pair(C_DIM))
        except curses.error:
            pass

    def _draw_main(self, s, h, w):
        y0 = 6
        for i, (label, _) in enumerate(self.MAIN_MENU):
            y = y0 + i
            if i == self.sel:
                s.addstr(y, 8, "▶  " + label.ljust(34),
                         curses.color_pair(C_SELECT) | curses.A_BOLD)
            else:
                s.addstr(y, 8, "   " + label.ljust(34),
                         curses.color_pair(C_DIM))

    def _draw_slots(self, s, h, w, mode):
        title = "SAVE STATE" if mode == "save" else "LOAD STATE"
        s.addstr(6, 4, title, curses.color_pair(C_TITLE) | curses.A_BOLD)

        for i in range(3):
            y = 8 + i * 2
            info = self._slot_info(i + 1)
            focused = (i == self.sel)
            if info:
                right = f"{info['date']}   {format_size(info['size'])}"
            else:
                right = "(empty)"
            label = f"  Slot {i+1}"
            line = label.ljust(12) + right
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

    def _draw_toggles(self, s, h, w):
        s.addstr(6, 4, "QUICK TOGGLES", curses.color_pair(C_TITLE) | curses.A_BOLD)
        for i, (label, _) in enumerate(self.TOGGLES):
            y = 8 + i
            focused = (i == self.sel)
            if focused:
                s.addstr(y, 6, "▶  " + label.ljust(w - 14),
                         curses.color_pair(C_SELECT) | curses.A_BOLD)
            else:
                s.addstr(y, 6, "   " + label, curses.color_pair(C_DIM))
        y = 8 + len(self.TOGGLES) + 1
        focused = (self.sel == len(self.TOGGLES))
        if focused:
            s.addstr(y, 6, "▶  Back".ljust(w - 14),
                     curses.color_pair(C_SELECT) | curses.A_BOLD)
        else:
            s.addstr(y, 6, "   Back", curses.color_pair(C_DIM))

    def _draw_confirm(self, s, h, w):
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
        yes = "[ YES ]"
        no  = "[ NO ]"
        gap = 6
        total = len(yes) + gap + len(no)
        bx = x0 + (box_w - total) // 2
        if self.sel == 0:
            s.addstr(y_btn, bx, yes, curses.color_pair(C_SELECT) | curses.A_BOLD)
        else:
            s.addstr(y_btn, bx, yes, curses.color_pair(C_DIM))
        if self.sel == 1:
            s.addstr(y_btn, bx + len(yes) + gap, no,
                     curses.color_pair(C_SELECT) | curses.A_BOLD)
        else:
            s.addstr(y_btn, bx + len(yes) + gap, no, curses.color_pair(C_DIM))
        s.addstr(y0 + box_h - 1, x0, "└" + "─" * (box_w - 2) + "┘",
                 curses.color_pair(C_WARN))

    def _draw_footer(self, s, h, w):
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

    def _draw_flash(self, s, h, w):
        if not self.message or time.time() > self.message_until:
            return
        try:
            s.addstr(h - 3, max(0, (w - len(self.message)) // 2),
                     self.message, curses.color_pair(C_OK) | curses.A_BOLD)
        except curses.error:
            pass

    # ---- main loop ---------------------------------------------------
    def run(self, stdscr):
        curses.curs_set(0)
        init_colors()
        stdscr.nodelay(True)
        stdscr.keypad(True)

        if not self.open_js():
            log.error("cannot open joystick, exiting")
            return 0

        # Initial pause so we control the framebuffer.
        # Note: the watcher also SIGSTOPs Dolphin before launching us.
        # SIGSTOP is not a counter — a second SIGSTOP on an already
        # stopped process is a no-op. This keeps the invariant simple.
        self.pause()

        last_draw = 0.0
        while self.running:
            now = time.time()
            if self.dirty or (now - last_draw) > 0.5:
                self.render(stdscr)
                last_draw = now

            # keyboard fallback (useful for testing via SSH)
            ch = stdscr.getch()
            if ch != -1:
                if ch in (curses.KEY_UP, ord('w')):
                    self._move(-1)
                elif ch in (curses.KEY_DOWN, ord('s')):
                    self._move(1)
                elif ch in (10, 13, ord(' '), ord('a'), ord('A')):
                    self._activate()
                elif ch in (27, ord('b'), ord('B'), ord('q')):
                    self._go_back()

            for kind, code in self.poll_js():
                if kind == "btn":
                    self.on_btn(code)

            time.sleep(0.02)

        self.close_js()

        # On exit, if still paused, resume or terminate.
        # The watcher will SIGCONT again as a safety net — harmless.
        if self.paused:
            if self.exit_code == 1:
                self._term(force=True)
            else:
                self.resume()
        return self.exit_code

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dolphin-pid", type=int, required=True)
    ap.add_argument("--config", type=str, default=None)
    args = ap.parse_args()

    cfg = load_config()
    setup_logging(cfg, "overlay")
    log.info("overlay starting (dolphin pid=%d)", args.dolphin_pid)

    ov = Overlay(args.dolphin_pid, cfg)
    try:
        rc = curses.wrapper(ov.run)
    except Exception as e:
        log.error("curses error: %s", e)
        # ensure dolphin is not left suspended
        try:
            os.kill(args.dolphin_pid, signal.SIGCONT)
        except Exception:
            pass
        return 0
    return rc or 0

if __name__ == "__main__":
    sys.exit(main())