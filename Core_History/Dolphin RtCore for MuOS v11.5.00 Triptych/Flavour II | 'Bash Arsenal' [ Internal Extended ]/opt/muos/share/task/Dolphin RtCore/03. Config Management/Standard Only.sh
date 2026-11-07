#!/bin/sh
# HELP: Standard Only | Remove tier variants from Assign Core, keep base profiles only.
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
echo "  Dolphin Rt:Core — Standard Only"
echo "==============================================="
echo ""
echo "  This will remove every tier variant (lite/std/max)"
echo "  from the Assign Core menu."
echo ""
echo "  You will only see the base profiles:"
echo "    - rtboost"
echo "    - rtprime"
echo "    - rtpure"
echo "    - rtverbose"
echo ""

/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/standard_only.sh

echo ""
echo "==============================================="
echo "  End of file - closing in ${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "$GENERAL_SLEEP"
FRONTEND start task
exit 0
