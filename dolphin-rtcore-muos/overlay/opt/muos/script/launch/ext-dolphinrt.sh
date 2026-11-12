#!/bin/bash
# ============================================================
# Dolphin Rt:Core — muOS Content Explorer launcher
# ============================================================
# Called by muOS as: ext-dolphinrt.sh <NAME> <CORE> <ROM>
set -u
. /opt/muos/script/var/func.sh

NAME="${1:-Dolphin}"
CORE="${2:-ext-dolphin-default-upright}"
ROM="${3:-}"

ORIENT="upright"
case "$CORE" in *-sideways) ORIENT="sideways" ;; esac
PROFILE=$(printf '%s' "$CORE" | sed -E 's/^ext-dolphin-//; s/-(upright|sideways)$//')
[ -n "$PROFILE" ] || PROFILE="default"

NUMSTICKS="$(GET_VAR "device" "board/stick" 2>/dev/null)"
case "$NUMSTICKS" in ''|*[!0-9]*) NUMSTICKS=0 ;; esac
HOME_VAL="$(GET_VAR "device" "board/home" 2>/dev/null)"
[ -n "$HOME_VAL" ] && export HOME="$HOME_VAL"
export XDG_CONFIG_HOME="${HOME:-/root}/.config"

EMUDIR="${MUOS_SHARE_DIR:-/opt/muos/share}/emulator/dolphin"
[ -d "$EMUDIR" ] || EMUDIR="/opt/muos/share/emulator/dolphin"
RTSYS="$EMUDIR/RtSys"
LOG_DIR="$RTSYS/logs"
LOG="$LOG_DIR/launcher.log"
APP_DIR="${MUOS_STORE_DIR:-/run/muos/storage}/application/Dolphin RtUI"
HOTKEY_DIR="$APP_DIR/workshop/hotkeys/Default"
HOTKEYS_INI="$HOTKEY_DIR/Hotkeys.ini"
GPTK_CFG="$HOTKEY_DIR/ext-dolphin.gptk"
GPTK_BIN="$APP_DIR/lib/gptokeyb2"
export RT_SAFE_EXIT_CONFIG="$APP_DIR/data/safe_exit.conf"

mkdir -p "$LOG_DIR" "$EMUDIR/Config"
log() { echo "$(date '+%F %T') | $*" >> "$LOG"; }

[ -x "$EMUDIR/dolphin" ] || chmod +x "$EMUDIR/dolphin" 2>/dev/null
[ -x "$EMUDIR/dolphin" ] || { log "[FATAL] $EMUDIR/dolphin missing or not executable"; exit 1; }
[ -f "$ROM" ] || { log "[FATAL] ROM not found: $ROM"; exit 1; }

