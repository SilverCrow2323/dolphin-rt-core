#!/bin/sh
# HELP: Delete All Saves | Delete both GameCube and Wii save data.
# ICON: diagnostic
#
# ============================================================
#  [Bash Arsenal | Rt:CORE Sector]
# ============================================================
#
. /opt/muos/script/var/func.sh

FRONTEND stop

# ── General reading time ──
CONF="/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/general_time.conf"
GENERAL_SLEEP=3
[ -f "$CONF" ] && . "$CONF" 2>/dev/null
[ -z "$GENERAL_SLEEP" ] && GENERAL_SLEEP=3


clear
echo "==============================================="
echo "  Dolphin Rt:Core — Delete ALL Saves"
echo "==============================================="
echo ""
echo "  WARNING: This deletes GC AND Wii save data."
echo "  System files are kept."
echo ""

opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/delete_saves.sh all

echo ""
echo "==============================================="
echo "  End of file - closing in ${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "$GENERAL_SLEEP"
FRONTEND start task
exit 0
