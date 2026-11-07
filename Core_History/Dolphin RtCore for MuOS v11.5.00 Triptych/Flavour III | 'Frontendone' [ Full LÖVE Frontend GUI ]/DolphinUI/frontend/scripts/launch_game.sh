#!/bin/bash
# ============================================================
#  DolphinUI — launch_game.sh
#  SPDW Factory Lab / sirpips
# ============================================================
#  Layout (all inside frontend/, except lib/):
#    frontend/scripts/launch_game.sh         ← this file
#    frontend/scripts/livemenu/main.py       ← Live Menu daemon
#    frontend/dolphin-emu/                   ← local Dolphin
#    frontend/dolphin-emu/Config/            ← INI files
#    frontend/config/                        ← gptokeyb configs
#    frontend/data/logs/                     ← runtime logs
#    ../lib/                                 ← native binaries
#
#  Args:
#    $1  ROM_PATH       ("" for virtual entries)
#    $2  GAME_ID        (optional; auto-detected if empty/UNKNOWN)
#    $3  PROFILE        (Default | Performance | ...)
#    $4  CTRL_PROFILE   (Default | Fighting | FPS | ...)
#    $5  HOTKEYS        (true | false)
#    $6  LIVEMENU       (true | false)
#    $7  LOGGING        (true | false)
#    $8  CORE_MODE      (local | external)
#    $9  MODE           (--gc-console | --wii-menu | "")
#
#  Notes:
#    * Config is applied by the frontend (profile_manager.lua) BEFORE
#      this script runs. We only touch Config/Hotkeys.ini when LiveMenu
#      is enabled, because the Live Menu injects keyboard hotkeys via
#      uinput and Dolphin needs the keyboard-device bindings installed.
#    * External mode delegates entirely to muOS's ext-dolphin.sh.
#    * Live Menu is a single daemon (main.py) that watches the pad
#      and opens the curses overlay in-process. It now receives the
#      real Dolphin PID (not the shell PID).
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"        # frontend/scripts
APP_DIR="$(dirname "$SCRIPT_DIR")"                 # frontend
BUNDLE_DIR="$(dirname "$APP_DIR")"                 # project root

LOCAL_EMU="$APP_DIR/dolphin-emu"
EXTERNAL_EMU="/opt/muos/share/emulator/dolphin"
CONFIG_BASE="$APP_DIR/config"
LIB_DIR="$BUNDLE_DIR/lib"
LOG_BASE="$APP_DIR/data/logs"
LIVEMENU_PY="$SCRIPT_DIR/livemenu/main.py"
INTERNAL_HOTKEYS="$SCRIPT_DIR/livemenu/Hotkeys.internal.ini"

ROM_PATH="${1:-}"
INPUT_GAME_ID="${2:-}"
PROFILE="${3:-Default}"
CTRL_PROFILE="${4:-}"
HOTKEYS="${5:-true}"
LIVEMENU="${6:-false}"
LOGGING="${7:-false}"
CORE_MODE="${8:-local}"
MODE="${9:-}"

mkdir -p "$LOG_BASE"

# ── Resolve emulator dir ─────────────────────────────────────
if [ "$CORE_MODE" = "external" ] && [ -x "$EXTERNAL_EMU/dolphin" ]; then
    EMU_DIR="$EXTERNAL_EMU"
else
    EMU_DIR="$LOCAL_EMU"
    CORE_MODE="local"
fi

# ── Log dir: external writes next to the emu, local writes in data/logs ──
if [ "$CORE_MODE" = "external" ]; then
    LOG_DIR="$EXTERNAL_EMU/rtdata/logs"
else
    LOG_DIR="$LOG_BASE"
fi
mkdir -p "$LOG_DIR"

# ── System info ──────────────────────────────────────────────
MUOS_VER="unknown"; MUOS_BUILD=""; DEVICE="unknown"; TESTER="unknown"
[ -f /opt/muos/config/system/version ] && MUOS_VER=$(cat /opt/muos/config/system/version 2>/dev/null)
[ -f /opt/muos/config/system/build ]   && MUOS_BUILD=$(cat /opt/muos/config/system/build 2>/dev/null)
[ -f /opt/muos/config/board/name ]     && DEVICE=$(cat /opt/muos/config/board/name 2>/dev/null)
[ -n "${USER:-}" ] && TESTER="$USER"

