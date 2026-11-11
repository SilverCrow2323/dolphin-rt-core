#!/usr/bin/env bash
# Builds dist/Dolphin_RtCore_v<version>_Andromeda.muxupd for muOS 2606.0 "Andromeda".
# Andromeda requires an integrity manifest (manifest.sha256) in every .muxupd; this script generates it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
OUT="${1:-$ROOT/dist}"; mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
ARCHIVE="$OUT/Dolphin_RtCore_v${VERSION//./_}_Andromeda.muxupd"
# Optional build outputs:
#   DOLPHIN_BIN=/path/to/aarch64/dolphin
#   DOLPHIN_SYS_DIR=/path/to/build/Sys
# Keep binary and Sys from the same Dolphin build revision.
DOLPHIN_BIN="${DOLPHIN_BIN:-}"
DOLPHIN_SYS_DIR="${DOLPHIN_SYS_DIR:-}"
DOLPHIN_LIB_DIR="${DOLPHIN_LIB_DIR:-}"
DOLPHIN_UI_ONLY="${DOLPHIN_UI_ONLY:-0}"
if [ -z "$DOLPHIN_LIB_DIR" ] && [ -n "$DOLPHIN_BIN" ] && [ -d "$(dirname "$DOLPHIN_BIN")/lib" ]; then
  DOLPHIN_LIB_DIR="$(dirname "$DOLPHIN_BIN")/lib"
fi
DEFAULT_SYS_SOURCE="$(cd "$ROOT/emu/dolphin/Sys" && pwd -P)"
SYS_SOURCE="$DEFAULT_SYS_SOURCE"
if [ -n "$DOLPHIN_SYS_DIR" ]; then
  [ -d "$DOLPHIN_SYS_DIR" ] || { echo "ERROR: DOLPHIN_SYS_DIR is not a directory: $DOLPHIN_SYS_DIR" >&2; exit 1; }
  SYS_SOURCE="$(cd "$DOLPHIN_SYS_DIR" && pwd -P)"
fi
if [ -z "$DOLPHIN_BIN" ]; then
  [ "$DOLPHIN_UI_ONLY" = "1" ] || {
    echo "ERROR: refusing to build an installable muOS update without Dolphin. Set DOLPHIN_BIN to a validated AArch64 executable, or explicitly set DOLPHIN_UI_ONLY=1 for CI-only UI validation." >&2
    exit 2
  }
  ARCHIVE="${ARCHIVE%.muxupd}_ui-only.muxupd"
else
  [ -s "$DOLPHIN_BIN" ] || { echo "ERROR: DOLPHIN_BIN is missing or empty: $DOLPHIN_BIN" >&2; exit 1; }
  hdr="$(head -c 20 "$DOLPHIN_BIN" | od -An -tx1 | tr -d ' \\n')"
  case "$hdr" in 7f454c46020101*b700) ;; *) echo "ERROR: DOLPHIN_BIN is not an aarch64 ELF executable" >&2; exit 1;; esac
  if readelf -d "$DOLPHIN_BIN" 2>/dev/null | grep -q "libhidapi-hidraw.so.0"; then
    [ -s "$DOLPHIN_LIB_DIR/libhidapi-hidraw.so.0" ] || {
      echo "ERROR: Dolphin requires libhidapi-hidraw.so.0 but it is not present in DOLPHIN_LIB_DIR=$DOLPHIN_LIB_DIR" >&2
      exit 1
    }
  fi
fi
S="$(mktemp -d)"; trap 'rm -rf "$S"' EXIT

# GameCube IPL text rendering depends on these Dolphin system resources.
# When a freshly built Sys tree is supplied, validate and package that exact tree.
for font in font_western.bin font_japanese.bin; do
  [ -s "$SYS_SOURCE/GC/$font" ] || { echo "ERROR: missing GameCube system font: $SYS_SOURCE/GC/$font" >&2; exit 1; }
