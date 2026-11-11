#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGER="$ROOT/dolphin-rtcore-muos/tools/build-muxupd-qt6-experimental.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/lib" "$TMP/qtlib" "$TMP/plugins/platforms" "$TMP/sys/GC" "$TMP/sys/Resources"
python3 - "$TMP/bin/dolphin" "$TMP/bin/dolphin-gui" <<'PY'
from pathlib import Path
import sys
header = bytes.fromhex("7f454c460201010000000000000000000300b700")
Path(sys.argv[1]).write_bytes(header + b"NoGUI test fixture\n")
Path(sys.argv[2]).write_bytes(header + b"Qt6 test fixture\n")
PY
chmod 755 "$TMP/bin/dolphin" "$TMP/bin/dolphin-gui"
printf 'western font fixture\n' > "$TMP/sys/GC/font_western.bin"
printf 'Japanese font fixture\n' > "$TMP/sys/GC/font_japanese.bin"
printf 'DSP ROM fixture\n' > "$TMP/sys/GC/dsp_rom.bin"
printf 'DSP coefficient fixture\n' > "$TMP/sys/GC/dsp_coef.bin"
printf 'OSD font fixture\n' > "$TMP/sys/Resources/OSD_Font.ttf"
printf 'Qt6Core fixture\n' > "$TMP/qtlib/libQt6Core.so.6"
printf 'EGLFS plugin fixture\n' > "$TMP/plugins/platforms/libqeglfs.so"
printf 'HIDAPI fixture\n' > "$TMP/lib/libhidapi-hidraw.so.0"
OUT="$TMP/dist"
DOLPHIN_NO_GUI_BIN="$TMP/bin/dolphin" \
DOLPHIN_QT_BIN="$TMP/bin/dolphin-gui" \
DOLPHIN_QT_LIB_DIR="$TMP/qtlib" \
DOLPHIN_QT_PLUGIN_DIR="$TMP/plugins" \
DOLPHIN_LIB_DIR="$TMP/lib" \
DOLPHIN_SYS_DIR="$TMP/sys" \
  bash "$PACKAGER" "$OUT"
VERSION="$(tr -d '[:space:]' < "$ROOT/dolphin-rtcore-muos/VERSION")"
ARCHIVE="$OUT/Dolphin_RtCore_v${VERSION//./_}_Andromeda_qt6-experimental.muxupd"
[ -s "$ARCHIVE" ]
EMU="opt/muos/share/emulator/dolphin"
for asset in \
  "$EMU/dolphin" \
  "$EMU/dolphin-qt6" \
  "$EMU/Sys/GC/font_western.bin" \
  "$EMU/Sys/GC/font_japanese.bin" \
  "$EMU/Sys/GC/dsp_rom.bin" \
  "$EMU/Sys/GC/dsp_coef.bin" \
  "$EMU/Sys/Resources/OSD_Font.ttf" \
  "$EMU/qt6/lib/libQt6Core.so.6" \
  "$EMU/qt6/plugins/platforms/libqeglfs.so" \
  "$EMU/lib/libhidapi-hidraw.so.0" \
  "$EMU/launch-qt6-experimental.sh"; do
  unzip -Z1 "$ARCHIVE" | grep -Fxq "$asset"
done
unzip -p "$ARCHIVE" "$EMU/dolphin" | cmp - "$TMP/bin/dolphin"
unzip -p "$ARCHIVE" "$EMU/dolphin-qt6" | cmp - "$TMP/bin/dolphin-gui"
unzip -p "$ARCHIVE" "$EMU/Sys/GC/font_western.bin" | cmp - "$TMP/sys/GC/font_western.bin"
unzip -p "$ARCHIVE" "$EMU/launch-qt6-experimental.sh" | grep -Fq 'QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-eglfs}"'
unzip -p "$ARCHIVE" manifest.sha256 | grep -Fq "$EMU/dolphin-qt6"
echo "[OK] experimental Qt6 package contains matching NoGUI/Qt binaries, Sys tree, Qt runtime, EGLFS plugin and HIDAPI"
echo "[OK] stable NoGUI executable path is not overwritten"
