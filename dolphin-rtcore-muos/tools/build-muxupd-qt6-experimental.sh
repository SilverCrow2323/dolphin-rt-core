#!/usr/bin/env bash
# Separate experimental Qt 6 muOS update; stable NoGUI Dolphin is not replaced.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
OUT="${1:-$ROOT/dist}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
: "${DOLPHIN_NO_GUI_BIN:?set DOLPHIN_NO_GUI_BIN to the NoGUI binary from the same muos-qt build}"
: "${DOLPHIN_QT_BIN:?set DOLPHIN_QT_BIN to the muos-qt Dolphin GUI binary}"
: "${DOLPHIN_QT_LIB_DIR:?set DOLPHIN_QT_LIB_DIR to the staged Qt 6 lib directory}"
: "${DOLPHIN_QT_PLUGIN_DIR:?set DOLPHIN_QT_PLUGIN_DIR to the staged Qt 6 plugins directory}"
[ -x "$DOLPHIN_NO_GUI_BIN" ] || { echo "muOS NoGUI Dolphin binary is not executable" >&2; exit 1; }
[ -x "$DOLPHIN_QT_BIN" ] || { echo "Qt 6 Dolphin binary is not executable" >&2; exit 1; }
hdr="$(head -c 20 "$DOLPHIN_QT_BIN" | od -An -tx1 | tr -d ' \n')"
case "$hdr" in 7f454c46020101*b700) ;; *) echo "Qt 6 binary is not AArch64 ELF" >&2; exit 1;; esac
[ -s "$DOLPHIN_QT_LIB_DIR/libQt6Core.so.6" ] || { echo "missing libQt6Core.so.6" >&2; exit 1; }
[ -s "$DOLPHIN_QT_PLUGIN_DIR/platforms/libqeglfs.so" ] || { echo "missing Qt EGLFS platform plugin" >&2; exit 1; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BASE="$TMP/base"
STAGE="$TMP/stage"
mkdir -p "$BASE" "$STAGE"
DOLPHIN_BIN="$DOLPHIN_NO_GUI_BIN" DOLPHIN_LIB_DIR="${DOLPHIN_LIB_DIR:-}" DOLPHIN_SYS_DIR="${DOLPHIN_SYS_DIR:-}" \
  bash "$ROOT/tools/build-muxupd.sh" "$BASE"
BASE_ARCHIVE="$BASE/Dolphin_RtCore_v${VERSION//./_}_Andromeda.muxupd"
[ -s "$BASE_ARCHIVE" ] || { echo "base muOS archive was not created" >&2; exit 1; }
unzip -q "$BASE_ARCHIVE" -d "$STAGE"
EMU="$STAGE/opt/muos/share/emulator/dolphin"
mkdir -p "$EMU/qt6/lib" "$EMU/qt6/plugins"
install -m755 "$DOLPHIN_QT_BIN" "$EMU/dolphin-qt6"
cp -a "$DOLPHIN_QT_LIB_DIR/." "$EMU/qt6/lib/"
cp -a "$DOLPHIN_QT_PLUGIN_DIR/." "$EMU/qt6/plugins/"
cat > "$EMU/launch-qt6-experimental.sh" <<'QTLAUNCH'
#!/bin/sh
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
export LD_LIBRARY_PATH="$HERE/qt6/lib:$HERE/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="$HERE/qt6/plugins"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-eglfs}"
exec "$HERE/dolphin-qt6" "$@"
QTLAUNCH
chmod 755 "$EMU/launch-qt6-experimental.sh"
ARCHIVE="$OUT/Dolphin_RtCore_v${VERSION//./_}_Andromeda_qt6-experimental.muxupd"
(
  cd "$STAGE"
  rm -f manifest.sha256
  find opt run -type f -print | LC_ALL=C sort | xargs -d '\n' sha256sum > manifest.sha256
  rm -f "$ARCHIVE"
  zip -q -X -r -9 "$ARCHIVE" manifest.sha256 opt run
)
echo "built experimental Qt 6 package: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"
