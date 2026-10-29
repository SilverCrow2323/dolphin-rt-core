#!/bin/sh
# HELP: View Launcher Report | Show the last launcher report.
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


REPORT="/opt/muos/share/emulator/dolphin/RtSys/logs/launcher_report.log"

clear
echo "==============================================="
echo "  Dolphin Rt:Core — Launcher Report"
echo "==============================================="
echo ""

if [ -f "$REPORT" ]; then
    cat "$REPORT"
else
    echo "  No launcher report found."
    echo "  Launch a game first to generate one."
fi

echo ""
echo "==============================================="
echo "  End of file - closing in ${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "$GENERAL_SLEEP"
FRONTEND start task
exit 0
