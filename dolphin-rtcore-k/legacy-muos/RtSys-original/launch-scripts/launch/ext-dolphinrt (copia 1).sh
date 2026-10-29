#!/bin/bash
# ============================================================
#  Dolphin Rt:Core v11.5.00 — Comfort Zone
#  SPDW Factory Lab / sirpips aka SilverCrow2323
#  /opt/muos/script/launch/ext-dolphinrt.sh
# ============================================================
. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

# ── Parse CORE ─────────────────────────────────────────────
ORIENT="upright"
case "$CORE" in
    *-sideways) ORIENT="sideways" ;;
    *-upright)  ORIENT="upright"  ;;
esac

# ── Environment ────────────────────────────────────────────
NUMSTICKS=$(cat /opt/muos/device/config/board/stick 2>/dev/null || echo 0)
HOME_VAL="$(GET_VAR "device" "board/home" 2>/dev/null)"
[ -n "$HOME_VAL" ] && export HOME="$HOME_VAL"
[ -z "$NUMSTICKS" ] && NUMSTICKS=0
export XDG_CONFIG_HOME="$HOME/.config"

EMUDIR="/opt/muos/share/emulator/dolphin"
RTSYS="$EMUDIR/RtSys"
LOGDIR="$RTSYS/logs"
REPORT="$LOGDIR/launcher_report.log"
WATCHER_LOG="$LOGDIR/watcher.log"

mkdir -p "$LOGDIR"
SETUP_SDL_ENVIRONMENT
SET_VAR "system" "foreground_process" "dolphin"

# ── Game metadata ──────────────────────────────────────────
ROM_BASE=$(basename "$ROM")
GAMEID=$(echo "$ROM_BASE" | grep -oE '[\(\[]([A-Z][A-Z0-9]{5})[\)\]]' | head -1 | tr -d '()[]')
[ -z "$GAMEID" ] && GAMEID="UNKNOWN"

GAMENAME=$(echo "$ROM_BASE" \
    | sed -E 's/\.[^.]+$//' \
    | sed -E 's/\s*[\(\[](USA|Europe|Japan|PAL|NTSC[^\)]*|World|Korea|Australia|France|Germany|Italy|Spain|Netherlands|Russia|Taiwan)[^\)]*[\)\]]//g' \
    | sed -E 's/\s*\(([A-Za-z]{2}(,[A-Za-z]{2})*)\)//g' \
    | sed -E 's/\s*[\(\[]([A-Z][A-Z0-9]{5})[\)\]]//g' \
    | sed 's/[[:space:]]*$//')

# ── Report header ──────────────────────────────────────────
{
    echo "Dolphin Rt:Core v11.5.00"
    echo "SPDW Factory Lab"
    echo "========================================"
    echo "Launcher Report - Last Session"
    echo "========================================"
    echo "Date      : $(date)"
    echo "NAME      : $NAME"
    echo "CORE      : $CORE"
    echo "ORIENT    : $ORIENT"
    echo "ROM       : $ROM"
    echo "GAMEID    : $GAMEID"
    echo "GAMENAME  : $GAMENAME"
    echo "NUMSTICKS : $NUMSTICKS"
    echo "EMUDIR    : $EMUDIR"
    echo "----------------------------------------"
} > "$REPORT"

# ── Copy INI profiles ──────────────────────────────────────
cd "$EMUDIR/Config" || exit 1

copy_profile() {
    local src="$1" dst="$2" label="$3"
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        echo "[PROFILE] $label: $src -> $dst" >> "$REPORT"
    else
        echo "[PROFILE] $label: MISSING source $src (skipped)" >> "$REPORT"
    fi
}

# ── Dolphin.ini (per profile) ──────────────────────────────
case ${CORE} in
    *compatibility*)  copy_profile "Dolphin.ini.compatibility"  "Dolphin.ini" "Dolphin.ini" ;;
    *performance*)    copy_profile "Dolphin.ini.performance"    "Dolphin.ini" "Dolphin.ini" ;;
    *rintromping*)    copy_profile "Dolphin.ini.rintromping"    "Dolphin.ini" "Dolphin.ini" ;;
    *speedhacks*)     copy_profile "Dolphin.ini.speedhacks"     "Dolphin.ini" "Dolphin.ini" ;;
    *blackscreenfix*) copy_profile "Dolphin.ini.blackscreenfix" "Dolphin.ini" "Dolphin.ini" ;;
    *sweetspot*)      copy_profile "Dolphin.ini.sweetspot"      "Dolphin.ini" "Dolphin.ini" ;;
    *default*)        copy_profile "Dolphin.ini.default"        "Dolphin.ini" "Dolphin.ini" ;;
    *)                copy_profile "Dolphin.ini.default"        "Dolphin.ini" "Dolphin.ini (fallback)" ;;
esac

