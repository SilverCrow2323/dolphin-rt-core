#!/bin/bash
# ============================================================
#  Dolphin Rt:UI — launcher v3
#  Modelled on /opt/muos/script/launch/ext-dolphinrt.sh (the path that is
#  known to work on the device): environment, RtSys profile baseline, then
#  "cd <emu dir> && ./dolphin -e ROM -u <emu dir>". No session dir, no ROM/ID
#  detection: the UI already knows the game and passes everything explicitly.
#
#  Layered settings, in this order:
#    1. RtSys/apply_profile.sh   (device baseline, orientation, sticks)
#    2. workshop profile         (Default <- family[/tier] <- game settings)
#    3. controller, hotkeys, logging
#    4. cheats + overlays        (Dolphin.ini / GFX.ini keys)
#    5. graphic mods             (only the selected ones are active)
#
#  Args (all --key=value): rom game-id sys title profile variant controller
#    hotkeys mods logging cheats safe-exit orient show-fps show-vps show-speed
#    show-osd return-to
#
#  Env:
#    DOLPHINUI_LOOP=1  — running inside mux_launch.sh's loop. Skip
#                        CONTENT_UNSET and restart_frontend: mux_launch.sh
#                        will re-launch LÖVE after we return.
# ============================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(dirname "$SCRIPT_DIR")"
[ -r /opt/muos/script/var/func.sh ] && . /opt/muos/script/var/func.sh >/dev/null 2>&1 || true

LOOP_MODE="${DOLPHINUI_LOOP:-0}"

# ── Defaults ────────────────────────────────────────────────
ROM=""; GAME_ID=""; SYS="GC"; TITLE=""
PROFILE="Default"; VARIANT=""; CONTROLLER=""; HOTKEYS=""
MODS="none"; LOGGING="off"; CHEATS="0"; SAFE_EXIT="1"; ORIENT=""
SHOW_FPS="0"; SHOW_VPS="0"; SHOW_SPEED="0"; SHOW_OSD="1"
RETURN_TO="library"

for arg in "$@"; do
    case "$arg" in
        --rom=*)         ROM="${arg#*=}" ;;
        --game-id=*)     GAME_ID="${arg#*=}" ;;
        --sys=*)         SYS="${arg#*=}" ;;
        --title=*)       TITLE="${arg#*=}" ;;
        --profile=*)     PROFILE="${arg#*=}" ;;
        --variant=*)     VARIANT="${arg#*=}" ;;
        --controller=*)  CONTROLLER="${arg#*=}" ;;
        --hotkeys=*)     HOTKEYS="${arg#*=}" ;;
        --mods=*)        MODS="${arg#*=}" ;;
        --logging=*)     LOGGING="${arg#*=}" ;;
        --cheats=*)      CHEATS="${arg#*=}" ;;
        --safe-exit=*)   SAFE_EXIT="${arg#*=}" ;;
        --orient=*)      ORIENT="${arg#*=}" ;;
        --show-fps=*)    SHOW_FPS="${arg#*=}" ;;
        --show-vps=*)    SHOW_VPS="${arg#*=}" ;;
        --show-speed=*)  SHOW_SPEED="${arg#*=}" ;;
        --show-osd=*)    SHOW_OSD="${arg#*=}" ;;
        --return-to=*)   RETURN_TO="${arg#*=}" ;;
        *) ;;                                   # unknown flags are ignored
    esac
done
[ "$SYS" = "WII" ] && SYS="Wii"
[ -z "$ORIENT" ] && ORIENT="upright"

# ── Paths ───────────────────────────────────────────────────
EMU="/opt/muos/share/emulator/dolphin"
DOLPHIN="$EMU/dolphin"
RTSYS="$EMU/RtSys"
CONFIG="$EMU/Config"
WORKSHOP="$GAME_DIR/workshop"
RT_PROFILES="$WORKSHOP/rtcoreprofile"
BASE_DIR="$WORKSHOP/base"
LOG_DIR="$GAME_DIR/data/logs"
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR" "$CONFIG" 2>/dev/null
LOG="$LOG_DIR/launch_${GAME_ID:-game}_$TS.log"
DOLPHIN_LOG="$LOG_DIR/dolphin_${GAME_ID:-game}_$TS.log"
# keep the newest 12 launch logs
ls -t "$LOG_DIR"/launch_*.log 2>/dev/null | tail -n +13 | while IFS= read -r f; do rm -f "$f"; done
ls -t "$LOG_DIR"/dolphin_*.log 2>/dev/null | tail -n +13 | while IFS= read -r f; do rm -f "$f"; done

