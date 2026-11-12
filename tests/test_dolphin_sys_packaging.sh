#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGER="$ROOT/dolphin-rtcore-muos/tools/build-muxupd.sh"
BASE_SYS="$ROOT/dolphin-rtcore-muos/emu/dolphin/Sys"
TMP="$(mktemp -d)"
SYNTHETIC_BACKUP="$ROOT/app/Dolphin RtUI/workshop/base/packaging-test.ini.bak.20261112"
cleanup() {
  rm -f "$SYNTHETIC_BACKUP"
  rm -rf "$TMP"
}
trap cleanup EXIT

# A timestamped backup used to leak into .muxupd archives because the
# packager only excluded the exact suffix '*.bak'.
printf 'must never ship\n' > "$SYNTHETIC_BACKUP"

SYS="$TMP/Sys"
mkdir -p "$SYS"
cp -a "$BASE_SYS/." "$SYS/"
MARKER_REL="Resources/RtCore-packaging-probe.txt"
printf 'Sys tree from a specific Dolphin build revision\n' > "$SYS/$MARKER_REL"

# The packager validates the aarch64 ELF header; this minimal fixture is not
# an executable emulator and is used only to exercise archive assembly.
python3 - "$TMP/dolphin" <<'PY'
from pathlib import Path
import sys

header = bytes.fromhex("7f454c460201010000000000000000000300b700")
Path(sys.argv[1]).write_bytes(header + b"RtCore packaging test fixture\n")
PY
chmod 755 "$TMP/dolphin"

LIBS="$TMP/lib"
mkdir -p "$LIBS"
printf "HIDAPI runtime fixture\n" > "$LIBS/libhidapi-hidraw.so.0"

OUT="$TMP/dist"
DOLPHIN_BIN="$TMP/dolphin" DOLPHIN_SYS_DIR="$SYS" DOLPHIN_LIB_DIR="$LIBS" \
  bash "$PACKAGER" "$OUT"

VERSION="$(tr -d '[:space:]' < "$ROOT/dolphin-rtcore-muos/VERSION")"
ARCHIVE="$OUT/Dolphin_RtCore_v${VERSION//./_}_Andromeda_with-dolphin.muxupd"
[ -s "$ARCHIVE" ]
if unzip -Z1 "$ARCHIVE" | grep -Eq '\\.bak(\\.|$)|~$|\\.swp"opt/muos/share/emulator/dolphin"
for asset in \
  "$EMU_PATH/dolphin" \
  "$EMU_PATH/lib/libhidapi-hidraw.so.0" \
  "$EMU_PATH/Sys/GC/font_western.bin" \
  "$EMU_PATH/Sys/GC/font_japanese.bin" \
  "$EMU_PATH/Sys/GC/dsp_rom.bin" \
  "$EMU_PATH/Sys/GC/dsp_coef.bin" \
  "$EMU_PATH/Sys/Resources/OSD_Font.ttf" \
  "$EMU_PATH/Sys/$MARKER_REL"; do
  unzip -Z1 "$ARCHIVE" | grep -Fxq "$asset"
done

unzip -p "$ARCHIVE" "$EMU_PATH/dolphin" | cmp -s "$TMP/dolphin" -
unzip -p "$ARCHIVE" "$EMU_PATH/lib/libhidapi-hidraw.so.0" | cmp -s "$LIBS/libhidapi-hidraw.so.0" -
unzip -p "$ARCHIVE" "$EMU_PATH/Sys/$MARKER_REL" | cmp -s "$SYS/$MARKER_REL" -

MARKER_SHA="$(sha256sum "$SYS/$MARKER_REL" | awk '{print $1}')"
unzip -p "$ARCHIVE" manifest.sha256 | grep -Fqx "$MARKER_SHA  $EMU_PATH/Sys/$MARKER_REL"

echo "[OK] binary, private HIDAPI runtime and supplied Sys tree are included at the muOS runtime paths"
echo "[OK] GameCube fonts, DSP assets, and the Sys-tree marker are present"
echo "[OK] manifest.sha256 covers the supplied Sys-tree marker"

# Missing assets must fail before an update archive is produced.
BROKEN_SYS="$TMP/Sys-missing-font"
cp -a "$SYS" "$BROKEN_SYS"
rm -f "$BROKEN_SYS/GC/font_japanese.bin"
FAIL_OUT="$TMP/fail-dist"
if DOLPHIN_BIN="$TMP/dolphin" DOLPHIN_SYS_DIR="$BROKEN_SYS" \
  bash "$PACKAGER" "$FAIL_OUT" >"$TMP/missing-font.log" 2>&1; then
  echo "[FAIL] packager accepted a Sys tree without font_japanese.bin" >&2
  exit 1
fi
grep -Fq "missing GameCube system font" "$TMP/missing-font.log"
if find "$FAIL_OUT" -maxdepth 1 -type f -name '*.muxupd' -print -quit 2>/dev/null | grep -q .; then
  echo "[FAIL] failed resource validation left a .muxupd archive" >&2
  exit 1
fi
echo "[OK] missing GameCube font is rejected before archive creation"

