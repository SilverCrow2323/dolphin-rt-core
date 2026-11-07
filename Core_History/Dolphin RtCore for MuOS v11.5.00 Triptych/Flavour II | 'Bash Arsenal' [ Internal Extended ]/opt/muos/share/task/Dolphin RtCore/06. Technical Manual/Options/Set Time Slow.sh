#!/bin/sh
# HELP: Set Time Slow | Set manual reading time to 15 seconds.
# ICON: diagnostic
#
# ============================================================
#  [Bash Arsenal | Rt:CORE Sector]
# ============================================================
#
. /opt/muos/script/var/func.sh

FRONTEND stop

CONF="/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/manual_time.conf"

clear
echo "==============================================="
echo "  Dolphin Rt:Core — Manual Reading Time"
echo "==============================================="
echo ""
echo "  Setting : Slow"
echo "  Time    : 15 seconds"
echo ""

cat > "$CONF" << 'CONFEOF'
# Dolphin Rt:Core — Technical Manual
# Reading time for manual pages, in seconds.
# Fast=5  Normal=10  Slow=15
# Change via: 06. Technical Manual -> Options -> Set Time
MANUAL_SLEEP=15
CONFEOF

. "$CONF" 2>/dev/null
if [ "$MANUAL_SLEEP" = "15" ]; then
    echo "  [OK] Manual reading time set to ${MANUAL_SLEEP}s"
    echo ""
    echo "  Every manual page will now auto-close"
    echo "  after ${MANUAL_SLEEP} seconds."
else
    echo "  [ERR] Could not write config file."
fi

echo ""
echo "==============================================="
echo "  End of file - closing in 3 seconds"
echo "==============================================="
sleep 3
FRONTEND start task
exit 0
