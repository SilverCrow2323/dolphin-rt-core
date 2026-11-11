#!/usr/bin/env bash
# Static regression checks for the muOS Dolphin runtime contract.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/dolphin-build/build-dolphin.sh"
PKG="$ROOT/dolphin-rtcore-muos/tools/build-muxupd.sh"
APP_LAUNCH="$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI/scripts/launch.sh"
EXT_LAUNCH="$ROOT/dolphin-rtcore-muos/overlay/opt/muos/script/launch/ext-dolphinrt.sh"

require() {
    local file="$1" needle="$2"
    if ! grep -Fq -- "$needle" "$file"; then
        echo "FAIL: expected '$needle' in $file" >&2
        exit 1
    fi
}

# The running executable and its resource tree live side by side on muOS.
require "$BUILD" 'case "$TARGET" in muos|muos-qt) LOCAL_SYS=ON;; esac'
require "$BUILD" '"-DLINUX_LOCAL_DEV=$LOCAL_SYS"'
require "$BUILD" 'cp -a "$SRC/Data/Sys/." "$OUT/Sys/"'
require "$BUILD" 'GC/font_western.bin GC/font_japanese.bin GC/dsp_rom.bin GC/dsp_coef.bin'

# Both muOS entry points must select the tested framebuffer/OpenGL path.
require "$APP_LAUNCH" '--platform=fbdev --video_backend=OGL'
require "$EXT_LAUNCH" '--platform=fbdev --video_backend=OGL'

# The updater must reject an incomplete resource payload before packaging.
require "$PKG" 'font_western.bin'
require "$PKG" 'font_japanese.bin'
require "$PKG" 'dsp_rom.bin'
require "$PKG" 'dsp_coef.bin'
require "$PKG" 'DOLPHIN_SYS_DIR="${DOLPHIN_SYS_DIR:-}"'
require "$PKG" 'SYS_SOURCE="$(cd "$DOLPHIN_SYS_DIR" && pwd -P)"'
require "$PKG" 'cp -a "$SYS_SOURCE/." "$S/$EMU/Sys/"'

echo "Dolphin muOS runtime contract: OK"
