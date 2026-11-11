#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGER="$ROOT/dolphin-rtcore-muos/tools/build-muxupd-qt6-experimental.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/lib" "$TMP/qtlib" "$TMP/plugins/platforms"
python3 - "$TMP/bin/dolphin-gui" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(bytes.fromhex("7f454c460201010000000000000000000300b700") + b"Qt6 test fixture\n")
PY
chmod 755 "$TMP/bin/dolphin-gui"
printf 'Qt6Core fixture\n' > "$TMP/qtlib/libQt6Core.so.6"
printf 'EGLFS plugin fixture\n' > "$TMP/plugins/platforms/libqeglfs.so"
printf 'HIDAPI fixture\n' > "$TMP/lib/libhidapi-hidraw.so.0"
OUT="$TMP/dist"
DOLPHIN_QT_BIN="$TMP/bin/dolphin-gui" \
DOLPHIN_QT_LIB_DIR="$TMP/qtlib" \
DOLPHIN_QT_PLUGIN_DIR="$TMP/plugins" \
DOLPHIN_LIB_DIR="$TMP/lib" \
  bash "$PACKAGER" "$OUT"
VERSION="$(tr -d '[:space:]' < "$ROOT/dolphin-rtcore-muos/VERSION")"
ARCHIVE="$OUT/Dolphin_RtCore_v${VERSION//./_}_Andromeda_qt6-experimental.muxupd"
[ -s "$ARCHIVE" ]
EMU="opt/muos/share/emulator/dolphin"
for asset in \
  "$EMU/dolphin-qt6" \
  "$EMU/qt6/lib/libQt6Core.so.6" \
  "$EMU/qt6/plugins/platforms/libqeglfs.so" \
  "$EMU/lib/libhidapi-hidraw.so.0" \
  "$EMU/launch-qt6-experimental.sh"; do
  unzip -Z1 "$ARCHIVE" | grep -Fxq "$asset"
done
unzip -p "$ARCHIVE" "$EMU/launch-qt6-experimental.sh" | grep -Fq 'QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-eglfs}"'
unzip -p "$ARCHIVE" manifest.sha256 | grep -Fq "$EMU/dolphin-qt6"
echo "[OK] experimental Qt6 package contains separate binary, Qt runtime, EGLFS plugin and HIDAPI"
echo "[OK] stable NoGUI executable path is not overwritten"
