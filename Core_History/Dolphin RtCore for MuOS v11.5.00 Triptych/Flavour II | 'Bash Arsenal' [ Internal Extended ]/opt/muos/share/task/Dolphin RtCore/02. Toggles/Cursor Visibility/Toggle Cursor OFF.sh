#!/bin/sh
# HELP: Toggle Cursor OFF | Show/hide the Wii pointer cursor.
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
echo "  Dolphin Rt:Core — Cursor Visibility (OFF)"
echo "==============================================="
echo ""
echo "  Note: mainly relevant for Wii titles that use"
echo "  the pointer (IR) cursor on screen."
echo ""

opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/toggle_dolphin_ini.sh CursorVisibility 0

echo ""
echo "==============================================="
echo "  End of file - closing in ${GENERAL_SLEEP} seconds"
echo "==============================================="
sleep "$GENERAL_SLEEP"
FRONTEND start task
exit 0
