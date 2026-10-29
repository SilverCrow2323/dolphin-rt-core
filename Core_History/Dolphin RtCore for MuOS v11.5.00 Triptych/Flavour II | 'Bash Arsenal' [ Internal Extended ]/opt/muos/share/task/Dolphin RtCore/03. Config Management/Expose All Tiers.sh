#!/bin/sh
# HELP: Expose All Tiers | Add all tier variants (lite/std/max) to Assign Core.
# ICON: storage
#
# ============================================================
#  [Bash Arsenal | Rt:CORE Sector]
# ============================================================
#
. /opt/muos/script/var/func.sh

FRONTEND stop

CONF="/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/general_time.conf"
GENERAL_SLEEP=3
[ -f "$CONF" ] && . "$CONF" 2>/dev/null
[ -z "$GENERAL_SLEEP" ] && GENERAL_SLEEP=3

clear
echo "==============================================="
echo "  Dolphin Rt:Core — Expose All Tiers"
echo "==============================================="
echo ""
echo "  This will add every tier variant to the"
echo "  Content Explorer -> Assign Core menu."
echo ""
echo "  You will see:"
echo "    - rtboost (base)"
echo "    - rtboost lite"
echo "    - rtboost std"
echo "    - rtboost max"
echo "    - rtprime / rtpure (same pattern)"
echo ""

/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/expose_all_tiers.sh

echo ""
echo "==============================================="
echo "  End of file - closing in ${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "$GENERAL_SLEEP"
FRONTEND start task
exit 0
