#!/usr/bin/env bash
# Builds dist/DolphinStream-muOS-<version>.zip
# Uses muOS Moonlight (/opt/muos/share/application/Moonlight) at runtime:
# love, libs (except gptokeyb2), moonlight/ and keys/ are NOT bundled.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d "[:space:]" < "$ROOT/VERSION")"
OUT="${1:-$ROOT/dist}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

APP_DIR=$(find "$ROOT/muos" -maxdepth 1 -mindepth 1 -type d | head -1)
[ -n "$APP_DIR" ] || { echo "! no app dir under muos/"; exit 1; }
APP_NAME=$(basename "$APP_DIR")
echo "app dir: $APP_NAME"

cd "$ROOT/muos"
rm -f "$OUT/DolphinStream-muOS-$VERSION.zip"

# Base excludes: runtime + secrets + system binaries (all provided by muOS)
zip -qry "$OUT/DolphinStream-muOS-$VERSION.zip" "$APP_NAME" \
    -x "*/__pycache__/*" \
    -x "*/conf/*.tsv" -x "*/conf/*.log" -x "*/conf/*.done" \
    -x "*/conf/*.status" -x "*/conf/*.result" -x "*/conf/*.txt" \
    -x "*/conf/stream.conf" -x "*/conf/ui.cfg" -x "*/conf/state.txt" \
    -x "*/covers/*.png" -x "*/launch.txt" -x "*/launch.env" \
    -x "*/keys/*" -x "*/moonlight/*" \
    -x "*/love" \
    -x "*/libs/liblove-*.so*" -x "*/libs/libluajit-*.so*"

# Add gptokeyb2 explicitly (the only lib we ship)
if [ -f "$APP_DIR/libs/gptokeyb2" ]; then
    zip -qj "$OUT/DolphinStream-muOS-$VERSION.zip" "$APP_DIR/libs/gptokeyb2"
    echo "  + gptokeyb2"
fi

echo "built $OUT/DolphinStream-muOS-$VERSION.zip"

# Report what is NOT bundled (for the README check)
echo ""
echo "Not bundled (taken from /opt/muos/share/application/Moonlight at runtime):"
echo "  love, libs/*.so, moonlight/, keys/"
echo "Bundled:"
echo "  app code + assets + gptokeyb2"


