#!/bin/sh
# Dolphin Rt:Core v12 - post-install hook.
# muOS Andromeda runs this once after a .muxupd is installed, then deletes it.
# It must never fail the install: the app retries the same step at every start.

EMU=/opt/muos/share/emulator/dolphin
APP="/run/muos/storage/application/Dolphin RtUI"

# Make sure every script is executable even if the archive lost the mode bits.
chmod 755 /opt/muos/script/launch/ext-dolphinrt.sh 2>/dev/null
find "$EMU/RtSys" -name '*.sh' -exec chmod 755 {} + 2>/dev/null

# Rt:UI now owns these controls. Remove legacy Task Toolkit trees left by
# previous Rt:Core releases so old menu entries cannot remain on the SD card.
TASK_ROOT="${MUOS_TASK_ROOT:-/opt/muos/share/task}"
for TASK_DIR in "$TASK_ROOT"/Dolphin\ Rt*Core; do
    [ -d "$TASK_DIR" ] || continue
    rm -rf "$TASK_DIR" 2>/dev/null || true
done
chmod 755 "$APP/mux_launch.sh" "$APP"/scripts/*.sh "$APP"/tools/stream/*.sh "$APP/lib/moonlight" "$APP/lib/love" "$APP/lib/gptokeyb2" 2>/dev/null
[ -f "$EMU/dolphin" ] && chmod 755 "$EMU/dolphin" 2>/dev/null

# Register GameCube/Wii + all Rt:Core profiles in the core manifest.
if [ -x "$EMU/RtSys/manifest_tool.sh" ]; then
    mkdir -p "$EMU/RtSys/logs" 2>/dev/null
    sh "$EMU/RtSys/manifest_tool.sh" apply >> "$EMU/RtSys/logs/install.log" 2>&1 \
        || echo "$(date '+%F %T') manifest registration failed; the app will retry at start" >> "$EMU/RtSys/logs/install.log"
fi
exit 0
