#!/bin/bash
# ============================================================
#  Bash Arsenal — Restore Standard Only in assign
#  SPDW Factory Lab / sirpips aka SilverCrow2323
# ============================================================
ASSIGN="/opt/muos/share/info/assign"
REMOVED=0

for sys in "Nintendo Gamecube" "Nintendo Wii"; do
    for base in rtboost rtprime rtpure; do
        for tier in lite std max; do
            for f in "$ASSIGN/$sys/dolphin - $base-$tier - "*.ini; do
                [ -f "$f" ] || continue
                rm -f "$f"
                REMOVED=$((REMOVED+1))
            done
        done
    done
done

echo "  [OK] Standard-only mode restored."
echo ""
echo "  Files removed : $REMOVED"
echo "  Location      : $ASSIGN"
echo ""
echo "  In Content Explorer -> Assign Core you will now see ONLY:"
echo "    Dolphin - rtboost - upright"
echo "    Dolphin - rtprime - upright"
echo "    Dolphin - rtpure - upright"
echo "    Dolphin - rtverbose - upright"
echo "    (plus Comfort Zone legacy profiles)"
echo ""
echo "  To change tier, use the Profile Adjusters tasks."
