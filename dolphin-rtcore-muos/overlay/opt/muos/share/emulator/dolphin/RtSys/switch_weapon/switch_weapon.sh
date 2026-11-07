#!/bin/bash
# ============================================================
#  switch_weapon.sh <1|2>        (muOS 2606 Andromeda edition)
#  SPDW Factory Lab / sirpips aka SilverCrow2323
# ============================================================
#  Mode 1: base profiles  (Comfort Zone legacy + Rt:Core base)
#  Mode 2: tier profiles  (rtboost/rtprime/rtpure x lite/std/max)
#
#  switch_weapon/{gc,wii}/mode {1,2}/*.ini are the source of truth.
#  Andromeda no longer reads info/assign/*.ini: RtSys/manifest_tool.sh turns the
#  sources into manifest entries for "Nintendo Gamecube" / "Nintendo Wii".
# ============================================================
SW_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL="$SW_DIR/../manifest_tool.sh"
TARGET="$1"
if [ "$TARGET" != "1" ] && [ "$TARGET" != "2" ]; then
    echo "  [ERR] Usage: switch_weapon.sh <1|2>"; exit 1
fi
[ -d "$SW_DIR/gc/mode $TARGET" ]  || { echo "  [ERR] Source missing: gc/mode $TARGET"; exit 1; }
[ -d "$SW_DIR/wii/mode $TARGET" ] || { echo "  [ERR] Source missing: wii/mode $TARGET"; exit 1; }

if [ -e /opt/muos/share/info/manifest ] && [ -x "$TOOL" ]; then
    sh "$TOOL" apply "$TARGET" || exit 1
    echo ""
    [ "$TARGET" = "1" ] && echo "  Mode 1 - Standard Only" || echo "  Mode 2 - All Tiers Exposed"
    echo "  Core assignments were refreshed; reopen Content Explorer to see the new list."
    exit 0
fi

# ── Legacy fallback (pre-Andromeda muOS only) ──────────────
ASSIGN="$SW_DIR/../../../../info/assign"
[ -d "$ASSIGN" ] || { echo "  [ERR] No manifest and no assign folder: nothing to switch"; exit 1; }
rm -rf "$ASSIGN/Nintendo Gamecube" "$ASSIGN/Nintendo Wii"
mkdir -p "$ASSIGN/Nintendo Gamecube" "$ASSIGN/Nintendo Wii"
cp -f "$SW_DIR/gc/mode $TARGET/"*.ini  "$ASSIGN/Nintendo Gamecube/"
cp -f "$SW_DIR/wii/mode $TARGET/"*.ini "$ASSIGN/Nintendo Wii/"
printf '# Dolphin Rt:Core - switch_weapon state\nMODE=%s\n' "$TARGET" > "$SW_DIR/mode.conf"
echo "  [OK] Mode $TARGET (legacy assign). Reboot muOS to refresh the Content Explorer cache."
