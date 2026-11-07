#!/bin/bash
# ============================================================
#  DolphinUI — overlay_exit.sh
#  Watches /dev/input/jsX for START+SELECT and terminates
#  the given Dolphin PID (or any "dolphin" process).
#  Usage:  overlay_exit.sh <js_device> [<dolphin_pid>]
# ============================================================
JS_DEV="${1:-/dev/input/js0}"
DOLPHIN_PID="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$APP_DIR/data/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/watcher_$(date +%Y%m%d_%H%M%S).log"
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

log "watcher on $JS_DEV (dolphin_pid='${DOLPHIN_PID:-none}')"
[ -e "$JS_DEV" ] || { log "ERROR: $JS_DEV not present"; exit 1; }

# RG35XX H / muOS schema: START=7, SELECT=6
START_BTN=7
SELECT_BTN=6
start_down=0
select_down=0

exec 3< "$JS_DEV"

while true; do
    # Exit if the target dolphin died
    if [ -n "$DOLPHIN_PID" ] && ! kill -0 "$DOLPHIN_PID" 2>/dev/null; then
        log "dolphin PID gone, exiting"
        break
    fi

    # Read one 8-byte js_event with a 1s timeout so the loop can
    # re-check liveness even when the user presses nothing.
    EVENT=$(timeout 1 dd bs=8 count=1 <&3 2>/dev/null | od -An -tu1 2>/dev/null)
    [ -z "$EVENT" ] && continue

    # shellcheck disable=SC2086
    set -- $EVENT
    VALUE=$5
    TYPE=$7
    NUMBER=$8
    TYPE=$((TYPE & 0x7F))
    [ "$TYPE" != "1" ] && continue

    [ "$NUMBER" = "$START_BTN" ]  && start_down=$VALUE
    [ "$NUMBER" = "$SELECT_BTN" ] && select_down=$VALUE

    if [ "$start_down" = "1" ] && [ "$select_down" = "1" ]; then
        log "START+SELECT → terminating dolphin"
        if [ -x /opt/muos/script/mux/overlay.sh ]; then
            /opt/muos/script/mux/overlay.sh "Exiting..." >> "$LOG" 2>&1 &
        fi
        sleep 0.5
        if [ -n "$DOLPHIN_PID" ]; then
            kill -TERM "$DOLPHIN_PID" 2>/dev/null
            sleep 0.5
            kill -KILL "$DOLPHIN_PID" 2>/dev/null
        else
            killall -TERM dolphin 2>/dev/null
            sleep 0.5
            killall -KILL dolphin 2>/dev/null
        fi
        log "dolphin terminated"
        break
    fi
done

exec 3<&-
log "watcher stopped"
exit 0