# ── Game ID extraction ───────────────────────────────────────
extract_game_id() {
    local rom="$1"
    if [ -z "$rom" ] || [ ! -f "$rom" ]; then echo "UNKNOWN"; return; fi

    local base
    base=$(basename "$rom")

    # 1. Bracketed ID in filename: (GXXXXX) or [GXXXXX]
    local fn_id
    fn_id=$(echo "$base" | grep -oE '[\(\[]([A-Z][A-Z0-9]{5})[\)\]]' \
            | head -1 | tr -d '()[]')
    if [ -n "$fn_id" ]; then echo "$fn_id"; return; fi

    # 2. Magic-based detection
    local magic
    magic=$(xxd -p -l 4 "$rom" 2>/dev/null | tr -d '\n')
    [ -z "$magic" ] && magic=$(od -An -tx1 -N4 "$rom" 2>/dev/null | tr -d ' \n')

    case "$magic" in
        52565a01|52565a)     # 'RVZ\x01' or 'RVZ'
            local rvz_id
            rvz_id=$(timeout 2 dd if="$rom" bs=1 skip=64 count=192 2>/dev/null \
                     | tr -d '\0' \
                     | grep -aoE '\b[A-Z][A-Z0-9]{5}\b' \
                     | grep -vE '^(RVZ|WBFS|WIA|ISO|GCM)$' \
                     | head -1)
            [ -n "$rvz_id" ] && { echo "$rvz_id"; return; }
            ;;
        57424653)            # 'WBFS'
            local wbfs_id
            wbfs_id=$(timeout 2 dd if="$rom" bs=1 skip=512 count=4096 2>/dev/null \
                     | tr -d '\0' \
                     | grep -aoE '\b[A-Z][A-Z0-9]{5}\b' \
                     | grep -vE '^(RVZ|WBFS|WIA|ISO|GCM)$' \
                     | head -1)
            [ -n "$wbfs_id" ] && { echo "$wbfs_id"; return; }
            ;;
        57494101|574941)     # 'WIA\x01' or 'WIA'
            local wia_id
            wia_id=$(timeout 2 dd if="$rom" bs=1 skip=64 count=192 2>/dev/null \
                     | tr -d '\0' \
                     | grep -aoE '\b[A-Z][A-Z0-9]{5}\b' \
                     | grep -vE '^(RVZ|WBFS|WIA|ISO|GCM)$' \
                     | head -1)
            [ -n "$wia_id" ] && { echo "$wia_id"; return; }
            ;;
        *)
            # ISO / GCM: ID at offset 0
            local iso_id
            iso_id=$(timeout 2 dd if="$rom" bs=1 count=6 2>/dev/null \
                     | tr -d '\0' | tr -cd '[:alnum:]')
            if [ ${#iso_id} -eq 6 ]; then echo "$iso_id"; return; fi
            ;;
    esac

    # 3. Universal last-resort scan (first 4 KB)
    local any_id
    any_id=$(timeout 2 dd if="$rom" bs=1 count=4096 2>/dev/null \
             | tr -d '\0' \
             | grep -aoE '\b[A-Z][A-Z0-9]{5}\b' \
             | grep -vE '^(RVZ|WBFS|WIA|ISO|GCM)$' \
             | head -1)
    [ -n "$any_id" ] && { echo "$any_id"; return; }

    echo "UNKNOWN"
}

# ── Game name cleanup ────────────────────────────────────────
clean_game_name() {
    local rom="$1"
    if [ -z "$rom" ]; then echo ""; return; fi
    local base
    base=$(basename "$rom")
    echo "$base" \
        | sed -E 's/\.[^.]+$//' \
        | sed -E 's/\s*[\(\[](USA|Europe|Japan|PAL|NTSC[^\)]*|En[^\)]*|Fr[^\)]*|De[^\)]*|Es[^\)]*|It[^\)]*|Multi[^\)]*)[\)\]]//g' \
        | sed -E 's/\s*[\(\[]([A-Z][A-Z0-9]{5})[\)\]]//g' \
        | sed -E 's/\s*[\(\[](Rev [0-9]+|v[0-9.]+)[\)\]]//g' \
        | sed 's/[[:space:]]*$//'
}

# ── Resolve GAME_ID / GAME_NAME ──────────────────────────────
if [ -n "$MODE" ]; then
    case "$MODE" in
        "--gc-console") GAME_ID="GC-MENU";  GAME_NAME="GameCube Console" ;;
        "--wii-menu")   GAME_ID="WII-MENU"; GAME_NAME="Wii System Menu" ;;
        *)              GAME_ID="UNKNOWN";  GAME_NAME="Virtual Entry" ;;
    esac