# Shared profile pipeline: Content Explorer and Rt:UI now project the same
# workshop catalogue into Config/ and use the same launch script.
SHARED_RUNTIME="$APP_DIR/scripts/ce_shared_profile_runtime.sh"
SHARED_LAUNCH="$APP_DIR/scripts/launch.sh"
if [ -r "$SHARED_RUNTIME" ] && [ -r "$SHARED_LAUNCH" ]; then
    # shellcheck source=/dev/null
    . "$SHARED_RUNTIME"
    rt_resolve_ce_core "$CORE" "$APP_DIR/workshop/rtcoreprofile"

    GAME_ID="$(rt_extract_game_id "$ROM" 2>/dev/null || true)"
    SYS="GC"
    ROM_EXT="$(printf '%s' "$ROM" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')"
    case "$ROM_EXT" in
        wbfs|wia) SYS="Wii" ;;
        gcm) SYS="GC" ;;
        *)
            case "$GAME_ID" in [RSWH]*) SYS="Wii" ;; esac
            ;;
    esac

    CARD=""
    [ -n "$GAME_ID" ] && CARD="$APP_DIR/workshop/gameslibrary/rtid_$GAME_ID.ini"

    # Per-game RTID values override the Content Explorer core selection,
    # matching the precedence used by core/launcher.lua in Rt:UI.
    VALUE="$(rt_read_rtid_launch "$CARD" RtProfile)"
    if [ -n "$VALUE" ] && rt_safe_profile_name "$VALUE" \
       && [ -d "$APP_DIR/workshop/rtcoreprofile/$VALUE" ]; then
        RT_PROFILE="$VALUE"
        RT_VARIANT=""
        if [ -d "$APP_DIR/workshop/rtcoreprofile/$VALUE/lite" ] \
           || [ -d "$APP_DIR/workshop/rtcoreprofile/$VALUE/std" ] \
           || [ -d "$APP_DIR/workshop/rtcoreprofile/$VALUE/max" ]; then
            RT_VARIANT="std"
        fi
    fi

    VALUE="$(rt_read_rtid_launch "$CARD" RtProfileVariant)"
    case "$VALUE" in lite|std|max)
        if [ -d "$APP_DIR/workshop/rtcoreprofile/$RT_PROFILE/$VALUE" ]; then
            RT_VARIANT="$VALUE"
        fi
        ;;
    esac

    CONTROLLER="$(rt_read_rtid_launch "$CARD" Controller)"
    rt_safe_profile_name "$CONTROLLER" || CONTROLLER="Default"
    CTRL_SUB="GameCube"; CTRL_FILE="GCPadNew.ini"
    [ "$SYS" = "Wii" ] && { CTRL_SUB="Wii"; CTRL_FILE="WiimoteNew.ini"; }
    [ -f "$APP_DIR/workshop/controller/$CTRL_SUB/$CONTROLLER/$CTRL_FILE" ] || CONTROLLER="Default"

    HOTKEYS="$(rt_read_rtid_launch "$CARD" Hotkeys)"
    [ "$HOTKEYS" = "Disabled" ] || {
        rt_safe_profile_name "$HOTKEYS" || HOTKEYS="Default"
        [ -f "$APP_DIR/workshop/hotkeys/$HOTKEYS/Hotkeys.ini" ] || HOTKEYS="Default"
    }

    GAMESETTINGS=""
    if [ -n "$GAME_ID" ]; then
        if rt_has_active_gameset "$GAME_ID" "$APP_DIR/workshop/gamesettings"; then
            # An existing (possibly empty) ActiveConfig is authoritative.
            GAMESETTINGS="$(rt_read_active_gameset "$GAME_ID" "$APP_DIR/workshop/gamesettings" || true)"
            [ -n "$GAMESETTINGS" ] || GAMESETTINGS="Disabled"
        else
            # Migrate only cards whose canonical ActiveConfig key does not exist.
            GAMESETTINGS="$(rt_read_rtid_launch "$CARD" GameSettings)"
        fi
    fi
    if [ "$GAMESETTINGS" != "Disabled" ] && [ -n "$GAMESETTINGS" ]; then
        if ! rt_safe_leaf_name "$GAMESETTINGS" \
           || [ -z "$GAME_ID" ] \
           || [ ! -f "$APP_DIR/workshop/gamesettings/$GAME_ID/$GAMESETTINGS" ]; then
            GAMESETTINGS=""
        fi
    fi

    LOGGING="$(rt_read_rtid_launch "$CARD" Logger)"
    case "$LOGGING" in
        ""|off|Disabled) LOGGING="off" ;;
        *)
            rt_safe_profile_name "$LOGGING" || LOGGING="off"
            [ -f "$APP_DIR/workshop/logging/$LOGGING/Logger.ini" ] || LOGGING="off"
            ;;
    esac

    CHEATS="0"
    [ "$(rt_read_rtid_launch "$CARD" Cheats)" = "yes" ] && CHEATS="1"
    MODS="none"
    [ "$(rt_read_rtid_launch "$CARD" Mods)" = "yes" ] && MODS="all"
    FPS="0"; VPS="0"; SPEED="0"; OSD="1"
    [ "$(rt_read_rtid_launch "$CARD" OverlayFPS)" = "yes" ] && FPS="1"
    [ "$(rt_read_rtid_launch "$CARD" OverlayVPS)" = "yes" ] && VPS="1"
    [ "$(rt_read_rtid_launch "$CARD" OverlaySpeed)" = "yes" ] && SPEED="1"
    [ "$(rt_read_rtid_launch "$CARD" OverlayOSD)" = "no" ] && OSD="0"

    export DOLPHINUI_LOOP=1
    export RT_EMUDIR="$EMUDIR"
    log "shared profile pipeline | game_id=$GAME_ID system=$SYS profile=$RT_PROFILE tier=$RT_VARIANT orientation=$RT_ORIENT"
    exec /bin/bash "$SHARED_LAUNCH" \
        --rom="$ROM" --game-id="$GAME_ID" --sys="$SYS" --title="$NAME" \
        --profile="$RT_PROFILE" --variant="$RT_VARIANT" \
        --controller="$CONTROLLER" --hotkeys="$HOTKEYS" \
        --gamesettings="$GAMESETTINGS" --logging="$LOGGING" --mods="$MODS" \
        --cheats="$CHEATS" --safe-exit=1 --orient="$RT_ORIENT" \
        --show-fps="$FPS" --show-vps="$VPS" --show-speed="$SPEED" --show-osd="$OSD" \
        --return-to=library
