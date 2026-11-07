#!/bin/bash
# profile_edit.sh — change tier (Lite/Std/Max) for a profile
CFG="/opt/muos/share/emulator/dolphin/Config"
clear
echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   EDIT RT:PROFILE — Tier Selector               ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
echo "  Available profiles:"
echo "    1) performance"
echo "    2) rintromping"
echo ""
read -p "  Choose profile [1-2]: " prof_choice
case "$prof_choice" in
    1) PROFILE="performance" ;;
    2) PROFILE="rintromping" ;;
    *) echo "  Invalid choice."; sleep 3; exit 1 ;;
esac
echo ""
echo "  Current tier for $PROFILE:"
for tier in lite std max; do
    echo "    $tier  →  Dolphin.ini.$PROFILE-$tier"
done
echo ""
echo "  Choose tier:"
echo "    1) lite  (best visual, standard perf)"
echo "    2) std   (balanced, Comfort Zone default)"
echo "    3) max   (aggressive underclock)"
echo ""
read -p "  Choose tier [1-3]: " tier_choice
case "$tier_choice" in
    1) TIER="lite" ;;
    2) TIER="std" ;;
    3) TIER="max" ;;
    *) echo "  Invalid choice."; sleep 3; exit 1 ;;
esac
echo ""
if [ ! -f "$CFG/Dolphin.ini.$PROFILE-$TIER" ]; then
    echo "  ERROR: $CFG/Dolphin.ini.$PROFILE-$TIER not found"
    sleep 3
    exit 1
fi
cp "$CFG/Dolphin.ini.$PROFILE-$TIER" "$CFG/Dolphin.ini.$PROFILE"
cp "$CFG/GFX.ini.$PROFILE-$TIER"     "$CFG/GFX.ini.$PROFILE"
echo "  ✓ Applied: $PROFILE → tier $TIER"
echo ""
echo "  Next time you launch a game with the '$PROFILE' core, this tier"
echo "  will be used."
echo ""
echo "  Closing in 5 seconds..."
sleep 5
