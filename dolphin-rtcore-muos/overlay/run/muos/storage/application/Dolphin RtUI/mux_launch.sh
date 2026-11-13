#!/bin/bash
# HELP: Dolphin Rt:Core - GameCube/Wii library, profiles, and PC streaming (Rt:Stream)
# ICON: dolphinrt_icon
# GRID: Dolphin Rt:Core
#
# mux_launch.sh - muOS 2606 "Andromeda" application entry point.
# The frontend runs:  mux_launch.sh "<this app folder>"   (after SETUP_APP).
#
# One process stays the muOS "app" for the whole cycle, so muOS never shows its
# menu over a game:
#     LÖVE (UI)  ->  Dolphin (local)  or  Moonlight (Rt:Stream)  ->  LÖVE (UI) -> ...
# The UI writes data/launch_cmd.sh + data/launch.request; this loop runs it
# synchronously and then restarts the UI on the screen named in data/launch.ret.

set -u

RETURN_TO=""
for arg in "$@"; do
    case "$arg" in
        --return-to=*) RETURN_TO="${arg#*=}" ;;
    esac
done

# muOS helpers (GET_VAR / SET_VAR / CAFFEINE / SETUP_APP ...)
# shellcheck disable=SC1091
{ [ -r /opt/muos/script/var/func.sh ] && . /opt/muos/script/var/func.sh; } >/dev/null 2>&1 || true
# shellcheck disable=SC1091
{ [ -r /opt/muos/script/var/retro.sh ] && . /opt/muos/script/var/retro.sh; } >/dev/null 2>&1 || true

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$APP_DIR/lib"
LOVE_BIN="$LIB_DIR/love"
[ -x "$LOVE_BIN" ] || LOVE_BIN="$(command -v love 2>/dev/null || true)"

# Prefer the live storage mount when it exists (same folder, stable path)
APP_NAME="$(basename "$APP_DIR")"
APP_MOUNT="${MUOS_STORE_DIR:-/run/muos/storage}/application/$APP_NAME"
[ -d "$APP_MOUNT" ] && APP_DIR="$APP_MOUNT"

export XDG_DATA_HOME="$APP_DIR/data"
export HOME="$APP_DIR/data"
export LD_LIBRARY_PATH="$LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# Heavy-debug build: keep RTUI diagnostics enabled for field testing.
# Users can override with DOLPHINUI_HEAVY_DEBUG=0 when troubleshooting storage/performance.
export DOLPHINUI_HEAVY_DEBUG="${DOLPHINUI_HEAVY_DEBUG:-1}"
export DOLPHINUI_DEBUG_LOG="${DOLPHINUI_DEBUG_LOG:-$APP_DIR/data/logs/heavy_debug.log}"
# NOTE: SDL_GAMECONTROLLERCONFIG* is set by SETUP_APP / SETUP_SDL_ENVIRONMENT
#       (retro or modern layout, chosen by the user's remap setting): never override it.

SCR_W=640; SCR_H=480
if type GET_VAR >/dev/null 2>&1; then
    W="$(GET_VAR device mux/width 2>/dev/null)";  H="$(GET_VAR device mux/height 2>/dev/null)"
    case "$W" in ''|*[!0-9]*) ;; *) SCR_W="$W" ;; esac
    case "$H" in ''|*[!0-9]*) ;; *) SCR_H="$H" ;; esac
fi

LOG_DIR="$APP_DIR/data/logs"
mkdir -p "$LOG_DIR" "$APP_DIR/data/stream"
FRONTEND_LOG="$LOG_DIR/frontend.log"
[ "$(wc -c < "$FRONTEND_LOG" 2>/dev/null || echo 0)" -gt 524288 ] && : > "$FRONTEND_LOG"

if [ -z "$LOVE_BIN" ] || [ ! -x "$LOVE_BIN" ]; then
    echo "Dolphin Rt:Core: love binary not found." | tee -a "$FRONTEND_LOG"
    exit 1
fi

cd "$APP_DIR" || exit 1

# Detect the installed muOS registration API and repair stale GameCube/Wii assignments
# before the frontend opens. The app remains launchable if registration fails.
MT="/opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh"
if [ -x "$MT" ]; then
    if ! sh "$MT" ensure >> "$LOG_DIR/manifest.log" 2>&1; then
        echo "$(date '+%F %T') [WARN] core registration check failed; see manifest.log / run the Register task" >> "$LOG_DIR/frontend.log"
    fi
fi

export DOLPHINUI_LOOP=1
command -v CAFFEINE >/dev/null 2>&1 && CAFFEINE on

LOOP_EXIT=0
while true; do
    rm -f "$APP_DIR/data/launch.request" "$APP_DIR/data/launch_cmd.sh" "$APP_DIR/data/launch.ret"

    if type SETUP_APP >/dev/null 2>&1; then
        SETUP_APP "love" ""
    else
        type SETUP_SDL_ENVIRONMENT >/dev/null 2>&1 && SETUP_SDL_ENVIRONMENT
    fi
    type SET_VAR >/dev/null 2>&1 && SET_VAR "system" "foreground_process" "love" 2>/dev/null
    export DOLPHINUI_RETURN_TO="$RETURN_TO"

    "$LOVE_BIN" . "${SCR_W}x${SCR_H}" >> "$FRONTEND_LOG" 2>&1
    LOOP_EXIT=$?

    # No launch request -> the user chose Exit (or LÖVE crashed)
    [ -f "$APP_DIR/data/launch.request" ] || break

    if [ -f "$APP_DIR/data/launch.ret" ]; then
        RETURN_TO="$(tr -d '\n\r' < "$APP_DIR/data/launch.ret")"
    fi
    [ -n "${RETURN_TO:-}" ] || RETURN_TO="library"

    # Run the game (Dolphin) or the stream (Moonlight) synchronously.
    if [ -f "$APP_DIR/data/launch_cmd.sh" ]; then
        DOLPHINUI_LOOP=1 bash "$APP_DIR/data/launch_cmd.sh" >> "$FRONTEND_LOG" 2>&1
        LOOP_EXIT=$?
    else
        echo "$(date +%T) [loop] launch.request present but launch_cmd.sh missing" >> "$FRONTEND_LOG"
    fi

    rm -f "$APP_DIR/data/launch.request" "$APP_DIR/data/launch_cmd.sh" "$APP_DIR/data/launch.ret"
done

# ── shutdown ───────────────────────────────────────────────
type CONTENT_UNSET >/dev/null 2>&1 && CONTENT_UNSET
command -v CAFFEINE >/dev/null 2>&1 && CAFFEINE off
# gptokeyb: the frontend stops its own group and stray instances when we return.

exit "$LOOP_EXIT"