elif [ -n "$INPUT_GAME_ID" ] && [ "$INPUT_GAME_ID" != "UNKNOWN" ]; then
    GAME_ID="$INPUT_GAME_ID"
    GAME_NAME=$(clean_game_name "$ROM_PATH")
else
    GAME_ID=$(extract_game_id "$ROM_PATH")
    GAME_NAME=$(clean_game_name "$ROM_PATH")
fi

[ -z "$GAME_NAME" ] && GAME_NAME="Unknown Title"

# ── Log files ────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="$LOG_DIR/dolphinrtcore_${PROFILE}_${GAME_ID}_${TIMESTAMP}.log"
REPORT="$LOG_DIR/launcher_report.log"
LAUNCHER_LOG="$LOG_BASE/launcher_$(date +%Y%m%d_%H%M%S).log"

log() { echo "[$(date '+%F %T')] $*" >> "$LAUNCHER_LOG"; }

{
    echo "Dolphin Rt:Core v11.0.0 'Light Arsenal'"
    echo "DolphinUI Launcher / SPDW Factory Lab"
    echo "========================================"
    echo "Dolphin Launch Log"
    echo "Date: $(date)"
    echo "NAME: $GAME_NAME"
    echo "CORE: $PROFILE"
    echo "ROM: $ROM_PATH"
    echo "GAMEID: $GAME_ID"
    echo "GAMENAME: $GAME_NAME"
    echo "CORE_MODE: $CORE_MODE"
    echo "CTRL: $CTRL_PROFILE"
    echo "HOTKEYS: $HOTKEYS"
    echo "LIVEMENU: $LIVEMENU"
    echo "LOGGING: $LOGGING"
    echo "EMUDIR: $EMU_DIR"
    echo "TESTER: $TESTER"
    echo "DEVICE: $DEVICE"
    echo "MUOS_VER: $MUOS_VER ($MUOS_BUILD)"
    echo "========================================"
} > "$LOGFILE"

{
    echo "DolphinUI Launcher Report"
    echo "========================================"
    echo "Date        : $(date)"
    echo "Session log : $(basename "$LOGFILE")"
    echo "NAME        : $GAME_NAME"
    echo "CORE        : $PROFILE"
    echo "ROM         : $ROM_PATH"
    echo "GAMEID      : $GAME_ID"
    echo "GAMENAME    : $GAME_NAME"
    echo "CORE_MODE   : $CORE_MODE"
    echo "TESTER      : $TESTER"
    echo "DEVICE      : $DEVICE"
    echo "MUOS_VER    : $MUOS_VER ($MUOS_BUILD)"
    echo "========================================"
} > "$REPORT"

log "=== DolphinUI Launch ==="
log "ROM=$ROM_PATH GAME_ID=$GAME_ID PROFILE=$PROFILE CORE=$CORE_MODE MODE=$MODE"

if [ -f "$ROM_PATH" ]; then
    MAGIC_HEX=$(xxd -p -l 8 "$ROM_PATH" 2>/dev/null | tr -d '\n' || echo "????????????????")
    log "Magic: $MAGIC_HEX"
fi

