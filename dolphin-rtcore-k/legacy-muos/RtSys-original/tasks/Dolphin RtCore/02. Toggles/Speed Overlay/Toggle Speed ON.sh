#!/bin/sh
# HELP: Toggle Speed ON | Turn the emulation Speed overlay ON in all profiles.
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
echo "  Dolphin Rt:Core — Speed Overlay (ON)"
echo "==============================================="
echo ""

opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/toggle_overlay.sh Speed True

echo ""
echo "==============================================="
echo "  End of file - closing in ${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "$GENERAL_SLEEP"
FRONTEND start task
exit 0
