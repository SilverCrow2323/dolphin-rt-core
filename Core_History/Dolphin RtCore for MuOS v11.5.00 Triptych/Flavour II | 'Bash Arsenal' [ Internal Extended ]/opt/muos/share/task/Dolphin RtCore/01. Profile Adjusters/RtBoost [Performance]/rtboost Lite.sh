#!/bin/sh
# HELP: rtboost Lite | Set rtboost (Performance Boost) to Lite tier.
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
echo "  Dolphin Rt:Core — rtboost (Performance Boost)"
echo "==============================================="
echo "  Tier : Lite"
echo ""

/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/edit_profile.sh rtboost lite

echo ""
echo "==============================================="
echo "  End of file - closing in ${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "$GENERAL_SLEEP"
FRONTEND start task
exit 0
