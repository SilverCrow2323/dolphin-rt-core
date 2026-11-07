#!/bin/bash
# overlay_toggle.sh <FPS|VPS> — toggle ShowFPS/ShowVPS in all profiles
KEY="${1:-FPS}"
CFG="/opt/muos/share/emulator/dolphin/Config"
case "$KEY" in
    FPS) INI_KEY="ShowFPS" ;;
    VPS) INI_KEY="ShowVPS" ;;
    *) exit 1 ;;
esac
clear
echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   TOGGLE $INI_KEY OVERLAY                       ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
CURRENT="unknown"
if [ -f "$CFG/GFX.ini" ]; then
    CURRENT=$(grep -E "^$INI_KEY = " "$CFG/GFX.ini" | head -1 | cut -d= -f2 | tr -d ' ')
fi
echo "  Current value: $CURRENT"
if [ "$CURRENT" = "True" ]; then NEW="False"; else NEW="True"; fi
echo "  Will set to  : $NEW"
echo ""
read -p "  Confirm? [y/N]: " c
case "$c" in y|Y|yes|YES) ;; *) echo "  Cancelled."; sleep 2; exit 0 ;; esac
for f in "$CFG"/GFX.ini "$CFG"/GFX.ini.*; do
    [ -f "$f" ] || continue
    if grep -q "^$INI_KEY = " "$f"; then
        sed -i "s/^$INI_KEY = .*/$INI_KEY = $NEW/" "$f"
    else
        sed -i "/^\[Settings\]/a $INI_KEY = $NEW" "$f"
    fi
done
echo ""
echo "  ✓ Set $INI_KEY = $NEW in all profile files"
echo ""
echo "  Closing in 5 seconds..."
sleep 5
