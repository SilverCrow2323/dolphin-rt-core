#!/bin/bash
# HELP: Dolphin Rt:FinalCut - LOVE frontend for Dolphin Rt:Core
# ICON: dolphinrt_icon
# GRID: Dolphin Rt:FinalCut
#
# mux_launch.sh - muOS Jacaranda application entry point.
#
# v3 (2026-10-23): single LOVE launch point, but the script no longer exits
# between LÖVE and Dolphin. The whole cycle is:
#
#     LÖVE (frontend) → launch.sh (Dolphin) → LÖVE (frontend) → ...
#
# mux_launch.sh stays the muOS "app" for the entire cycle, so muOS never
# shows its menu over Dolphin and CAFFEINE / OSD / gptokeyb2 stay in the
# state that the emulator needs.

set -u

RETURN_TO=""
for arg in "$@"; do
    case "$arg" in
        --return-to=*) RETURN_TO="${arg#*=}" ;;
    esac
done
[ -n "$RETURN_TO" ] && export DOLPHINUI_RETURN_TO="$RETURN_TO"

[ -r /opt/muos/script/var/func.sh ] && . /opt/muos/script/var/func.sh >/dev/null 2>&1 || true

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$APP_DIR/lib"
LOVE_BIN="$LIB_DIR/love"
[ -x "$LOVE_BIN" ] || LOVE_BIN="$(command -v love 2>/dev/null || true)"

APP_NAME="$(basename "$APP_DIR")"
APP_MOUNT="/run/muos/storage/application/$APP_NAME"
[ -d "$APP_MOUNT" ] && APP_DIR="$APP_MOUNT"

OSD_DAEMONS="muos_osd mux_osd muos_hotkey muos_hotkeys muos_volume muos-vol muos_osd.py"
pause_osd()  { for P in $OSD_DAEMONS; do pkill -STOP -x "$P" 2>/dev/null || true; done; }
resume_osd() { for P in $OSD_DAEMONS; do pkill -CONT -x "$P" 2>/dev/null || true; done; }

export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
export XDG_DATA_HOME="$APP_DIR/data"
export HOME="$APP_DIR/data"
export LD_LIBRARY_PATH="$LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

SCR_W=640
SCR_H=480
if type GET_VAR >/dev/null 2>&1; then
    SCR_W="$(GET_VAR device mux/width 2>/dev/null || echo 640)"
    SCR_H="$(GET_VAR device mux/height 2>/dev/null || echo 480)"
fi

LOG_DIR="$APP_DIR/data/logs"
mkdir -p "$LOG_DIR"
FRONTEND_LOG="$LOG_DIR/frontend.log"
if [ "$(wc -c < "$FRONTEND_LOG" 2>/dev/null || echo 0)" -gt 524288 ]; then
    : > "$FRONTEND_LOG"
fi

if [ -z "$LOVE_BIN" ] || [ ! -x "$LOVE_BIN" ]; then
    echo "Dolphin Rt:FinalCut: love binary not found." | tee -a "$FRONTEND_LOG"
    exit 1
fi

cd "$APP_DIR" || exit 1

export DOLPHINUI_LOOP=1
command -v CAFFEINE >/dev/null 2>&1 && CAFFEINE on
pause_osd

# ── main loop: LÖVE → Dolphin → LÖVE ───────────────────────
LOOP_EXIT=0

while true; do
    # Clear any stale request from a previous cycle (or a crashed run)
    rm -f "$APP_DIR/data/launch.request" \
          "$APP_DIR/data/launch_cmd.sh" \
          "$APP_DIR/data/launch.ret"

    # muOS: set up the environment for love before each iteration.
    # (launch.sh does its own SETUP_SDL_ENVIRONMENT for Dolphin.)
    if type SETUP_APP >/dev/null 2>&1; then
        SETUP_APP "love" ""
    else
        type SETUP_SDL_ENVIRONMENT >/dev/null 2>&1 && SETUP_SDL_ENVIRONMENT
    fi
    type SET_VAR >/dev/null 2>&1 && SET_VAR "system" "foreground_process" "love" 2>/dev/null
    export DOLPHINUI_RETURN_TO="$RETURN_TO"

    "$LOVE_BIN" . "${SCR_W}x${SCR_H}" >> "$FRONTEND_LOG" 2>&1
    LOOP_EXIT=$?

    # No launch request → the user chose Exit (or LÖVE crashed)
    [ -f "$APP_DIR/data/launch.request" ] || break

    # Carry over the return-to target for the next LÖVE launch
    if [ -f "$APP_DIR/data/launch.ret" ]; then
        RETURN_TO="$(tr -d '\n\r' < "$APP_DIR/data/launch.ret")"
    fi
    [ -n "${RETURN_TO:-}" ] || RETURN_TO="library"

    # Run Dolphin synchronously. launch.sh reads its flags normally; the
    # only difference is DOLPHINUI_LOOP=1, which makes it skip
    # CONTENT_UNSET and restart_frontend (this script handles both).
    if [ -f "$APP_DIR/data/launch_cmd.sh" ]; then
        DOLPHINUI_LOOP=1 bash "$APP_DIR/data/launch_cmd.sh" >> "$FRONTEND_LOG" 2>&1
        LOOP_EXIT=$?
    else
        echo "$(date +%T) [loop] launch.request present but launch_cmd.sh missing" >> "$FRONTEND_LOG"
    fi

    rm -f "$APP_DIR/data/launch.request" \
          "$APP_DIR/data/launch_cmd.sh" \
          "$APP_DIR/data/launch.ret"
done

# ── shutdown ───────────────────────────────────────────────
resume_osd
command -v CAFFEINE >/dev/null 2>&1 && CAFFEINE off
killall -q gptokeyb2 gptokeyb2.armhf 2>/dev/null || true

exit "$LOOP_EXIT"