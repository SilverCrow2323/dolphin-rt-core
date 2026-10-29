#!/bin/bash
# ============================================================
#  Bash Arsenal — Expose all tier variants in assign
#  SPDW Factory Lab / sirpips aka SilverCrow2323
# ============================================================
ASSIGN="/opt/muos/share/info/assign"
CREATED=0

for sys in "Nintendo Gamecube" "Nintendo Wii"; do
    ORIENTS="upright"
    [ "$sys" = "Nintendo Wii" ] && ORIENTS="upright sideways"

    for base in rtboost rtprime rtpure; do
        for tier in lite std max; do
            for o in $ORIENTS; do
                f="$ASSIGN/$sys/dolphin - $base-$tier - $o.ini"
                if [ ! -f "$f" ]; then
                    cat > "$f" << INI
[dolphin - $base-$tier - $o]
name=Dolphin - $base $tier - $o
core=ext-dolphin-$base-$tier-$o

[launch]
prep=
exec=/opt/muos/script/launch/ext-dolphinrt.sh
done=
INI
                    CREATED=$((CREATED+1))
                fi
            done
        done
    done
done

echo "  [OK] All tier variants exposed."
echo ""
echo "  Files created : $CREATED"
echo "  Location      : $ASSIGN"
echo ""
echo "  In Content Explorer -> Assign Core you will now see:"
echo "    Dolphin - rtboost - upright       (base)"
echo "    Dolphin - rtboost lite - upright  (tier)"
echo "    Dolphin - rtboost std - upright   (tier)"
echo "    Dolphin - rtboost max - upright   (tier)"
echo "    ... and the same for rtprime / rtpure"
