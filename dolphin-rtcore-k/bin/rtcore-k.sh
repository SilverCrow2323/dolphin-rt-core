#!/bin/bash
# Dolphin Rt:Core K — launcher
# Uso / usage:  rtcore-k.sh <ROM> [profilo/profile]
# Nessun percorso assoluto: tutto è relativo alla cartella della release.
# No absolute paths: everything is relative to the release folder.

SELF="$(readlink -f "$0")"
BIN="$(dirname "$SELF")"
ROOT="$(dirname "$BIN")"
CORE="$ROOT/core"

[ -f "$ROOT/config/rtcore.conf" ] && . "$ROOT/config/rtcore.conf"
DEVICE="${RTCORE_DEVICE:-${DEVICE:-rg35xx-h}}"
[ -f "$ROOT/config/devices/$DEVICE.conf" ] && . "$ROOT/config/devices/$DEVICE.conf"

ROM="$1"
PROFILE="${2:-${DEFAULT_PROFILE:-default}}"
LOGDIR="$ROOT/logs"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/launch.log"
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 524288 ] && mv -f "$LOG" "$LOG.old"
[ -n "${RTCORE_DRYRUN:-}" ] && LOG=/dev/stdout

find_userdata() {
  if [ -n "${USERDATA:-}" ] && [ -d "$USERDATA" ]; then echo "$USERDATA"; return; fi
  local d="$ROOT"
  while [ "$d" != "/" ]; do
    [ -f "$d/system/batocera.conf" ] && { echo "$d"; return; }
    d="$(dirname "$d")"
  done
  [ -d /userdata ] && echo /userdata
}
UD="$(find_userdata)"
CONF="${UD:+$UD/system/batocera.conf}"

