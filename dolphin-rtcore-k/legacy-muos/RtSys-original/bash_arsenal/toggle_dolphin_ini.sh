#!/bin/bash
. "/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/_common.sh"
KEY="$1"; VALUE="$2"
[ -z "$KEY" ] || [ -z "$VALUE" ] && exit 1
CHANGED=0
for f in "$CFG"/Dolphin.ini "$CFG"/Dolphin.ini.*; do
    [ -f "$f" ] || continue
    set_ini "$f" "Interface" "$KEY" "$VALUE" && CHANGED=$((CHANGED+1))
done
echo "  [OK] $KEY = $VALUE"
echo ""
echo "  Files updated : $CHANGED"
