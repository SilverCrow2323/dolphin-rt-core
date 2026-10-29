#!/bin/bash
# ============================================================
#  Overlay Exit Watcher — START+SELECT only
#  SPDW Factory Lab / sirpips aka SilverCrow2323
# ============================================================
JS_DEV="${1:-/dev/input/js0}"
RTSYS="/opt/muos/share/emulator/dolphin/RtSys"
LOG="$RTSYS/logs/watcher.log"

mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

log "Watcher started on $JS_DEV"

[ -e "$JS_DEV" ] || { log "ERROR: $JS_DEV not found"; exit 1; }

# Button numbers (muOS Schema B / RG35XX H)
START_BTN=7
SELECT_BTN=6

start_down=0
select_down=0

exec 3< "$JS_DEV"

while true; do
    # Exit if Dolphin is no longer running
    pgrep -x dolphin >/dev/null 2>&1 || { log "Dolphin exited, watcher stopping"; break; }

    # Read one 8-byte js_event with timeout
    EVENT=$(timeout 1 dd bs=8 count=1 <&3 2>/dev/null | od -An -tu1 2>/dev/null)
    [ -z "$EVENT" ] && continue

    set -- $EVENT
    VALUE=$5      # 1 = pressed, 0 = released
    TYPE=$7
    NUMBER=$8

    # Mask init flag (0x80)
    TYPE=$((TYPE & 0x7F))

    # Only button events
    [ "$TYPE" != "1" ] && continue

    [ "$NUMBER" = "$START_BTN" ]  && start_down=$VALUE
    [ "$NUMBER" = "$SELECT_BTN" ] && select_down=$VALUE

    # Combo detected → exit
    if [ "$start_down" = "1" ] && [ "$select_down" = "1" ]; then
        log "START+SELECT detected — terminating Dolphin"

        # Show a quick overlay if muOS provides one
        if [ -x /opt/muos/script/mux/overlay.sh ]; then
            /opt/muos/script/mux/overlay.sh "Exiting..." >> "$LOG" 2>&1 &
        fi

        sleep 1

        killall -TERM dolphin 2>/dev/null
        sleep 0.5
        killall -KILL dolphin 2>/dev/null

        log "Dolphin terminated"
        break
    fi
done

exec 3<&-
log "Watcher stopped"
exit 0