log() { echo "[$(date '+%T')] $*" >> "$LOG"; }

WATCHER_PID=""; GPTK_PID=""

# ── helpers ─────────────────────────────────────────────────
# set_ini_key FILE SECTION KEY VALUE — edits in place, creates what is missing
set_ini_key() {
    local file="$1" section="$2" key="$3" value="$4"
    [ -f "$file" ] || : > "$file"
    if awk -v sec="[$section]" -v k="$key" '
        /^\[/ { in_sec = ($0 == sec) }
        in_sec && $0 ~ "^[ \t]*"k"[ \t]*=" { found = 1; exit }
        END { exit !found }' "$file"; then
        awk -v sec="[$section]" -v k="$key" -v v="$value" '
            /^\[/ { in_sec = ($0 == sec) }
            in_sec && $0 ~ "^[ \t]*"k"[ \t]*=" { print k " = " v; next }
            { print }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    elif grep -q "^\[$section\]" "$file"; then
        awk -v sec="[$section]" -v line="$key = $value" '
            { print }
            $0 == sec { print line }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    else
        printf '\n[%s]\n%s = %s\n' "$section" "$key" "$value" >> "$file"
    fi
}

stop_helpers() {
    [ -n "$WATCHER_PID" ] && kill -TERM "$WATCHER_PID" 2>/dev/null
    [ -n "$GPTK_PID" ] && kill -TERM "$GPTK_PID" 2>/dev/null
    killall -q gptokeyb2 gptokeyb2.armhf 2>/dev/null || true
    WATCHER_PID=""; GPTK_PID=""
}

# ── restart_frontend ───────────────────────────────────────
# In loop mode mux_launch.sh handles the re-launch of LÖVE itself; we must
# not fork a second frontend or muOS will see the app exit in the middle.
restart_frontend() {
    local code="${1:-0}"
    if [ "$LOOP_MODE" = "1" ]; then
        log "loop mode: skipping restart_frontend (return-to=$RETURN_TO)"
        return 0
    fi
    local launcher="$GAME_DIR/mux_launch.sh"
    export DOLPHINUI_LAST_EXIT="$code" DOLPHINUI_LAST_TITLE="$TITLE" DOLPHINUI_LAST_ID="$GAME_ID"
    if [ -f "$launcher" ]; then
        bash "$launcher" --return-to="$RETURN_TO" >> "$LOG_DIR/frontend.log" 2>&1
    else
        log "WARN: $launcher missing, frontend not restarted"
    fi
}

fatal() {                                   # fatal <code> <message>
    local code="$1"; shift
    log "FATAL: $*"
    stop_helpers
    if [ "$LOOP_MODE" != "1" ]; then
        type CONTENT_UNSET >/dev/null 2>&1 && CONTENT_UNSET
    fi
    restart_frontend "$code"
    exit "$code"
}
trap 'stop_helpers; exit 0' TERM INT

log "=== launch v3 | $TITLE | id=$GAME_ID sys=$SYS | profile=$PROFILE variant=${VARIANT:-none} | controller=${CONTROLLER:-auto} hotkeys=${HOTKEYS:-auto} mods=$MODS cheats=$CHEATS loop=$LOOP_MODE"
log "rom=$ROM"

[ -x "$DOLPHIN" ] || fatal 1 "Dolphin not found or not executable: $DOLPHIN"
[ -f "$ROM" ] || fatal 2 "ROM not found: $ROM"

# ── 1. Environment (same as ext-dolphinrt.sh) ───────────────
NUMSTICKS=$(cat /opt/muos/device/config/board/stick 2>/dev/null || echo 0)
[ -z "$NUMSTICKS" ] && NUMSTICKS=0
if type GET_VAR >/dev/null 2>&1; then
    HOME_VAL="$(GET_VAR "device" "board/home" 2>/dev/null)"
    [ -n "$HOME_VAL" ] && export HOME="$HOME_VAL"
fi
export XDG_CONFIG_HOME="${HOME:-/root}/.config"
type SETUP_SDL_ENVIRONMENT >/dev/null 2>&1 && SETUP_SDL_ENVIRONMENT
type SET_VAR >/dev/null 2>&1 && SET_VAR "system" "foreground_process" "dolphin"

# ── 2. Profile: family / tier ───────────────────────────────
# "RtPrime (Std)" → family RtPrime, tier std. Tiers exist ONLY for Rt:CORE
# families (profile folders that have lite/ std/ max/ inside).
PROFILE_RE='^(.+)[[:space:]]+\(([^)]+)\)[[:space:]]*$'
if [[ "$PROFILE" =~ $PROFILE_RE ]]; then
    VARIANT=$(printf '%s' "${BASH_REMATCH[2]}" | tr 'A-Z' 'a-z')
    PROFILE="${BASH_REMATCH[1]}"
fi
IS_FAMILY=0
for _t in lite std max; do [ -d "$RT_PROFILES/$PROFILE/$_t" ] && IS_FAMILY=1; done
if [ "$IS_FAMILY" = "1" ]; then
    case "$VARIANT" in lite|std|max) ;; *) VARIANT="std" ;; esac
