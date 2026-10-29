#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSIGN="$SCRIPT_DIR/../../../../info/assign"
MODE_FILE="$SCRIPT_DIR/../switch_weapon/mode.conf"

MODE=1
[ -f "$MODE_FILE" ] && . "$MODE_FILE"

VISIBLE_BASE=0
VISIBLE_TIER=0
HIDDEN_BASE=0
HIDDEN_TIER=0

for sys in "Nintendo Gamecube" "Nintendo Wii"; do
    [ -d "$ASSIGN/$sys" ] || continue
    cd "$ASSIGN/$sys" || continue
    for f in dolphin*.ini; do
        [ -f "$f" ] || continue
        case "$f" in
            *-lite-*|*-std-*|*-max-*) VISIBLE_TIER=$((VISIBLE_TIER+1)) ;;
            *) VISIBLE_BASE=$((VISIBLE_BASE+1)) ;;
        esac
    done
    for f in .dolphin*.ini; do
        [ -f "$f" ] || continue
        case "$f" in
            *-lite-*|*-std-*|*-max-*) HIDDEN_TIER=$((HIDDEN_TIER+1)) ;;
            *) HIDDEN_BASE=$((HIDDEN_BASE+1)) ;;
        esac
    done
done

echo "  mode.conf says : MODE $MODE"
if [ "$VISIBLE_TIER" -gt 0 ] && [ "$VISIBLE_BASE" -eq 0 ]; then
    echo "  Actual state   : MODE 2 (All Tiers)"
elif [ "$VISIBLE_BASE" -gt 0 ] && [ "$VISIBLE_TIER" -eq 0 ]; then
    echo "  Actual state   : MODE 1 (Standard Only)"
else
    echo "  Actual state   : MIXED / INCONSISTENT"
fi
echo ""
echo "  Visible base : $VISIBLE_BASE"
echo "  Visible tier : $VISIBLE_TIER"
echo "  Hidden base  : $HIDDEN_BASE"
echo "  Hidden tier  : $HIDDEN_TIER"