# ── External core: delegate entirely to muOS ─────────────────
if [ "$CORE_MODE" = "external" ] && [ -x "/opt/muos/script/launch/ext-dolphin.sh" ]; then
    log "Delegating to /opt/muos/script/launch/ext-dolphin.sh"
    NAME="$(basename "${ROM_PATH:-dolphin}")"
    CORE="ext-dolphin-${PROFILE}"
    exec /opt/muos/script/launch/ext-dolphin.sh "$NAME" "$CORE" "$ROM_PATH"
fi

# ── Local mode ───────────────────────────────────────────────
log "Local mode: using existing dolphin-emu/Config/"

cd "$EMU_DIR" || { log "FATAL: cannot cd to $EMU_DIR"; exit 1; }

# muOS env (best-effort)
if [ -f /opt/muos/script/var/func.sh ]; then
    . /opt/muos/script/var/func.sh
    type SETUP_SDL_ENVIRONMENT >/dev/null 2>&1 && SETUP_SDL_ENVIRONMENT
    type SET_VAR >/dev/null 2>&1 && SET_VAR "system" "foreground_process" "dolphin"
fi

# ── Live Menu: install internal Hotkeys.ini BEFORE Dolphin starts ──
# Dolphin reads Hotkeys.ini once at startup, so this must happen first.
# When LiveMenu is ON we override the user's Hotkeys.ini with the
# keyboard-device bindings that the uinput injector expects. The user's
# previous file is preserved as Hotkeys.ini.user; the frontend re-applies
# the chosen hotkey profile on every launch, so no state is lost.
if [ "$LIVEMENU" = "true" ] && [ -f "$INTERNAL_HOTKEYS" ]; then
    if [ -f "$EMU_DIR/Config/Hotkeys.ini" ]; then
        cp -f "$EMU_DIR/Config/Hotkeys.ini" "$EMU_DIR/Config/Hotkeys.ini.user" 2>/dev/null || true
    fi
    cp -f "$INTERNAL_HOTKEYS" "$EMU_DIR/Config/Hotkeys.ini"
    log "Installed internal Hotkeys.ini for LiveMenu (backup: Hotkeys.ini.user)"
elif [ "$LIVEMENU" = "true" ]; then
    log "WARN: LiveMenu on but $INTERNAL_HOTKEYS not found"
fi

# ── gptokeyb2 (keyboard emulation for the pad) ──────────────
GPTOKEYB_PID=""
if [ "$HOTKEYS" = "true" ]; then
    GPTK_FILE="$CONFIG_BASE/ext-dolphin.gptk"
    if [ "$LIVEMENU" = "true" ] && [ -f "$CONFIG_BASE/live_menu.gptk" ]; then
        GPTK_FILE="$CONFIG_BASE/live_menu.gptk"
    fi

    GPTOKEYB_BIN=""
    if [ -x "$LIB_DIR/gptokeyb2.armhf" ]; then
        GPTOKEYB_BIN="$LIB_DIR/gptokeyb2.armhf"
    elif [ -x "$LIB_DIR/gptokeyb2" ]; then
        GPTOKEYB_BIN="$LIB_DIR/gptokeyb2"
    elif [ -x /mnt/mmc/MUOS/PortMaster/gptokeyb2 ]; then
        GPTOKEYB_BIN="/mnt/mmc/MUOS/PortMaster/gptokeyb2"
    fi

    if [ -n "$GPTOKEYB_BIN" ] && [ -f "$GPTK_FILE" ]; then
        log "Starting keymapper: $GPTOKEYB_BIN -c $GPTK_FILE -k dolphin"
        killall -9 gptokeyb gptokeyb2 gptokeyb2.armhf 2>/dev/null

        if [ -f "$LIB_DIR/libinterpose.armhf.so" ]; then
            ( LD_PRELOAD="$LIB_DIR/libinterpose.armhf.so" \
              "$GPTOKEYB_BIN" -k "dolphin" -c "$GPTK_FILE" \
              >> "$LOGFILE" 2>&1 ) &
        else
            ( "$GPTOKEYB_BIN" -k "dolphin" -c "$GPTK_FILE" \
              >> "$LOGFILE" 2>&1 ) &
        fi
        GPTOKEYB_PID=$!
        log "Keymapper PID=$GPTOKEYB_PID"
    else
        log "WARN: no keymapper binary or missing config ($GPTK_FILE)"
    fi
