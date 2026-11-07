#!/bin/bash
SCOPE="$1"
EMU="/opt/muos/share/emulator/dolphin"
GC_DIR="$EMU/GC"
WII_DIR="$EMU/Wii"
GC_COUNT=0
WII_COUNT=0

case "$SCOPE" in
    gc|all)
        for f in "$GC_DIR"/MemoryCard*.raw; do
            [ -f "$f" ] && rm -f "$f" && GC_COUNT=$((GC_COUNT+1))
        done
        for d in "$GC_DIR"/USA "$GC_DIR"/EUR "$GC_DIR"/JAP; do
            [ -d "$d" ] && rm -rf "$d" && GC_COUNT=$((GC_COUNT+1))
        done
        ;;
esac

case "$SCOPE" in
    wii|all)
        if [ -d "$WII_DIR/title/00010000" ]; then
            WII_COUNT=$(find "$WII_DIR/title/00010000" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
            rm -rf "$WII_DIR/title/00010000"/* 2>/dev/null
        fi
        ;;
esac

case "$SCOPE" in
    gc)  echo "  [OK] GameCube save data removed."; echo ""; echo "  Items deleted : $GC_COUNT" ;;
    wii) echo "  [OK] Wii save data removed."; echo ""; echo "  Game saves    : $WII_COUNT" ;;
    all) echo "  [OK] All save data removed."; echo ""; echo "  GC items      : $GC_COUNT"; echo "  Wii saves     : $WII_COUNT" ;;
esac

echo ""
echo "  Kept intact:"
echo "    - GC/SRAM.raw (system SRAM)"
echo "    - Wii/title/00000001 (system menu)"
echo "    - Wii/shared2/sys/SYSCONF (Wii system config)"
