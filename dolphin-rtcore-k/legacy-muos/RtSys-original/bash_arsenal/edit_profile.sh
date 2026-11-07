#!/bin/bash
. "/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/_common.sh"
PROFILE="$1"
TIER="$2"
[ -z "$PROFILE" ] || [ -z "$TIER" ] && { echo "  [ERR] Usage: edit_profile.sh <profile> <tier>"; exit 1; }
SRC_D="$CFG/Dolphin.ini.${PROFILE}-${TIER}"
SRC_G="$CFG/GFX.ini.${PROFILE}-${TIER}"
[ ! -f "$SRC_D" ] && { echo "  [ERR] Missing: $SRC_D"; exit 1; }
[ ! -f "$SRC_G" ] && { echo "  [ERR] Missing: $SRC_G"; exit 1; }
cp -f "$SRC_D" "$CFG/Dolphin.ini.${PROFILE}"
cp -f "$SRC_G" "$CFG/GFX.ini.${PROFILE}"
echo "  [OK] Profile '$PROFILE' set to tier '$TIER'."
echo ""
echo "  Files updated:"
echo "    Dolphin.ini.$PROFILE  <-  Dolphin.ini.${PROFILE}-${TIER}"
echo "    GFX.ini.$PROFILE      <-  GFX.ini.${PROFILE}-${TIER}"
echo ""
echo "  Overclock : $(get_ini "$CFG/Dolphin.ini.$PROFILE" Overclock)"
echo "  VISkip    : $(get_ini "$CFG/GFX.ini.$PROFILE" VISkip)"
echo "  NoMipmap  : $(get_ini "$CFG/GFX.ini.$PROFILE" NoMipmapping)"
echo "  DisableFog: $(get_ini "$CFG/GFX.ini.$PROFILE" DisableFog)"
