#!/bin/sh
# HELP: Set General Time Slow | Set general script reading time to 7 seconds.
# ICON: diagnostic
#
# ============================================================
#  [Bash Arsenal | Rt:CORE Sector]
# ============================================================
#
. /opt/muos/script/var/func.sh

FRONTEND stop

CONF="/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/general_time.conf"

clear
echo "==============================================="
echo "  Dolphin Rt:Core — General Reading Time"
echo "==============================================="
echo ""
echo "  Setting : Slow"
echo "  Time    : 7 seconds"
echo ""

cat > "$CONF" << 'CONFEOF'
# Dolphin Rt:Core — Bash Arsenal
# Reading time for regular script output, in seconds.
# Fast=3  Normal=5  Slow=7
# Change via: 06. Technical Manual -> Options -> Set General Time
GENERAL_SLEEP=7
CONFEOF

. "$CONF" 2>/dev/null
if [ "$GENERAL_SLEEP" = "7" ]; then
    echo "  [OK] General reading time set to ${GENERAL_SLEEP}s"
    echo ""
    echo "  Every script output will now auto-close"
    echo "  after ${GENERAL_SLEEP} seconds."
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
