#!/bin/bash
. "/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/_common.sh"
KEY_NAME="$1"; NEW_VALUE="$2"
case "$KEY_NAME" in
    FPS)   KEY="ShowFPS" ;;
    VPS)   KEY="ShowVPS" ;;
    Speed) KEY="ShowSpeed" ;;
    *)     echo "  [ERR] Unknown key: $KEY_NAME"; exit 1 ;;
esac
case "$NEW_VALUE" in True|False) ;; *) echo "  [ERR] Unknown value: $NEW_VALUE"; exit 1 ;; esac
CHANGED=0
for f in "$CFG"/GFX.ini "$CFG"/GFX.ini.*; do
    [ -f "$f" ] || continue
    set_ini "$f" "Settings" "$KEY" "$NEW_VALUE" && CHANGED=$((CHANGED+1))
done
echo "  [OK] $KEY = $NEW_VALUE"
echo ""
echo "  Files updated : $CHANGED"
echo "  Effect        : overlay will be $( [ "$NEW_VALUE" = "True" ] && echo "visible" || echo "hidden" ) after restarting the game."
