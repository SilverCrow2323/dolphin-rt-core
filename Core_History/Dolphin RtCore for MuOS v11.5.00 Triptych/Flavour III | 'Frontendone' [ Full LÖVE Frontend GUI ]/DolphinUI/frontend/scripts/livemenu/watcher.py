#!/usr/bin/env python3
"""DolphinUI Live Menu - joystick watcher daemon.

Watches /dev/input/jsX for two patterns:
  MENU + START  (simultaneous)  -> launch overlay menu
  MENU alone    (short press)   -> SIGTERM Dolphin (exit to frontend)

Usage:
  watcher.py

While overlay is running, this process blocks (does not read joystick).
"""
import argparse
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
    load_config, setup_logging, find_dolphin_pid,
    find_joystick, app_dir, ensure_dir,
    JS_EVENT_BUTTON, JS_EVENT_INIT,
)

log = logging.getLogger("livemenu.watcher")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
class Watcher:
    def __init__(self, cfg):
        self.cfg = cfg
        self.menu_btns = set(int(b) for b in cfg["watcher"]["menu_buttons"])
        self.start_btn = int(cfg["watcher"]["start_button"])
        self.combo_window = cfg["watcher"]["combo_window_ms"] / 1000.0
        self.menu_alone_timeout = cfg["watcher"]["menu_alone_timeout_ms"] / 1000.0
        self.kill_on_alone = cfg["watcher"]["kill_on_menu_alone"]
        self.running = True

        self.js_path = None
        self.js_fd = None

        self.btn_state = {}          # button -> 0/1
        self.menu_down_at = 0.0
        self.menu_armed = False      # MENU pressed, waiting for START
        self.combo_fired = False     # START arrived during MENU press

    # ---- lifecycle ---------------------------------------------------
    def open_js(self):
        self.js_path = find_joystick()
        if not self.js_path:
            log.error("no joystick found")
            return False
        try:
            self.js_fd = os.open(self.js_path, os.O_RDONLY | os.O_NONBLOCK)
            log.info("watching %s", self.js_path)
            return True
        except Exception as e:
            log.error("cannot open %s: %s", self.js_path, e)
            return False

    def close_js(self):
        if self.js_fd is not None:
            try:
                os.close(self.js_fd)
            except Exception:
                pass
            self.js_fd = None

    def stop(self, *_):
        log.info("signal received, stopping")
        self.running = False

    # ---- high-level actions -----------------------------------------
    def menu_is_down(self):
        return any(self.btn_state.get(b, 0) == 1 for b in self.menu_btns)

    def launch_overlay(self):
        log.info("MENU+START detected -> launching overlay")
        dolphin_pid = find_dolphin_pid()
        if dolphin_pid is None:
            log.warning("dolphin not running, ignoring")
            return

        # Pause dolphin so the user can't interact with the game.
        # The overlay will SIGSTOP again on entry: SIGSTOP is not a
        # counter, so a second signal on an already stopped process is
        # a no-op. This is intentional — the watcher is the safety net
        # in case the overlay crashes without resuming.
        if self.cfg["overlay"]["pause_dolphin"]:
            try:
                os.kill(dolphin_pid, signal.SIGSTOP)
                log.info("dolphin %d paused", dolphin_pid)
            except Exception as e:
                log.error("SIGSTOP failed: %s", e)
                return

        # Spawn overlay (blocking)
        overlay_py = os.path.join(app_dir(), "scripts", "livemenu", "overlay.py")
        env = os.environ.copy()
        env["PYTHONPATH"] = (
            str(Path(__file__).resolve().parent) + ":" + env.get("PYTHONPATH", "")
        )
        try:
            proc = subprocess.run(
                [sys.executable, overlay_py,
                 "--dolphin-pid", str(dolphin_pid),
                 "--config", self._config_path()],
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=300,
            )
            rc = proc.returncode
        except subprocess.TimeoutExpired:
            log.error("overlay timeout")
            rc = 0
        except Exception as e:
            log.error("overlay spawn failed: %s", e)
            rc = 0

        # Resume if still paused (overlay did not terminate dolphin)
        if self.cfg["overlay"]["pause_dolphin"]:
            try:
                os.kill(dolphin_pid, signal.SIGCONT)
                log.info("dolphin %d resumed", dolphin_pid)
            except ProcessLookupError:
                pass
            except Exception as e:
                log.error("SIGCONT failed: %s", e)

        # If overlay returned 1, user chose to close the emulator
        if rc == 1:
            log.info("overlay requested dolphin termination")
            try:
                os.kill(dolphin_pid, signal.SIGTERM)
            except Exception:
                pass

        # Drain any events queued while we were away
        self._drain()
        # Reset state so we don't immediately re-fire
        self.menu_armed = False
        self.combo_fired = False
        self.btn_state.clear()

    def kill_dolphin(self):
        pid = find_dolphin_pid()
        if pid is None:
            log.info("MENU alone -> dolphin not running")
            return
        log.info("MENU alone -> SIGTERM dolphin %d", pid)
        try:
            os.kill(pid, signal.SIGTERM)
        except Exception as e:
            log.error("SIGTERM failed: %s", e)

    def _drain(self):
        """Consume pending events from the joystick device."""
        if self.js_fd is None:
            return
        deadline = time.time() + 0.1
        while time.time() < deadline:
            r, _, _ = select.select([self.js_fd], [], [], 0.02)
            if not r:
                return
            try:
                buf = os.read(self.js_fd, 8 * 64)
                if not buf:
                    return
            except Exception:
                return

    def _config_path(self):
        return os.path.join(app_dir(), "data", "livemenu_config.json")

    # ---- main loop ---------------------------------------------------
    def run(self):
        if not self.open_js():
            return 1
        last_poll = 0.0
        poll_interval = self.cfg["watcher"]["poll_interval_ms"] / 1000.0

        while self.running:
            r, _, _ = select.select([self.js_fd], [], [], poll_interval)
            if not r:
                continue
            try:
                buf = os.read(self.js_fd, 8 * 64)
                if not buf:
                    # EOF: device disappeared (unplugged / power event).
                    # Close the fd and try to reopen a new one.
                    log.warning("joystick EOF, trying to reopen")
                    self.close_js()
                    time.sleep(0.5)
                    if not self.open_js():
                        log.error("cannot reopen joystick, exiting")
                        return 1
                    continue
            except Exception:
                time.sleep(0.1)
                continue

            i = 0
            while i + 8 <= len(buf):
                _t, value, etype, number = struct.unpack("IhBB", buf[i:i + 8])
                i += 8
                if etype & JS_EVENT_INIT:
                    continue
                if (etype & 0x7F) != JS_EVENT_BUTTON:
                    continue
                self._handle_button(number, value)

        self.close_js()
        return 0

    def _handle_button(self, number, value):
        prev = self.btn_state.get(number, 0)
        if prev == value:
            return
        self.btn_state[number] = value

        is_menu  = number in self.menu_btns
        is_start = (number == self.start_btn)

        if is_menu and value == 1:
            # MENU down
            if not self.menu_armed and not self.combo_fired:
                self.menu_armed = True
                self.menu_down_at = time.time()
            return

        if is_start and value == 1 and self.menu_is_down():
            if not self.combo_fired:
                self.combo_fired = True
                self.menu_armed = False
                self.launch_overlay()
            return

        if is_menu and value == 0 and not self.menu_is_down():
            if self.menu_armed and not self.combo_fired:
                dt = time.time() - self.menu_down_at
                if self.kill_on_alone and dt <= self.menu_alone_timeout:
                    self.kill_dolphin()
            self.menu_armed = False
            self.combo_fired = False
            return

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    args = ap.parse_args()

    cfg = load_config()
    setup_logging(cfg, "watcher")
    log.info("=" * 50)
    log.info("watcher starting")

    w = Watcher(cfg)
    signal.signal(signal.SIGTERM, w.stop)
    signal.signal(signal.SIGINT, w.stop)
    return w.run()

if __name__ == "__main__":
    sys.exit(main())