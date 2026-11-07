#!/bin/bash
# ============================================================
#  switch_weapon.sh <1|2>
#  SPDW Factory Lab / sirpips aka SilverCrow2323
# ============================================================
#  Mode 1: base profiles  (Comfort Zone legacy + Rt:Core base)
#  Mode 2: tier profiles  (rtboost/rtprime/rtpure × lite/std/max)
#
#  Architecture:
#    switch_weapon/{gc,wii}/mode {1,2}/ = source of truth
#    info/assign/{Nintendo Gamecube,Nintendo Wii}/ = active copy
#
#  Switching = wipe assign folder, copy from source.
# ============================================================

SW_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSIGN="$SW_DIR/../../../../info/assign"
MODE_FILE="$SW_DIR/mode.conf"

TARGET="$1"
if [ "$TARGET" != "1" ] && [ "$TARGET" != "2" ]; then
    echo "  [ERR] Usage: switch_weapon.sh <1|2>"
    exit 1
fi

[ -d "$ASSIGN" ] || { echo "  [ERR] Assign folder not found: $ASSIGN"; exit 1; }
[ -d "$SW_DIR/gc/mode $TARGET" ] || { echo "  [ERR] Source missing: gc/mode $TARGET"; exit 1; }
[ -d "$SW_DIR/wii/mode $TARGET" ] || { echo "  [ERR] Source missing: wii/mode $TARGET"; exit 1; }

# ── Wipe active assign folders ─────────────────────────────
rm -rf "$ASSIGN/Nintendo Gamecube" "$ASSIGN/Nintendo Wii"
mkdir -p "$ASSIGN/Nintendo Gamecube" "$ASSIGN/Nintendo Wii"

# ── Copy from source ───────────────────────────────────────
cp -f "$SW_DIR/gc/mode $TARGET/"*.ini  "$ASSIGN/Nintendo Gamecube/"
cp -f "$SW_DIR/wii/mode $TARGET/"*.ini "$ASSIGN/Nintendo Wii/"

GC_COUNT=$(ls -1 "$ASSIGN/Nintendo Gamecube/" | wc -l)
WII_COUNT=$(ls -1 "$ASSIGN/Nintendo Wii/" | wc -l)

# ── Write state ────────────────────────────────────────────
cat > "$MODE_FILE" << EOF
# Dolphin Rt:Core — switch_weapon state
MODE=$TARGET
EOF

# ── Report ─────────────────────────────────────────────────
if [ "$TARGET" = "1" ]; then
    echo "  [OK] Mode 1 — Standard Only"
else
    echo "  [OK] Mode 2 — All Tiers Exposed"
fi
echo ""
echo "  GameCube : $GC_COUNT files"
echo "  Wii      : $WII_COUNT files"
echo ""
echo "  Reboot muOS to refresh Content Explorer cache."
