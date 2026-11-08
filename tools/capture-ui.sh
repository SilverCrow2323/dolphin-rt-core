#!/usr/bin/env bash
# Capture a registered Dolphin Rt:UI screen using the existing core/devshot.lua hook.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI"
LOVE_BIN="${LOVE_BIN:-love}"
SCREEN="" OUTPUT="" DELAY="1.5" PADS="" SCREENS="" OUT_DIR=""
usage() {
  cat <<'EOF'
Usage:
  tools/capture-ui.sh SCREEN [OUTPUT.png]
  tools/capture-ui.sh --screen NAME [--output FILE.png] [--delay SECONDS] [--pads "R1,A"]
  tools/capture-ui.sh --screens "boot,library,settings" [--out-dir DIR]

Environment:
  LOVE_BIN       LÖVE executable (default: love)
  DISPLAY        Existing X11 display; if unset, xvfb-run is used when available
EOF
}
while (($#)); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
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
command -v "$LOVE_BIN" >/dev/null 2>&1 || { echo "LÖVE executable not found: $LOVE_BIN (set LOVE_BIN)" >&2; exit 1; }
[[ "$DELAY" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "Delay must be a non-negative number" >&2; exit 2; }
if [[ -n "$SCREENS" ]]; then
  [[ -z "$SCREEN" && -z "$OUTPUT" ]] || { echo "Use either --screens or a single screen" >&2; exit 2; }
  OUT_DIR="${OUT_DIR:-$ROOT/artifacts/screenshots}"
  mkdir -p "$OUT_DIR"
  IFS=',' read -r -a names <<< "$SCREENS"
  for name in "${names[@]}"; do
    name="$(printf '%s' "$name" | xargs)"
    [[ -n "$name" ]] || continue
    safe="${name//[^a-zA-Z0-9_-]/_}"
    "$0" --screen "$name" --output "$OUT_DIR/$safe.png" --delay "$DELAY" --pads "$PADS"
  done
  exit 0
fi
[[ -n "$SCREEN" ]] || { usage >&2; exit 2; }
if [[ -z "$OUTPUT" ]]; then
  OUTPUT="$ROOT/artifacts/screenshots/$SCREEN.png"
fi
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
[[ -s "$OUTPUT" ]] || { echo "LÖVE exited without producing a PNG: $OUTPUT" >&2; exit 1; }
printf 'Captured %s (%s bytes)\n' "$OUTPUT" "$(wc -c < "$OUTPUT" | tr -d ' ')"
