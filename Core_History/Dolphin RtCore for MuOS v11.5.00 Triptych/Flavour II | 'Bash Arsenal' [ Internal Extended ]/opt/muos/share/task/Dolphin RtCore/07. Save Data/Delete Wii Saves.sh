#!/bin/sh
# HELP: Delete Wii Saves | Delete Wii game save data (keeps system files).
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
echo "  Dolphin Rt:Core — Delete Wii Saves"
echo "==============================================="
echo ""
echo "  WARNING: This will DELETE:"
echo "    - Wii/title/00010000/* (all game saves)"
echo ""
echo "  System menu and SYSCONF are kept."
echo ""

opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/delete_saves.sh wii

echo ""
echo "==============================================="
echo "  End of file - closing in ${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "$GENERAL_SLEEP"
FRONTEND start task
exit 0
