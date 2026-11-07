#!/bin/bash
. "/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/_common.sh"
[ ! -d "$FACTORY" ] && { echo "  [ERR] Factory folder not found: $FACTORY"; exit 1; }
RESTORED=0
for src in "$FACTORY"/Dolphin.ini.* "$FACTORY"/GFX.ini.*; do
    [ -f "$src" ] || continue
    cp -f "$src" "$CFG/$(basename "$src")" && RESTORED=$((RESTORED+1))
done
echo "  [OK] Factory reset complete."
echo ""
echo "  Files restored: $RESTORED"
echo "  Source        : $FACTORY"
echo ""
echo "  All profiles back to Comfort Zone defaults."
