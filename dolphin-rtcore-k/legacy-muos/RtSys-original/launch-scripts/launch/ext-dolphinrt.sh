#!/bin/bash
# ============================================================
#  Dolphin Rt:Core v11.5.00 — Universal Launcher
#  SPDW Factory Lab / sirpips aka SilverCrow2323
#  /opt/muos/script/launch/ext-dolphinrt.sh
# ============================================================
#  CORE format:  ext-dolphin-<profile>-[upright|sideways]
#
#  Adding a profile = drop 2 files + 1 assign, no edit here.
#  Profiles already in Config/ work automatically.
# ============================================================
. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

# ── Parse CORE ─────────────────────────────────────────────
ORIENT="upright"
case "$CORE" in *-sideways) ORIENT="sideways" ;; esac
PROFILE=$(echo "$CORE" | sed -E 's/^ext-dolphin-//; s/-(upright|sideways)$//')
[ -z "$PROFILE" ] && PROFILE="default"

# ── Environment ────────────────────────────────────────────
NUMSTICKS=$(cat /opt/muos/device/config/board/stick 2>/dev/null || echo 0)
[ "$NUMSTICKS" = "" ] && NUMSTICKS=0

HOME_VAL="$(GET_VAR "device" "board/home" 2>/dev/null)"
[ -n "$HOME_VAL" ] && export HOME="$HOME_VAL"
export XDG_CONFIG_HOME="$HOME/.config"

EMUDIR="/opt/muos/share/emulator/dolphin"
RTSYS="$EMUDIR/RtSys"
LOG="$RTSYS/logs/launcher.log"

mkdir -p "$RTSYS/logs"
SETUP_SDL_ENVIRONMENT
SET_VAR "system" "foreground_process" "dolphin"

# ── Apply profile ──────────────────────────────────────────
"$RTSYS/apply_profile.sh" "$PROFILE" "$ORIENT" "$NUMSTICKS" \
    || { echo "[FATAL] apply_profile failed" >> "$LOG"; exit 1; }

# ── Launch ─────────────────────────────────────────────────
echo "$(date '+%F %T') | $PROFILE | $ORIENT | $(basename "$ROM")" >> "$LOG"

cd "$EMUDIR" || exit 1

JS_DEV=$(ls /dev/input/js* 2>/dev/null | head -1)
[ -z "$JS_DEV" ] && JS_DEV="/dev/input/js0"
[ -x "$RTSYS/overlay_exit.sh" ] && "$RTSYS/overlay_exit.sh" "$JS_DEV" &
WATCHER_PID=$!

cleanup() {
    [ -n "$WATCHER_PID" ] && kill -TERM "$WATCHER_PID" 2>/dev/null
    exit 0
}
trap cleanup SIGTERM SIGINT

"./dolphin" -e "$ROM" -u "$EMUDIR" >> "$RTSYS/logs/dolphin_debug.log" 2>&1
EXIT_CODE=$?

[ -n "$WATCHER_PID" ] && kill -TERM "$WATCHER_PID" 2>/dev/null
type CONTENT_UNSET >/dev/null 2>&1 && CONTENT_UNSET

echo "$(date '+%F %T') | exit=$EXIT_CODE" >> "$LOG"
exit $EXIT_CODE
