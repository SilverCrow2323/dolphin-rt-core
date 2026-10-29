#!/bin/sh
# HELP: Expose All Tiers | Mode 2 — every tier visible in Assign Core.
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
echo "  Dolphin Rt:Core — Expose All Tiers (Mode 2)"
echo "==============================================="
echo ""

/opt/muos/share/emulator/dolphin/RtSys/switch_weapon/switch_weapon.sh 2

echo ""
echo "==============================================="
echo "  End of file - closing in ${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "$GENERAL_SLEEP"
FRONTEND start task
exit 0
