#!/usr/bin/env bash
# Capture registered Dolphin Rt:UI screens through core/devshot.lua.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI"
LOVE_BIN="${LOVE_BIN:-love}"
SCREEN="" OUTPUT="" DELAY="1.5" PADS="" SCREENS="" OUT_DIR="" ALL=0 LIST=0


usage() {
  cat <<'EOF'
Usage:
  bash tools/capture-ui.sh SCREEN [OUTPUT.png]
  bash tools/capture-ui.sh --screen NAME [--output FILE.png] [--delay SECONDS] [--pads "R1,A"]
  bash tools/capture-ui.sh --screens "boot,library,settings,triage" [--out-dir DIR]
  bash tools/capture-ui.sh --all [--out-dir DIR]
  bash tools/capture-ui.sh --list

Options:
  --all             Capture every screen registered by the frontend.
  --list            Print registered screen IDs without launching LÖVE.
  --screens LIST    Capture a comma-separated list of screens.
  --pads SEQUENCE   Inject logical gamepad presses before capture.
  --delay SECONDS   Seconds before capture (default: 1.5).
  --out-dir DIR     Batch output directory (default: artifacts/screenshots).

Environment:
  LOVE_BIN          LÖVE executable (default: love).
  DISPLAY           Existing X11 display; otherwise xvfb-run is used.
EOF
}
while (($#)); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --all) ALL=1; shift ;;
    --list) LIST=1; shift ;;
    --screen) SCREEN="${2:?missing screen name}"; shift 2 ;;
    --output) OUTPUT="${2:?missing output path}"; shift 2 ;;
    --delay) DELAY="${2:?missing delay}"; shift 2 ;;
    --pads) PADS="${2-}"; shift 2 ;;
    --screens) SCREENS="${2:?missing screen list}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:?missing output directory}"; shift 2 ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      if [[ -z "$SCREEN" ]]; then SCREEN="$1"
      elif [[ -z "$OUTPUT" ]]; then OUTPUT="$1"
      else echo "Unexpected argument: $1" >&2; exit 2; fi
      shift ;;
  esac
done

[[ -d "$APP" ]] || { echo "Frontend directory not found: $APP" >&2; exit 1; }

registered_screens() {
  local registry="$APP/ui/init.lua"
  [[ -f "$registry" ]] || { echo "Screen registry not found: $registry" >&2; return 1; }
  grep -oE '[{][[:space:]]*"[^"]+"[[:space:]]*,[[:space:]]*"ui[.]screens[.][^"]+"[[:space:]]*[}]' "$registry" |
    sed -E 's/^[{][[:space:]]*"([^"]+)".*$/\1/'
}

if (( LIST )); then
  (( ALL == 0 )) && [[ -z "$SCREEN$SCREENS$OUTPUT" ]] || { echo "--list cannot be combined with capture options." >&2; exit 2; }
  registered_screens
  exit $?
fi

is_registered_screen() {
  registered_screens | grep -Fxq -- "$1"
}

# Reject unknown IDs before starting LÖVE. Otherwise a typo can produce a
# perfectly valid PNG of an empty/error screen and look like a successful run.
if [[ -n "$SCREEN" ]] && ! is_registered_screen "$SCREEN"; then
  echo "Unknown screen: $SCREEN" >&2
  echo "Registered screens:" >&2
  registered_screens >&2
  exit 2
fi
if [[ -n "$SCREENS" ]]; then
  IFS=',' read -r -a requested <<< "$SCREENS"
  for name in "${requested[@]}"; do
    name="$(printf '%s' "$name" | xargs)"
    [[ -n "$name" ]] || continue
    if ! is_registered_screen "$name"; then
      echo "Unknown screen in batch: $name" >&2
      exit 2
    fi
  done
fi