done
for resource in dsp_rom.bin dsp_coef.bin; do
  [ -s "$SYS_SOURCE/GC/$resource" ] || { echo "ERROR: missing GameCube DSP resource: $SYS_SOURCE/GC/$resource" >&2; exit 1; }
done
[ -s "$SYS_SOURCE/Resources/OSD_Font.ttf" ] || { echo "ERROR: missing Dolphin OSD font: $SYS_SOURCE/Resources/OSD_Font.ttf" >&2; exit 1; }

APP="run/muos/storage/application/Dolphin RtUI"; EMU="opt/muos/share/emulator/dolphin"
mkdir -p "$S/$APP" "$S/$EMU"
cp -a "$ROOT/emu/dolphin/." "$S/$EMU/"
if [ "$SYS_SOURCE" != "$DEFAULT_SYS_SOURCE" ]; then
  rm -rf "$S/$EMU/Sys"
  mkdir -p "$S/$EMU/Sys"
  cp -a "$SYS_SOURCE/." "$S/$EMU/Sys/"
fi
cp -a "$ROOT/app/Dolphin RtUI/." "$S/$APP/"
cp -a "$ROOT/overlay/." "$S/"                         # muOS-only files (launcher, tasks, manifest tool, update hook)
[ -n "$DOLPHIN_BIN" ] && install -m755 "$DOLPHIN_BIN" "$S/$EMU/dolphin"
if [ -n "$DOLPHIN_LIB_DIR" ]; then
  [ -d "$DOLPHIN_LIB_DIR" ] || { echo "ERROR: DOLPHIN_LIB_DIR is not a directory: $DOLPHIN_LIB_DIR" >&2; exit 1; }
  mkdir -p "$S/$EMU/lib"
  cp -a "$DOLPHIN_LIB_DIR/." "$S/$EMU/lib/"
fi
if [ -n "$DOLPHIN_BIN" ] && readelf -d "$DOLPHIN_BIN" 2>/dev/null | grep -q "libhidapi-hidraw.so.0"; then
  [ -s "$S/$EMU/lib/libhidapi-hidraw.so.0" ] || { echo "ERROR: missing bundled HIDAPI runtime; set DOLPHIN_LIB_DIR" >&2; exit 1; }
  readelf -h "$S/$EMU/lib/libhidapi-hidraw.so.0" | grep -q 'Machine:.*AArch64' || {
    echo "ERROR: bundled libhidapi-hidraw.so.0 is not an AArch64 ELF library" >&2; exit 1;
  }
fi
mkdir -p "$S/$APP/data/logs" "$S/$APP/data/stream/covers" "$S/$APP/data/stream/keys"

find "$S" -name '*.sh' -exec chmod 755 {} +
chmod 755 "$S/$APP"/lib/love "$S/$APP"/lib/moonlight "$S/$APP"/lib/gptokeyb2 2>/dev/null || true
find "$S" \( -name __pycache__ -o -name '*.rt.*' -o -name '*.tmp' -o -name '*.bak' \) -prune -exec rm -rf {} +

# Never ship personal / runtime data
if find "$S" -path '*/data/stream/*' -type f | grep -q .; then echo "ERROR: runtime stream data in the package" >&2; exit 1; fi

( cd "$S" && rm -f manifest.sha256 \
  && find . -type f | sed 's|^\./||' | LC_ALL=C sort > /tmp/.rt_files.$$ \
  && if grep -q -E '[][*?\\]|^/|\.\.' /tmp/.rt_files.$$; then echo "ERROR: unsafe file name" >&2; exit 1; fi \
  && xargs -d '\n' sha256sum < /tmp/.rt_files.$$ > manifest.sha256 && rm -f /tmp/.rt_files.$$ \
  && rm -f "$ARCHIVE" && zip -q -X -r -9 "$ARCHIVE" manifest.sha256 opt run )
echo "built $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1), $(wc -l < <(unzip -Z1 "$ARCHIVE" | grep -v '/$')) files)"