else
    VARIANT=""                              # plain profile: no tiers
fi
log "profile resolved: $PROFILE tier=${VARIANT:-none} family=$IS_FAMILY"

# ── 3. Device baseline (RtSys) ──────────────────────────────
# Use the matching RtSys profile when there is one, otherwise "default".
if [ -x "$RTSYS/apply_profile.sh" ]; then
    RT_NAME="default"
    if [ -d "$RTSYS/Config" ]; then
        want="$(printf '%s' "$PROFILE" | tr 'A-Z ' 'a-z_')"
        for cand in "${want}-${VARIANT}" "${want}_${VARIANT}" "$want"; do
            [ -z "$VARIANT" ] && [ "$cand" != "$want" ] && continue
            for d in "$RTSYS/Config"/*/; do
                [ -d "$d" ] || continue
                nm="$(basename "$d")"
                if [ "$(printf '%s' "$nm" | tr 'A-Z ' 'a-z_')" = "$cand" ]; then RT_NAME="$nm"; break 2; fi
            done
        done
    fi
    if "$RTSYS/apply_profile.sh" "$RT_NAME" "$ORIENT" "$NUMSTICKS" >> "$LOG" 2>&1; then
        log "RtSys baseline applied: $RT_NAME $ORIENT sticks=$NUMSTICKS"
    else
        log "WARN: RtSys apply_profile.sh failed for '$RT_NAME' (continuing)"
    fi
else
    log "RtSys/apply_profile.sh not present: workshop profile only"
fi

# ── 4. Workshop profile (Default <- profile[/tier] <- game settings) ──
PDIR=""
for cand in "$RT_PROFILES/$PROFILE/$VARIANT" "$RT_PROFILES/$PROFILE" "$RT_PROFILES/Default"; do
    [ -n "$cand" ] && [ -f "$cand/Dolphin.ini" ] && { PDIR="$cand"; break; }
done
if [ -z "$PDIR" ]; then
    log "WARN: no workshop profile found for '$PROFILE'; Config left as the baseline"
else
    MERGE="$GAME_DIR/tools/rt_profile_merge.py"
    TMPD="$GAME_DIR/data/tmp_cfg"
    rm -rf "$TMPD"; mkdir -p "$TMPD"
    merged=0
    if command -v python3 >/dev/null 2>&1 && [ -f "$MERGE" ]; then
        if python3 "$MERGE" --default-dir "$RT_PROFILES/Default" --profile-dir "$PDIR" \
                --out-dir "$TMPD" --game-id "$GAME_ID" --workshop "$WORKSHOP" >> "$LOG" 2>&1 \
           && [ -s "$TMPD/Dolphin.ini" ]; then
            merged=1
        fi
    fi
    for f in Dolphin.ini GFX.ini; do
        if [ "$merged" = "1" ] && [ -s "$TMPD/$f" ]; then cp -f "$TMPD/$f" "$CONFIG/$f"; log "applied $f (merged)"
        elif [ -f "$PDIR/$f" ]; then cp -f "$PDIR/$f" "$CONFIG/$f"; log "applied $f <- $PDIR"
        fi
    done
    rm -rf "$TMPD"
fi

# ── 5. Controller ───────────────────────────────────────────
CTRL_SUB="GameCube"; CTRL_FILE="GCPadNew.ini"
[ "$SYS" = "Wii" ] && { CTRL_SUB="Wii"; CTRL_FILE="WiimoteNew.ini"; }
for c in "$WORKSHOP/controller/$CTRL_SUB/${CONTROLLER:-Default}/$CTRL_FILE" \
         "$WORKSHOP/controller/$CTRL_SUB/Default/$CTRL_FILE" "$BASE_DIR/$CTRL_FILE"; do
    if [ -f "$c" ]; then cp -f "$c" "$CONFIG/$CTRL_FILE"; log "controller $CTRL_FILE <- $c"; break; fi
done

# ── 6. Hotkeys + logging ────────────────────────────────────
if [ "${HOTKEYS:-}" != "Disabled" ]; then
    for c in "$WORKSHOP/hotkeys/${HOTKEYS:-Default}/Hotkeys.ini" "$WORKSHOP/hotkeys/Default/Hotkeys.ini" "$BASE_DIR/Hotkeys.ini"; do
        if [ -f "$c" ]; then cp -f "$c" "$CONFIG/Hotkeys.ini"; log "Hotkeys.ini <- $c"; break; fi
    done
fi
case "${LOGGING:-off}" in
    off|Disabled|"") ;;
    *) [ -f "$WORKSHOP/logging/$LOGGING/Logger.ini" ] && cp -f "$WORKSHOP/logging/$LOGGING/Logger.ini" "$CONFIG/Logger.ini" && log "Logger.ini <- $LOGGING" ;;
esac

# ── 7. Cheats + overlays ────────────────────────────────────
if [ "$CHEATS" = "1" ]; then set_ini_key "$CONFIG/Dolphin.ini" "General" "EnableCheats" "True"
else set_ini_key "$CONFIG/Dolphin.ini" "General" "EnableCheats" "False"; fi
tf() { [ "$1" = "1" ] && echo True || echo False; }
set_ini_key "$CONFIG/GFX.ini" "Settings" "ShowFPS" "$(tf "$SHOW_FPS")"
set_ini_key "$CONFIG/GFX.ini" "Settings" "ShowVPS" "$(tf "$SHOW_VPS")"
set_ini_key "$CONFIG/GFX.ini" "Settings" "ShowSpeed" "$(tf "$SHOW_SPEED")"
set_ini_key "$CONFIG/Dolphin.ini" "Interface" "OnScreenDisplayMessages" "$(tf "$SHOW_OSD")"
log "cheats=$CHEATS overlays fps=$SHOW_FPS vps=$SHOW_VPS speed=$SHOW_SPEED osd=$SHOW_OSD"

# ── 8. Graphic mods: only the selected ones are active ──────
# --mods=none | all | name1,name2   (folder names in Load/GraphicMods)
want_mod() {
    case "$2" in none|"") return 1 ;; all) return 0 ;; esac
    local IFS=',' m
    for m in $2; do [ "$m" = "$1" ] && return 0; done
    return 1
}
GM_ON="$EMU/Load/GraphicMods"; GM_OFF="$EMU/Load/GraphicMods.off"
if [ -d "$GM_ON" ] || [ -d "$GM_OFF" ]; then
    mkdir -p "$GM_ON" "$GM_OFF" 2>/dev/null
    for d in "$GM_ON"/*/; do
        [ -d "$d" ] || continue; n="$(basename "$d")"
        want_mod "$n" "$MODS" || { [ -e "$GM_OFF/$n" ] || mv "${d%/}" "$GM_OFF/$n"; }
    done
    for d in "$GM_OFF"/*/; do
        [ -d "$d" ] || continue; n="$(basename "$d")"
        want_mod "$n" "$MODS" && { [ -e "$GM_ON/$n" ] || mv "${d%/}" "$GM_ON/$n"; }
    done
    log "mods active: $(ls -1 "$GM_ON" 2>/dev/null | tr '\n' ',')"
fi

# ── 8b. Mod Vault: Textures / WiiSDSync / Riivolution / DynamicInputTextures ──
# data/mods_plan.txt (scritto dalla UI, una riga per voce):
#   ON|<Cat>|<nome>            la voce deve stare in Load/<Cat>   (la riporta da .off)
#   OFF|<Cat>|<nome>           parcheggiala in Load/<Cat>.off
#   LINK|<Cat>|<nome>|<GAMEID> link Load/<Cat>/<GAMEID> -> <nome> (Dolphin carica per ID);
#                              il link viene rimosso a fine partita
MODS_PLAN="$GAME_DIR/data/mods_plan.txt"
MODS_LINKS="$GAME_DIR/data/mods_links.txt"
mods_cleanup_links() {
    [ -f "$MODS_LINKS" ] || return 0
    while IFS= read -r lp; do
        [ -n "$lp" ] && [ -L "$lp" ] && rm -f "$lp"
    done < "$MODS_LINKS"
    rm -f "$MODS_LINKS"
}
mods_cleanup_links                       # avanzi di una sessione interrotta
if [ -f "$MODS_PLAN" ]; then
    while IFS='|' read -r act cat name gid; do
        [ -n "$cat" ] && [ -n "$name" ] || continue
        M_ON="$EMU/Load/$cat"; M_OFF="$EMU/Load/$cat.off"
        case "$act" in
            ON)
                if [ ! -e "$M_ON/$name" ] && [ -e "$M_OFF/$name" ]; then
                    mkdir -p "$M_ON" && mv "$M_OFF/$name" "$M_ON/$name"
                fi ;;
            OFF)
                if [ ! -e "$M_OFF/$name" ] && [ -e "$M_ON/$name" ]; then
                    mkdir -p "$M_OFF" && mv "$M_ON/$name" "$M_OFF/$name"
                fi ;;
            LINK)
                if [ -n "$gid" ] && [ ! -e "$M_ON/$gid" ] && [ -d "$M_ON/$name" ]; then
                    if ln -s "$M_ON/$name" "$M_ON/$gid" 2>/dev/null; then
                        echo "$M_ON/$gid" >> "$MODS_LINKS"
                        log "mods: link $cat/$gid -> $name"
                    else
                        log "WARN: mods: cannot link $cat/$name (filesystem without symlinks?)"
                    fi
                fi ;;
        esac
    done < "$MODS_PLAN"
    log "mods plan applied ($(wc -l < "$MODS_PLAN" 2>/dev/null) entries)"
fi

# ── 9. Run ──────────────────────────────────────────────────
cd "$EMU" || fatal 1 "cd $EMU failed"

JS_DEV=$(ls /dev/input/js* 2>/dev/null | head -1)
[ -z "$JS_DEV" ] && JS_DEV="/dev/input/js0"
if [ "$SAFE_EXIT" = "1" ]; then
    for w in "$RTSYS/overlay_exit.sh" "$SCRIPT_DIR/overlay_exit.sh"; do
        if [ -x "$w" ]; then "$w" "$JS_DEV" >/dev/null 2>&1 & WATCHER_PID=$!; log "exit watcher $w pid=$WATCHER_PID"; break; fi
    done
fi

"$DOLPHIN" -e "$ROM" -u "$EMU" >> "$DOLPHIN_LOG" 2>&1 &
DOLPHIN_PID=$!
log "dolphin pid=$DOLPHIN_PID  ( ./dolphin -e <rom> -u $EMU )"

# gptokeyb2 attaches to the "dolphin" process
if [ "${HOTKEYS:-}" != "Disabled" ]; then
    GPTK_BIN=""
    for b in "$GAME_DIR/lib/gptokeyb2" "$GAME_DIR/../lib/gptokeyb2" "/lib/gptokeyb2"; do
        [ -x "$b" ] && { GPTK_BIN="$b"; break; }
    done
    [ "$(uname -m 2>/dev/null)" = "armv7l" ] && [ -x "${GPTK_BIN}.armhf" ] && GPTK_BIN="${GPTK_BIN}.armhf"
    GPTK_CFG=""
    for c in "$WORKSHOP/hotkeys/${HOTKEYS:-Default}/ext-dolphin.gptk" "$WORKSHOP/hotkeys/Default/ext-dolphin.gptk" "$BASE_DIR/ext-dolphin.gptk"; do
        [ -f "$c" ] && { GPTK_CFG="$c"; break; }
    done
    if [ -n "$GPTK_BIN" ] && [ -n "$GPTK_CFG" ]; then
        killall -q gptokeyb2 gptokeyb2.armhf 2>/dev/null || true
        sleep 0.5
        "$GPTK_BIN" -c "$GPTK_CFG" -1 dolphin > "$LOG_DIR/gptokeyb2_$TS.log" 2>&1 &
        GPTK_PID=$!
        log "gptokeyb2 pid=$GPTK_PID cfg=$GPTK_CFG"
    else
        log "WARN: gptokeyb2 not started (bin='$GPTK_BIN' cfg='$GPTK_CFG')"
    fi
fi

wait "$DOLPHIN_PID"
EXIT_CODE=$?
log "dolphin exited: $EXIT_CODE"

# ── 10. Back to the frontend ────────────────────────────────
mods_cleanup_links
stop_helpers
if [ "$LOOP_MODE" != "1" ]; then
    type CONTENT_UNSET >/dev/null 2>&1 && CONTENT_UNSET
fi
restart_frontend "$EXIT_CODE"
exit "$EXIT_CODE"