[ -n "$ROM" ] && [ -f "$ROM" ] || { echo "ROM non trovata / not found: $ROM" >> "$LOG"; exit 1; }
case "$ROM" in */[Gg]ame[Cc]ube/*|*/gc/*) SYS=gamecube;; *) SYS=wii;; esac

# opzione per gioco > per sistema > globale > default (le scrive ES in batocera.conf)
opt() {
  local v=""
  if [ -n "$CONF" ] && [ -f "$CONF" ]; then
    v=$(grep -m1 -F "${SYS}[\"${ROM}\"].$1=" "$CONF" 2>/dev/null | cut -d= -f2-)
    [ -z "$v" ] && v=$(grep -m1 "^${SYS}\.$1=" "$CONF" 2>/dev/null | cut -d= -f2-)
    [ -z "$v" ] && v=$(grep -m1 "^global\.$1=" "$CONF" 2>/dev/null | cut -d= -f2-)
  fi
  echo "${v:-$2}"
}
NUMSTICKS=$(opt rtc_pad "${NUMSTICKS:-2}")
case "$PROFILE" in *-sideways) ORIENT_DEF=sideways;; *) ORIENT_DEF=upright;; esac
ORIENT=$(opt rtc_orient "$ORIENT_DEF")
GSET=$(opt rtc_gamesettings on)
TEX=$(opt rtc_textures off)
CHEATS=$(opt rtc_cheats off)
FPS=$(opt rtc_fps off)
EXITC=$(opt rtc_exit select_start)
case "$EXITC" in
  mode_start) KA="${BTN_MENU:-8}";   KB="${BTN_START:-7}";;
  *)          KA="${BTN_START:-7}";  KB="${BTN_SELECT:-6}";;
esac

EXTRA=()
[ "$TEX" = on ]    && EXTRA+=(-C GFX.Settings.HiresTextures=True)
[ "$CHEATS" = on ] && EXTRA+=(-C Dolphin.Core.EnableCheats=True)
[ "$FPS" = on ]    && EXTRA+=(-C GFX.Settings.ShowFPS=True)

esc() { printf '%s' "$1" | sed -e 's/[\\#&]/\\&/g'; }

watcher() {
  exec 3< "${JS_DEV:-/dev/input/js0}" || exit 1
  local s=0 b=0 EV V T N i
  while true; do
    EV=$(dd bs=8 count=1 <&3 2>/dev/null | od -An -tu1)
    [ -z "$EV" ] && continue
    set -- $EV
    V=$5; T=$(( $7 & 127 )); N=$8
    [ "$T" = 1 ] || continue
    [ "$N" = "$KA" ] && s=$V
    [ "$N" = "$KB" ] && b=$V
    if [ "$s" = 1 ] && [ "$b" = 1 ]; then
      echo "combo uscita / exit combo ($EXITC)" >> "$LOG"
      killall -TERM dolphin 2>/dev/null
      for i in $(seq 1 "${EXIT_GRACE:-8}"); do pidof dolphin >/dev/null || break; sleep 1; done
      killall -KILL dolphin 2>/dev/null
      break
    fi
  done
}

restore() {
  [ -d "$CORE/GameSettings.off" ] && [ ! -d "$CORE/GameSettings" ] && mv "$CORE/GameSettings.off" "$CORE/GameSettings"
}
trap restore EXIT
restore
if [ "$GSET" = off ] && [ -d "$CORE/GameSettings" ] && [ -z "${RTCORE_DRYRUN:-}" ]; then
  mv "$CORE/GameSettings" "$CORE/GameSettings.off"
fi

{
echo "=== $(date '+%F %T') | $SYS | $PROFILE | pad=$NUMSTICKS $ORIENT | gs=$GSET tex=$TEX ch=$CHEATS fps=$FPS exit=$EXITC | $(basename "$ROM") ==="
cd "$CORE/Config" || exit 1
PROFILE_BASE="${PROFILE%-sideways}"; PROFILE_BASE="${PROFILE_BASE%-upright}"
for f in Dolphin.ini GFX.ini; do
  if   [ -f "$f.$PROFILE_BASE" ]; then cp -f "$f.$PROFILE_BASE" "$f"
  elif [ -f "$f.default" ];       then cp -f "$f.default" "$f"; fi
done
case "$PROFILE_BASE" in
  *rtverbose*) [ -f Logger.ini.verbose ] && cp -f Logger.ini.verbose Logger.ini;;
  *)           [ -f Logger.ini.default ] && cp -f Logger.ini.default Logger.ini;;
esac
[ -f "GCPadNew.ini.${NUMSTICKS}joy" ] && cp -f "GCPadNew.ini.${NUMSTICKS}joy" GCPadNew.ini
SUF=""; [ "$ORIENT" = sideways ] && SUF=".sideways"
if   [ -f "WiimoteNew.ini.${NUMSTICKS}joy$SUF" ]; then cp -f "WiimoteNew.ini.${NUMSTICKS}joy$SUF" WiimoteNew.ini
elif [ -f "WiimoteNew.ini.${NUMSTICKS}joy" ];      then cp -f "WiimoteNew.ini.${NUMSTICKS}joy" WiimoteNew.ini; fi

# nome del pad e percorsi: riscritti a ogni avvio (la release è spostabile)
for f in GCPadNew.ini WiimoteNew.ini Hotkeys.ini; do
  [ -f "$f" ] && sed -i "s#^Device = SDL/0/.*#Device = SDL/0/$(esc "${PAD_NAME:-Controller}")#" "$f"
done
E="$(esc "$CORE")"
sed -i -e "s#/run/muos/storage/save/dolphin/#$E/#g" -e "s#/run/muos/storage/bios/dolphin/#$E/bios/#g" Dolphin.ini

cd "$CORE" || exit 1
export HOME="${UD:+$UD/system}"; [ -d "$HOME" ] || export HOME="$ROOT"
export SDL_GAMECONTROLLERCONFIG="${SDL_GUID},${PAD_NAME},${SDL_MAP},platform:Linux,"

if [ -n "${RTCORE_DRYRUN:-}" ]; then
  echo "[dry-run] ROOT=$ROOT CORE=$CORE UD=$UD SYS=$SYS"
  echo "[dry-run] SDL_GAMECONTROLLERCONFIG=$SDL_GAMECONTROLLERCONFIG"
  echo "[dry-run] cmd: $CORE/dolphin -e $ROM -u $CORE ${EXTRA[*]}"
  exit 0
fi

watcher & WPID=$!
./dolphin -e "$ROM" -u "$CORE" "${EXTRA[@]}"
echo "exit=$?"
kill $WPID 2>/dev/null
} >> "$LOG" 2>&1
exit 0
