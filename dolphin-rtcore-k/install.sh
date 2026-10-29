#!/bin/bash
# Dolphin Rt:Core K - installer
# Run it from wherever the folder lives (emulators, tools, ...): it uses its own location, nothing is hard-coded.
# If the release files are missing (or with --update) it downloads them from the repo set in config/repo.conf.
shopt -u patsub_replacement 2>/dev/null

ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
[ -f "$ROOT/config/repo.conf" ] && . "$ROOT/config/repo.conf"
REPO="${RTCORE_REPO:-${REPO:-}}"
REF="${RTCORE_REF:-${REF:-main}}"
SUBDIR="${RTCORE_SUBDIR-${SUBDIR-}}"
URL="${RTCORE_URL:-}"

usage() {
cat <<EOT
Usage: ./install.sh [options]
  --update         download the latest release files from the repo first (your saves and settings are kept)
  --offline        never download anything
  --repo OWNER/NAME  --ref BRANCH_OR_TAG  --subdir DIR  --url TARBALL_URL   (override config/repo.conf)
  --userdata DIR   Batocera/Knulli data folder (default: auto-detected, usually /userdata)
  --roms DIR       ROMs folder           (default: <userdata>/roms)
  --es-dir DIR     EmulationStation config folder (default: <userdata>/system/configs/emulationstation)
  --themes DIR     themes folder         (default: <userdata>/themes)
  --no-es          do not write the EmulationStation files
  --no-theme       do not install the logos into the theme
  --no-restart     do not restart EmulationStation
  --dry-run        show what would be done, write nothing
  -h, --help       this help
EOT
}

USERDATA_OPT=""; ROMS_OPT=""; ES_OPT=""; THEMES_OPT=""
DO_ES=1; DO_THEME=1; DO_RESTART=1; DRY=0; UPDATE=0; OFFLINE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --update)     UPDATE=1; shift;;
    --offline)    OFFLINE=1; shift;;
    --repo)       REPO="$2"; shift 2;;
    --ref)        REF="$2"; shift 2;;
    --subdir)     SUBDIR="$2"; shift 2;;
    --url)        URL="$2"; shift 2;;
    --userdata)   USERDATA_OPT="$2"; shift 2;;
    --roms)       ROMS_OPT="$2"; shift 2;;
    --es-dir)     ES_OPT="$2"; shift 2;;
    --themes)     THEMES_OPT="$2"; shift 2;;
    --no-es)      DO_ES=0; shift;;
    --no-theme)   DO_THEME=0; shift;;
    --no-restart) DO_RESTART=0; shift;;
    --dry-run)    DRY=1; shift;;
    -h|--help)    usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
done