# ── GFX.ini (per profile) ──────────────────────────────────
case ${CORE} in
    *compatibility*)  copy_profile "GFX.ini.compatibility"  "GFX.ini" "GFX.ini" ;;
    *performance*)    copy_profile "GFX.ini.performance"    "GFX.ini" "GFX.ini" ;;
    *rintromping*)    copy_profile "GFX.ini.rintromping"    "GFX.ini" "GFX.ini" ;;
    *speedhacks*)     copy_profile "GFX.ini.speedhacks"     "GFX.ini" "GFX.ini" ;;
    *blackscreenfix*) copy_profile "GFX.ini.blackscreenfix" "GFX.ini" "GFX.ini" ;;
    *sweetspot*)      copy_profile "GFX.ini.sweetspot"      "GFX.ini" "GFX.ini" ;;
    *default*)        copy_profile "GFX.ini.default"        "GFX.ini" "GFX.ini" ;;
    *)                copy_profile "GFX.ini.default"        "GFX.ini" "GFX.ini (fallback)" ;;
esac

# ── GCPadNew.ini ───────────────────────────────────────────
GCPAD_SRC="GCPadNew.ini.${NUMSTICKS}joy"
[ -f "$GCPAD_SRC" ] || GCPAD_SRC="GCPadNew.ini.default"
copy_profile "$GCPAD_SRC" "GCPadNew.ini" "GCPadNew.ini (${NUMSTICKS}joy)"

# ── WiimoteNew.ini ─────────────────────────────────────────
if [ "$ORIENT" = "sideways" ]; then
    WIIMOTE_SRC="WiimoteNew.ini.${NUMSTICKS}joy.sideways"
    [ -f "$WIIMOTE_SRC" ] || WIIMOTE_SRC="WiimoteNew.ini.${NUMSTICKS}joy"
    [ -f "$WIIMOTE_SRC" ] || WIIMOTE_SRC="WiimoteNew.ini.default"
else
    WIIMOTE_SRC="WiimoteNew.ini.${NUMSTICKS}joy"
    [ -f "$WIIMOTE_SRC" ] || WIIMOTE_SRC="WiimoteNew.ini.default"
fi
copy_profile "$WIIMOTE_SRC" "WiimoteNew.ini" "WiimoteNew.ini (${NUMSTICKS}joy, ${ORIENT})"

cd "$EMUDIR" || exit 1

# ── Cleanup handler ────────────────────────────────────────
DOLPHIN_PID=""
WATCHER_PID=""

cleanup() {
    echo "[Signal] Terminating..." >> "$REPORT"
    [ -n "$DOLPHIN_PID" ] && kill -TERM "$DOLPHIN_PID" 2>/dev/null
    sleep 0.2
    [ -n "$DOLPHIN_PID" ] && kill -KILL "$DOLPHIN_PID" 2>/dev/null
    [ -n "$WATCHER_PID" ] && kill -TERM "$WATCHER_PID" 2>/dev/null
    exit 0
}
trap cleanup SIGTERM SIGINT

# ── Start overlay watcher (START+SELECT → exit) ────────────
JS_DEV=$(ls /dev/input/js* 2>/dev/null | head -1)
[ -z "$JS_DEV" ] && JS_DEV="/dev/input/js0"

if [ -x "$RTSYS/overlay_exit.sh" ]; then
    "$RTSYS/overlay_exit.sh" "$JS_DEV" > "$WATCHER_LOG" 2>&1 &
    WATCHER_PID=$!
    echo "[Watcher] Started on $JS_DEV (pid=$WATCHER_PID)" >> "$REPORT"
    sleep 0.3
else
    echo "[Watcher] NOT FOUND at $RTSYS/overlay_exit.sh" >> "$REPORT"
fi

# ── Launch Dolphin ─────────────────────────────────────────
echo "[Launch] $(date)" >> "$REPORT"
"./dolphin" -e "$ROM" -u "$EMUDIR" > /dev/null 2>&1 &
DOLPHIN_PID=$!
wait "$DOLPHIN_PID"
EXIT_CODE=$?

# ── Stop watcher ───────────────────────────────────────────
[ -n "$WATCHER_PID" ] && kill -TERM "$WATCHER_PID" 2>/dev/null

{
    echo "----------------------------------------"
    echo "Exit code : $EXIT_CODE"
    echo "Ended     : $(date)"
    case $EXIT_CODE in
        0)   echo "Status    : Clean exit" ;;
        134) echo "Status    : SIGABRT" ;;
        139) echo "Status    : SIGSEGV" ;;
        143) echo "Status    : SIGTERM (user exit)" ;;
        1)   echo "Status    : General error" ;;
        *)   echo "Status    : Unknown" ;;
    esac
    echo "========================================"
} >> "$REPORT"

type CONTENT_UNSET >/dev/null 2>&1 && CONTENT_UNSET

case $EXIT_CODE in
    0|143) exit 0 ;;
    *)     exit $EXIT_CODE ;;
esac
