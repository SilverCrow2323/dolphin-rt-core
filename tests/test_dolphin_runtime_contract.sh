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
require "$BUILD" 'case "$TARGET" in muos|muos-qt|knulli|fbdev|rocknix) LOCAL_SYS=ON;; esac'
require "$BUILD" '"-DLINUX_LOCAL_DEV=$LOCAL_SYS"'
require "$BUILD" "libhidapi-hidraw.so.0"
require "$BUILD" 'rm -rf "$OUT/Sys"'
require "$BUILD" 'cp -a "$SRC/Data/Sys/." "$OUT/Sys/"'
require "$BUILD" 'GC/font_western.bin GC/font_japanese.bin GC/dsp_rom.bin GC/dsp_coef.bin'

# Both muOS entry points must select the tested framebuffer/OpenGL path.
require "$APP_LAUNCH" '--platform=fbdev --video_backend=OGL'
require "$APP_LAUNCH" 'LD_LIBRARY_PATH="$EMU/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"'
require "$EXT_LAUNCH" '--platform=fbdev --video_backend=OGL'

# gptokeyb2 uses its native FSM syntax. Never enable its built-in
# START+SELECT kill binding; Rt:Core Safe Exit owns the M / combo watcher.
require "$APP_LAUNCH" '"$GPTK_BIN" dolphin -c "$GPTK_CFG" -D states,keyboard'
require "$EXT_LAUNCH" '"$GPTK_BIN" dolphin -c "$GPTK_CFG" -D states,keyboard'
if grep -Fq -- '-1 dolphin' "$APP_LAUNCH" "$EXT_LAUNCH"; then
    echo "FAIL: gptokeyb2 START+SELECT kill mode must remain disabled" >&2
    exit 1
fi
require "$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI/workshop/hotkeys/Default/ext-dolphin.gptk" '[controls:rt_hotkeys]'
require "$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI/workshop/hotkeys/Default/ext-dolphin.gptk" 'l2 = hold_state rt_hotkeys'
for launcher in "$APP_LAUNCH" "$EXT_LAUNCH"; do
    gptk_line="$(grep -nF '"$GPTK_BIN" dolphin -c "$GPTK_CFG"' "$launcher" | head -1 | cut -d: -f1)"
    dolphin_line="$(grep -nE '(^|[[:space:]])(\./)?"?\$DOLPHIN"? --platform=fbdev' "$launcher" | head -1 | cut -d: -f1)"
    [ -n "$gptk_line" ] && [ -n "$dolphin_line" ] && [ "$gptk_line" -lt "$dolphin_line" ] || {
        echo "FAIL: gptokeyb2 must attach before Dolphin starts in $launcher" >&2
        exit 1
    }
done

# The updater must reject an incomplete resource payload before packaging.
require "$PKG" 'font_western.bin'
require "$PKG" 'font_japanese.bin'
require "$PKG" 'dsp_rom.bin'
require "$PKG" 'dsp_coef.bin'
require "$PKG" 'DOLPHIN_SYS_DIR="${DOLPHIN_SYS_DIR:-}"'
require "$ROOT/dolphin-rtcore-muos/tools/build-muxupd-qt6-experimental.sh" 'DOLPHIN_NO_GUI_BIN'
require "$ROOT/dolphin-rtcore-muos/tools/build-muxupd-qt6-experimental.sh" 'DOLPHIN_BIN="$DOLPHIN_NO_GUI_BIN"'
require "$ROOT/dolphin-rtcore-muos/tools/build-muxupd-qt6-experimental.sh" 'dolphin-qt6'
require "$ROOT/dolphin-rtcore-muos/tools/build-muxupd-qt6-experimental.sh" 'QT_QPA_PLATFORM'
require "$PKG" 'DOLPHIN_LIB_DIR="${DOLPHIN_LIB_DIR:-}"'
require "$PKG" "libhidapi-hidraw.so.0"
require "$EXT_LAUNCH" 'LD_LIBRARY_PATH="$EMUDIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"'
require "$PKG" 'SYS_SOURCE="$(cd "$DOLPHIN_SYS_DIR" && pwd -P)"'
require "$PKG" 'cp -a "$SYS_SOURCE/." "$S/$EMU/Sys/"'

echo "Dolphin muOS runtime contract: OK"