fi

# ── Build dolphin args ───────────────────────────────────────
ARGS=( -u "$EMU_DIR" )

case "$MODE" in
    "--gc-console")
        ARGS+=( -b )
        log "Booting GameCube System Menu"
        ;;
    "--wii-menu")
        ARGS+=( -b -n 0000000100000002 )
        log "Booting Wii System Menu"
        ;;
    *)
        if [ -n "$ROM_PATH" ] && [ -f "$ROM_PATH" ]; then
            ARGS+=( -e "$ROM_PATH" )
        else
            log "FATAL: no ROM and no virtual mode"
            exit 2
        fi
        ;;
esac

chmod +x "$EMU_DIR/dolphin" 2>/dev/null

# ── Start Dolphin in background, capture its real PID ───────
log "Exec: ./dolphin ${ARGS[*]}"
echo "Starting Dolphin: $(date)" >> "$LOGFILE"

"./dolphin" "${ARGS[@]}" >> "$LOGFILE" 2>&1 &
DOLPHIN_PID=$!
log "Dolphin started, PID=$DOLPHIN_PID"

# ── Live Menu daemon (single-process watcher + overlay) ─────
# Started AFTER Dolphin so it receives the real Dolphin PID, not this
# shell's PID. This was the actual bug in the previous revision.
LIVEMENU_PID=""
if [ "$LIVEMENU" = "true" ] && [ -f "$LIVEMENU_PY" ]; then
    log "Starting LiveMenu daemon with dolphin-pid=$DOLPHIN_PID"
    PYTHONPATH="$SCRIPT_DIR/livemenu:${PYTHONPATH:-}" \
        python3 "$LIVEMENU_PY" daemon --dolphin-pid "$DOLPHIN_PID" \
        >> "$LOGFILE" 2>&1 &
    LIVEMENU_PID=$!
    log "LiveMenu daemon PID=$LIVEMENU_PID"
else
    if [ "$LIVEMENU" = "true" ]; then
        log "WARN: LiveMenu enabled but $LIVEMENU_PY not found"
    fi
fi

# ── Wait for Dolphin to exit ─────────────────────────────────
wait "$DOLPHIN_PID"
EC=$?
echo "Dolphin exited with code $EC: $(date)" >> "$LOGFILE"

case $EC in
    0)   echo "EXIT_INTERPRETATION: Clean exit" >> "$LOGFILE" ;;
    134) echo "EXIT_INTERPRETATION: SIGABRT (memory corruption / assert)" >> "$LOGFILE" ;;
    139) echo "EXIT_INTERPRETATION: SIGSEGV (segmentation fault)" >> "$LOGFILE" ;;
    143) echo "EXIT_INTERPRETATION: SIGTERM (user exit via Live Menu)" >> "$LOGFILE" ;;
    1)   echo "EXIT_INTERPRETATION: General error" >> "$LOGFILE" ;;
    *)   echo "EXIT_INTERPRETATION: Unknown exit code ($EC)" >> "$LOGFILE" ;;
esac
log "Dolphin exit=$EC"

# ── Cleanup ──────────────────────────────────────────────────
if [ -n "$LIVEMENU_PID" ]; then
    kill -TERM "$LIVEMENU_PID" 2>/dev/null
    sleep 0.2
    kill -9 "$LIVEMENU_PID" 2>/dev/null
    pkill -9 -P "$LIVEMENU_PID" 2>/dev/null
    log "LiveMenu daemon stopped"
fi
if [ -n "$GPTOKEYB_PID" ]; then
    kill -9 "$GPTOKEYB_PID" 2>/dev/null
    log "Keymapper stopped"
fi
killall -9 gptokeyb gptokeyb2 gptokeyb2.armhf 2>/dev/null

type CONTENT_UNSET >/dev/null 2>&1 && CONTENT_UNSET

exit $EC