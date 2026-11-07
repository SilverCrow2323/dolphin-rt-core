#!/bin/sh
# HELP: Toggle All Games Bloom Removal | Enable or disable this Graphics Mod.
# ICON: theme
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


MOD_DIR="/opt/muos/share/emulator/dolphin/Load/GraphicMods/All Games Bloom Removal"
MARKER="$MOD_DIR/.disabled"

clear
echo "==============================================="
echo "  Graphics Mod: All Games Bloom Removal"
echo "==============================================="
echo ""

if [ ! -d "$MOD_DIR" ]; then
    echo "  [ERR] Mod folder not found."
    STATUS="ERROR"
elif [ -f "$MARKER" ]; then
    rm -f "$MARKER"
    echo "  [OK] Mod ENABLED."
    echo ""
    echo "  The mod will be active at the next launch."
    STATUS="ENABLED"
else
    touch "$MARKER"
    echo "  [OK] Mod DISABLED."
    echo ""
    echo "  The mod will be ignored at the next launch."
    STATUS="DISABLED"
fi

echo ""
echo "  Mod    : All Games Bloom Removal"
echo "  Status : $STATUS"
echo ""
echo "==============================================="
echo "  End of file - closing in ${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "$GENERAL_SLEEP"
FRONTEND start task
exit 0