# Missing DSP data is also fatal before an update archive is written.
DSP_SYS="$TMP/Sys-missing-dsp"
mkdir -p "$DSP_SYS/GC"
cp "$SYS/GC/font_western.bin" "$DSP_SYS/GC/"
cp "$SYS/GC/font_japanese.bin" "$DSP_SYS/GC/"
cp "$SYS/GC/dsp_rom.bin" "$DSP_SYS/GC/"
if DOLPHIN_BIN="$TMP/dolphin" DOLPHIN_SYS_DIR="$DSP_SYS" \
  bash "$PACKAGER" "$TMP/fail-dsp-dist" >"$TMP/missing-dsp.log" 2>&1; then
  echo "[FAIL] packager accepted a Sys tree without dsp_coef.bin" >&2
  exit 1
fi
grep -Fq "missing GameCube DSP resource" "$TMP/missing-dsp.log"
if find "$TMP/fail-dsp-dist" -maxdepth 1 -type f -name '*.muxupd' -print -quit 2>/dev/null | grep -q .; then
  echo "[FAIL] DSP validation failure left a .muxupd archive" >&2
  exit 1
fi
echo "[OK] missing GameCube DSP data is rejected before archive creation"
; then
  echo "[FAIL] backup/editor residue was included in the .muxupd" >&2
  exit 1
fi
echo "[OK] timestamped backups and editor residue are excluded"

EMU_PATH="opt/muos/share/emulator/dolphin"
for asset in \
  "$EMU_PATH/dolphin" \
  "$EMU_PATH/lib/libhidapi-hidraw.so.0" \
  "$EMU_PATH/Sys/GC/font_western.bin" \
  "$EMU_PATH/Sys/GC/font_japanese.bin" \
  "$EMU_PATH/Sys/GC/dsp_rom.bin" \
  "$EMU_PATH/Sys/GC/dsp_coef.bin" \
  "$EMU_PATH/Sys/Resources/OSD_Font.ttf" \
  "$EMU_PATH/Sys/$MARKER_REL"; do
  unzip -Z1 "$ARCHIVE" | grep -Fxq "$asset"
done

unzip -p "$ARCHIVE" "$EMU_PATH/dolphin" | cmp -s "$TMP/dolphin" -
unzip -p "$ARCHIVE" "$EMU_PATH/lib/libhidapi-hidraw.so.0" | cmp -s "$LIBS/libhidapi-hidraw.so.0" -
unzip -p "$ARCHIVE" "$EMU_PATH/Sys/$MARKER_REL" | cmp -s "$SYS/$MARKER_REL" -

MARKER_SHA="$(sha256sum "$SYS/$MARKER_REL" | awk '{print $1}')"
unzip -p "$ARCHIVE" manifest.sha256 | grep -Fqx "$MARKER_SHA  $EMU_PATH/Sys/$MARKER_REL"

echo "[OK] binary, private HIDAPI runtime and supplied Sys tree are included at the muOS runtime paths"
echo "[OK] GameCube fonts, DSP assets, and the Sys-tree marker are present"
echo "[OK] manifest.sha256 covers the supplied Sys-tree marker"

# Missing assets must fail before an update archive is produced.
BROKEN_SYS="$TMP/Sys-missing-font"
cp -a "$SYS" "$BROKEN_SYS"
rm -f "$BROKEN_SYS/GC/font_japanese.bin"
FAIL_OUT="$TMP/fail-dist"
if DOLPHIN_BIN="$TMP/dolphin" DOLPHIN_SYS_DIR="$BROKEN_SYS" \
  bash "$PACKAGER" "$FAIL_OUT" >"$TMP/missing-font.log" 2>&1; then
  echo "[FAIL] packager accepted a Sys tree without font_japanese.bin" >&2
  exit 1
fi
grep -Fq "missing GameCube system font" "$TMP/missing-font.log"
if find "$FAIL_OUT" -maxdepth 1 -type f -name '*.muxupd' -print -quit 2>/dev/null | grep -q .; then
  echo "[FAIL] failed resource validation left a .muxupd archive" >&2
  exit 1
fi
echo "[OK] missing GameCube font is rejected before archive creation"

# Missing DSP data is also fatal before an update archive is written.
DSP_SYS="$TMP/Sys-missing-dsp"
mkdir -p "$DSP_SYS/GC"
cp "$SYS/GC/font_western.bin" "$DSP_SYS/GC/"
cp "$SYS/GC/font_japanese.bin" "$DSP_SYS/GC/"
cp "$SYS/GC/dsp_rom.bin" "$DSP_SYS/GC/"
if DOLPHIN_BIN="$TMP/dolphin" DOLPHIN_SYS_DIR="$DSP_SYS" \
  bash "$PACKAGER" "$TMP/fail-dsp-dist" >"$TMP/missing-dsp.log" 2>&1; then
  echo "[FAIL] packager accepted a Sys tree without dsp_coef.bin" >&2
  exit 1
fi
grep -Fq "missing GameCube DSP resource" "$TMP/missing-dsp.log"
if find "$TMP/fail-dsp-dist" -maxdepth 1 -type f -name '*.muxupd' -print -quit 2>/dev/null | grep -q .; then
  echo "[FAIL] DSP validation failure left a .muxupd archive" >&2
  exit 1
fi
echo "[OK] missing GameCube DSP data is rejected before archive creation"
