#!/bin/bash
# profile_reset.sh — restore all profiles from factory
CFG="/opt/muos/share/emulator/dolphin/Config"
FACTORY="/opt/muos/share/emulator/dolphin/RtSys/factory/Config"
clear
echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   RESET ALL PROFILES — Factory Restore          ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
echo "  This will overwrite ALL profile INIs in:"
echo "    $CFG"
echo "  with factory versions from:"
echo "    $FACTORY"
echo ""
read -p "  Confirm reset? [y/N]: " confirm
case "$confirm" in
    y|Y|yes|YES) ;;
    *) echo "  Cancelled."; sleep 2; exit 0 ;;
esac
cp -f "$FACTORY"/Dolphin.ini.* "$CFG/" 2>/dev/null
cp -f "$FACTORY"/GFX.ini.*     "$CFG/" 2>/dev/null
echo ""
echo "  ✓ All profiles reset to factory defaults"
echo ""
echo "  Closing in 5 seconds..."
sleep 5
