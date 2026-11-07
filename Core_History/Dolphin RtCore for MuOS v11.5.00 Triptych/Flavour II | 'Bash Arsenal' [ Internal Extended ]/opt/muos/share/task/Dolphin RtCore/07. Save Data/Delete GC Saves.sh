#!/bin/sh
# HELP: Delete GC Saves | Delete GameCube memory cards and per-game saves.
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
echo "  Dolphin Rt:Core — Delete GC Saves"
echo "==============================================="
echo ""
echo "  WARNING: This will DELETE:"
echo "    - MemoryCardA.USA.raw"
echo "    - MemoryCardB.USA.raw"
echo "    - GC/USA/ (per-game saves)"
echo "    - GC/EUR/ (per-game saves)"
echo ""
echo "  SRAM.raw is kept."
echo ""

opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/delete_saves.sh gc

echo ""
echo "==============================================="
echo "  End of file - closing in ${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "$GENERAL_SLEEP"
FRONTEND start task
exit 0