fi

# Legacy fallback remains available if Rt:UI's shared runtime is absent.
SETUP_SDL_ENVIRONMENT
SET_VAR "system" "foreground_process" "dolphin"
"$RTSYS/apply_profile.sh" "$PROFILE" "$ORIENT" "$NUMSTICKS" >> "$LOG" 2>&1     || { log "[FATAL] apply_profile failed"; exit 1; }

# Content Explorer has no per-launch RTUI settings payload. Use the shipped
# Default profile, and run gptokeyb2 only when the profile explicitly selects
# keyboard mode. SDL/gamepad mode must never inject virtual keyboard events.
HOTKEY_DEVICE=""
if [ -s "$HOTKEYS_INI" ]; then
    cp -f "$HOTKEYS_INI" "$EMUDIR/Config/Hotkeys.ini"
    HOTKEY_DEVICE="$(awk -F= 'tolower($1) ~ /^[[:space:]]*device[[:space:]]*$/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$HOTKEYS_INI" 2>/dev/null)"
else
    rm -f "$EMUDIR/Config/Hotkeys.ini"
fi
log "launch | $NAME | $PROFILE | $ORIENT | $(basename "$ROM") | hotkeys=${HOTKEY_DEVICE:-Disabled}"

export LD_LIBRARY_PATH="$EMUDIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$EMUDIR" || exit 1
# Prefer the real RG35XX H joydev node. Some muOS builds expose a
# phantom js0 entry; only accept character devices and prefer js1.
JS_DEV=""
for candidate in /dev/input/js1 /dev/input/js0 /dev/input/js*; do
    [ -c "$candidate" ] || continue
    JS_DEV="$candidate"
    break
done
if [ -n "$JS_DEV" ]; then
    log "controller joydev device: $JS_DEV"
else
    log "WARN no usable /dev/input/js* character device; Safe Exit watcher disabled"
fi

WATCHER_PID=""
GPTK_PID=""
DOLPHIN_PID=""
stop_helpers() {
    [ -n "$WATCHER_PID" ] && kill -TERM "$WATCHER_PID" 2>/dev/null || true
    [ -n "$GPTK_PID" ] && kill -TERM "$GPTK_PID" 2>/dev/null || true
    WATCHER_PID=""
    GPTK_PID=""
}
on_signal() {
    [ -n "$DOLPHIN_PID" ] && kill -TERM "$DOLPHIN_PID" 2>/dev/null || true
    stop_helpers
    exit 0
}
trap on_signal TERM INT

if [ "$HOTKEY_DEVICE" = "Keyboard" ] && [ -x "$GPTK_BIN" ] && [ -s "$GPTK_CFG" ]; then
    pkill -f "$GPTK_BIN -c" 2>/dev/null || true
    sleep 0.25
    "$GPTK_BIN" -c "$GPTK_CFG" -D states,keyboard >> "$LOG_DIR/gptokeyb2-content-explorer.log" 2>&1 &
    GPTK_PID=$!
    log "gptokeyb2 pid=$GPTK_PID profile=Default"
elif [ "$HOTKEY_DEVICE" = "Keyboard" ]; then
    log "WARN keyboard hotkeys requested but gptokeyb2/config unavailable: $GPTK_BIN / $GPTK_CFG"
else
    log "gptokeyb2 not started; Device is not Keyboard"
fi
sleep 0.25  # attach to the controller before Dolphin opens it



./dolphin --platform=fbdev --video_backend=OGL -e "$ROM" -u "$EMUDIR" >> "$LOG_DIR/dolphin_debug.log" 2>&1 &
DOLPHIN_PID=$!
log "Dolphin pid=$DOLPHIN_PID"

if [ -n "$JS_DEV" ] && [ -x "$RTSYS/overlay_exit.sh" ]; then
    "$RTSYS/overlay_exit.sh" "$JS_DEV" "$DOLPHIN_PID" >/dev/null 2>&1 &
    WATCHER_PID=$!
    log "Safe Exit watcher pid=$WATCHER_PID target=$DOLPHIN_PID device=$JS_DEV config=$RT_SAFE_EXIT_CONFIG"
elif [ -z "$JS_DEV" ]; then
    log "WARN Safe Exit unavailable: no usable joydev character device"
else
    log "WARN Safe Exit watcher not installed: $RTSYS/overlay_exit.sh"
fi


EXIT_CODE=0
wait "$DOLPHIN_PID" || EXIT_CODE=$?
stop_helpers
log "Dolphin exited: $EXIT_CODE"
exit "$EXIT_CODE"