say()  { echo "[rtcore-k] $*"; }
die()  { echo "[rtcore-k] ERROR: $*" >&2; exit 1; }
run()  { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
xml_escape() { local s="$1"; s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"; printf '%s' "$s"; }

find_userdata() {
  if [ -n "$USERDATA_OPT" ]; then echo "$USERDATA_OPT"; return; fi
  if [ -n "${USERDATA:-}" ] && [ -d "$USERDATA" ]; then echo "$USERDATA"; return; fi
  local d="$ROOT"
  while [ "$d" != "/" ]; do
    [ -f "$d/system/batocera.conf" ] && { echo "$d"; return; }
    d="$(dirname "$d")"
  done
  [ -d /userdata ] && echo /userdata
}

download() {  # url out
  if   command -v curl >/dev/null 2>&1; then curl -fL $([ -t 2 ] && echo -# || echo -sS) --retry 3 --connect-timeout 20 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then wget -q -O "$2" "$1"
  else die "neither curl nor wget is available"; fi
}

fetch_release() {  # $1 = first | update
  local mode="$1" tmp url top src newv
  command -v tar >/dev/null 2>&1 || die "tar is required"
  [ -n "$URL" ] || [ -n "$REPO" ] || die "no repo configured: edit config/repo.conf or pass --repo OWNER/NAME"
  url="${URL:-https://codeload.github.com/$REPO/tar.gz/$REF}"
  if [ "$DRY" = 1 ]; then echo "[dry-run] download $url (subdir: '${SUBDIR:-<repo root>}') and copy into $ROOT ($mode)"; return; fi
  [ -d "$ROOT/.git" ] && [ "$mode" = update ] && say "note: this folder is a git checkout, 'git pull' is the cleaner way to update"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/rtcore.XXXXXX")" || die "cannot create a temporary folder"
  say "Downloading $url"
  download "$url" "$tmp/src.tar.gz" || { rm -rf "$tmp"; die "download failed. Check the network and the repo/ref/subdir in config/repo.conf"; }
  mkdir -p "$tmp/x"
  tar -xzof "$tmp/src.tar.gz" -C "$tmp/x" || { rm -rf "$tmp"; die "the download is not a valid archive"; }
  top="$(ls -1 "$tmp/x" | head -n1)"
  src="$tmp/x/$top"; [ -n "$SUBDIR" ] && src="$src/$SUBDIR"
  [ -f "$src/core/dolphin" ] || { rm -rf "$tmp"; die "no release found in the download (expected '${SUBDIR:+$SUBDIR/}core/dolphin')"; }
  newv="$(cat "$src/VERSION" 2>/dev/null)"
  if [ "$mode" = first ]; then
    (cd "$src" && tar -cf - .) | (cd "$ROOT" && tar -xof -)
  else
    # update: never touch saves, memory cards, the Wii NAND, states, logs or your settings
    (cd "$src" && tar -cf - \
        --exclude=./core/Gamecube --exclude=./core/Wii --exclude=./core/GC --exclude=./core/StateSaves \
        --exclude=./core/Cache --exclude=./core/Logs --exclude=./core/Dump --exclude=./core/ScreenShots \
        --exclude=./core/Config/Dolphin.ini --exclude=./core/Config/GFX.ini --exclude=./core/Config/GCPadNew.ini \
        --exclude=./core/Config/WiimoteNew.ini --exclude=./core/Config/Logger.ini \
        --exclude=./logs --exclude=./config/rtcore.conf --exclude=./config/repo.conf .) | (cd "$ROOT" && tar -xof -)
  fi
  rm -rf "$tmp"
  say "Release files ready (version ${newv:-unknown})"
}

UD="$(find_userdata)"
ROMS="${ROMS_OPT:-${UD:+$UD/roms}}"
ES_DIR="${ES_OPT:-${UD:+$UD/system/configs/emulationstation}}"
THEMES="${THEMES_OPT:-${UD:+$UD/themes}}"

say "Dolphin Rt:Core K $(cat "$ROOT/VERSION" 2>/dev/null)"
if [ "$UPDATE" = 1 ]; then
  [ "$OFFLINE" = 1 ] && die "--update and --offline cannot be combined"
  fetch_release update
elif [ ! -f "$ROOT/core/dolphin" ]; then
  [ "$OFFLINE" = 1 ] && die "core/dolphin is missing and --offline was given"
  say "core/dolphin is missing: fetching the release files from the repo"
  fetch_release first
fi
[ -f "$ROOT/core/dolphin" ] || [ "$DRY" = 1 ] || die "core/dolphin not found"

if [ "$DO_ES" = 1 ] && { [ -z "$ROMS" ] || [ -z "$ES_DIR" ]; }; then
  die "userdata folder not found. Pass --userdata DIR (or --roms and --es-dir)."
fi
say "release : $ROOT"
say "userdata: ${UD:-?}   roms: ${ROMS:-?}   es: ${ES_DIR:-?}"

run chmod +x "$ROOT"/bin/*.sh "$ROOT"/theme/*.sh "$ROOT"/install.sh "$ROOT"/uninstall.sh "$ROOT"/rtcore.sh "$ROOT/core/dolphin" 2>/dev/null
run mkdir -p "$ROOT/logs"

if [ "$DO_ES" = 1 ]; then
  run mkdir -p "$ROMS/wii" "$ROMS/gamecube" "$ES_DIR"

  CORES_SYS=""; CORES_FEAT=""; first=1
  while IFS= read -r c; do
    c="${c%%#*}"; c="$(echo "$c" | tr -d '[:space:]')"; [ -z "$c" ] && continue
    if [ $first = 1 ]; then CORES_SYS+="          <core default=\"true\">$c</core>"$'\n'; first=0
    else CORES_SYS+="          <core>$c</core>"$'\n'; fi
    CORES_FEAT+="      <core name=\"$c\" features=\"\">"$'\n'
    for v in rtc_pad rtc_orient rtc_gamesettings rtc_exit rtc_textures rtc_cheats rtc_fps; do
      CORES_FEAT+="        <sharedFeature value=\"$v\" />"$'\n'
    done
    CORES_FEAT+="      </core>"$'\n'
  done < "$ROOT/config/cores.list"

  render() {  # template -> output
    local t; t="$(cat "$1")"
    t="${t//@ROOT@/$(xml_escape "$ROOT")}"
    t="${t//@ROMS@/$(xml_escape "$ROMS")}"
    t="${t//@CORES_SYSTEMS@/${CORES_SYS%$'\n'}}"
    t="${t//@CORES_FEATURES@/${CORES_FEAT%$'\n'}}"
    if [ "$DRY" = 1 ]; then echo "[dry-run] would write $2"; return; fi
    [ -f "$2" ] && cp -f "$2" "$2.bak"
    printf '%s\n' "$t" > "$2"
  }
  render "$ROOT/es/es_systems_rtcore.cfg.in"  "$ES_DIR/es_systems_rtcore.cfg"
  render "$ROOT/es/es_features_rtcore.cfg.in" "$ES_DIR/es_features_rtcore.cfg"
  say "EmulationStation: systems 'wii' and 'gamecube' defined, put ROMs in $ROMS/{wii,gamecube}"
fi

if [ "$DO_THEME" = 1 ] && [ -n "$THEMES" ] && [ -n "$ES_DIR" ]; then
  if [ "$DRY" = 1 ]; then echo "[dry-run] bash theme/install-theme.sh --themes '$THEMES' --es-dir '$ES_DIR'"
  else bash "$ROOT/theme/install-theme.sh" --themes "$THEMES" --es-dir "$ES_DIR"; fi
fi

if [ "$DRY" != 1 ]; then
  { echo "root=$ROOT"; echo "es_dir=$ES_DIR"; echo "roms=$ROMS"; echo "version=$(cat "$ROOT/VERSION" 2>/dev/null)"; echo "date=$(date '+%F %T')"; } > "$ROOT/.installed"
fi

if [ "$DO_ES" = 1 ] && [ "$DO_RESTART" = 1 ] && [ "$DRY" != 1 ]; then
  if [ -x /etc/init.d/S31emulationstation ]; then
    say "Restarting EmulationStation..."
    /etc/init.d/S31emulationstation restart >/dev/null 2>&1 &
  else
    say "Restart EmulationStation manually."
  fi
fi
say "Done. Next: put ROMs in the wii / gamecube folders, then Game Settings > Update Game Lists."