command -v "$LOVE_BIN" >/dev/null 2>&1 || {
  echo "LÖVE executable not found: $LOVE_BIN (set LOVE_BIN)" >&2; exit 1;
}
[[ "$DELAY" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
  echo "Delay must be a non-negative number" >&2; exit 2;
}

if (( ALL )) && [[ -n "$SCREENS" ]]; then
  echo "Use either --all or --screens, not both." >&2
  exit 2
fi
if (( ALL )) || [[ -n "$SCREENS" ]]; then
  [[ -z "$SCREEN" && -z "$OUTPUT" ]] || {
    echo "Batch mode cannot be combined with --screen or a positional screen" >&2
    exit 2
  }
  if (( ALL )); then
    SCREENS="$(registered_screens | paste -sd, -)"
    [[ -n "$SCREENS" ]] || { echo "No screens found in ui/init.lua" >&2; exit 1; }
  fi

  OUT_DIR="${OUT_DIR:-$ROOT/artifacts/screenshots}"
  mkdir -p "$OUT_DIR"
  OUT_DIR="$(cd "$OUT_DIR" && pwd)"

  # One LÖVE process cycles through the requested screens and writes one PNG
  # per screen. This avoids restarting the emulator UI 22 times per resolution.
  IFS=',' read -r -a names <<< "$SCREENS"
  for name in "${names[@]}"; do
    name="$(printf '%s' "$name" | xargs)"
    [[ -n "$name" ]] || continue
    safe="${name//[^a-zA-Z0-9_-]/_}"
    rm -f -- "$OUT_DIR/$safe.png"
  done

  export DOLPHINUI_SHOT_BATCH="$SCREENS"
  export DOLPHINUI_SHOT_DIR="$OUT_DIR"
  export DOLPHINUI_SHOT_DELAY="$DELAY"
  export DOLPHINUI_SHOT_PADS="$PADS"
  export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-dummy}"
  export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"

  runner=("$LOVE_BIN" .)
  if [[ -z "${DISPLAY:-}" ]] && command -v xvfb-run >/dev/null 2>&1; then
    runner=(xvfb-run -a "${runner[@]}")
  elif [[ -z "${DISPLAY:-}" ]]; then
    echo "No DISPLAY and xvfb-run is unavailable. Install Xvfb or set DISPLAY." >&2
    exit 1
  fi

  (
    cd "$APP"
    "${runner[@]}"
  )

  completed=0
  failed=0
  for name in "${names[@]}"; do
    name="$(printf '%s' "$name" | xargs)"
    [[ -n "$name" ]] || continue
    safe="${name//[^a-zA-Z0-9_-]/_}"
    if [[ -s "$OUT_DIR/$safe.png" ]]; then
      completed=$((completed + 1))
    else
      echo "FAILED: $name (PNG missing or empty)" >&2
      failed=$((failed + 1))
    fi
  done
  echo "Batch capture: $completed succeeded, $failed failed."
  (( failed == 0 && completed > 0 ))
  exit $?
fi
[[ -n "$SCREEN" ]] || { usage >&2; exit 2; }
OUTPUT="${OUTPUT:-$ROOT/artifacts/screenshots/$SCREEN.png}"
mkdir -p "$(dirname -- "$OUTPUT")"
OUTPUT="$(cd -- "$(dirname -- "$OUTPUT")" && pwd)/$(basename -- "$OUTPUT")"
[[ "$OUTPUT" == *.png ]] || { echo "Output must end in .png" >&2; exit 2; }
rm -f -- "$OUTPUT"

export DOLPHINUI_SHOT="$OUTPUT:$DELAY"
export DOLPHINUI_SHOT_PADS="$PADS"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-dummy}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"

runner=("$LOVE_BIN" . "--screen=$SCREEN")
if [[ -z "${DISPLAY:-}" ]] && command -v xvfb-run >/dev/null 2>&1; then
  runner=(xvfb-run -a "${runner[@]}")
elif [[ -z "${DISPLAY:-}" ]]; then
  echo "No DISPLAY and xvfb-run is unavailable. Install Xvfb or set DISPLAY." >&2
  exit 1
fi

(
  cd "$APP"
  "${runner[@]}"
)
[[ -s "$OUTPUT" ]] || {
  echo "LÖVE exited without producing a PNG: $OUTPUT" >&2
  exit 1
}
printf 'Captured %s (%s bytes)\n' "$OUTPUT" "$(wc -c < "$OUTPUT" | tr -d ' ')"
