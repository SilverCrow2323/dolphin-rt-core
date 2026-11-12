#!/bin/bash
# Configurable Safe Exit watcher for RTUI-launched Dolphin sessions.
# Default: START + SELECT (buttons 9 + 8). Multi-button combinations are supported.
set -u
JS_DEV="${1:-/dev/input/js1}"
DOLPHIN_PID="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$APP_DIR/data/logs"
CONFIG="${RT_SAFE_EXIT_CONFIG:-$APP_DIR/data/safe_exit.conf}"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/watcher_$(date +%Y%m%d_%H%M%S).log"
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

COMBO=()
if [ -r "$CONFIG" ]; then
    IFS=',' read -r -a CANDIDATE < "$CONFIG"
    for token in "${CANDIDATE[@]}"; do
        token="${token//[[:space:]]/}"
        case "$token" in ''|*[!0-9]*) continue ;; esac
        [ "$token" -le 255 ] || continue
        duplicate=0
        for existing in "${COMBO[@]}"; do [ "$existing" = "$token" ] && duplicate=1; done
        [ "$duplicate" -eq 1 ] || COMBO+=("$token")
    done
fi
[ "${#COMBO[@]}" -gt 0 ] || COMBO=(8 9)
log "Safe Exit watcher on $JS_DEV; combo=$(IFS=,; echo "${COMBO[*]}"); pid=${DOLPHIN_PID:-auto}"
[ -e "$JS_DEV" ] || { log "ERROR: $JS_DEV not present"; exit 1; }
exec 3< "$JS_DEV"
declare -a DOWN=()
seen=0
while true; do
    if [ -n "$DOLPHIN_PID" ]; then
        if kill -0 "$DOLPHIN_PID" 2>/dev/null; then seen=1
        elif [ "$seen" = 1 ]; then log "Dolphin PID exited"; break; fi
    else
        if pgrep -x dolphin >/dev/null 2>&1; then seen=1
        elif [ "$seen" = 1 ]; then log "Dolphin exited"; break; fi
    fi

    EVENT=$(timeout 2 dd bs=8 count=1 <&3 2>/dev/null | od -An -tu1 2>/dev/null)
    [ -z "$EVENT" ] && continue
    # shellcheck disable=SC2086
    set -- $EVENT
    [ "$#" -ge 8 ] || continue
    VALUE=$5
    TYPE=$7
    NUMBER=$8
    TYPE=$((TYPE & 0x7F))
    [ "$TYPE" = "1" ] || continue
    case "$VALUE" in 0|1) ;; *) continue ;; esac
    DOWN[$NUMBER]=$VALUE

    matched=1
    for button in "${COMBO[@]}"; do
        [ "${DOWN[$button]:-0}" = "1" ] || { matched=0; break; }
    done
    if [ "$matched" = 1 ]; then
        log "Safe Exit combo detected; terminating Dolphin"
        if [ -x /opt/muos/script/mux/overlay.sh ]; then
            /opt/muos/script/mux/overlay.sh "Exiting..." >> "$LOG" 2>&1 &
        fi
        if [ -n "$DOLPHIN_PID" ]; then
            kill -TERM "$DOLPHIN_PID" 2>/dev/null || true
            for _ in 1 2 3 4 5 6; do
                kill -0 "$DOLPHIN_PID" 2>/dev/null || break
                sleep 0.25
            done
            kill -KILL "$DOLPHIN_PID" 2>/dev/null || true
        else
            killall -TERM dolphin 2>/dev/null || true
            for _ in 1 2 3 4 5 6; do
                pgrep -x dolphin >/dev/null 2>&1 || break
                sleep 0.25
            done
            killall -KILL dolphin 2>/dev/null || true
        fi
        log "Dolphin termination requested"
        break
    fi
done
exec 3<&-
log "Safe Exit watcher stopped"
exit 0
