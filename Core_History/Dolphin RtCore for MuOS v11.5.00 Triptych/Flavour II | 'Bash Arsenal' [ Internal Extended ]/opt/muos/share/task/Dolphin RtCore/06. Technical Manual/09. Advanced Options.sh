#!/bin/sh
# HELP: Technical Manual — Advanced Options | Mods and Load/ toggles.
# ICON: diagnostic
#
# ============================================================
#  [Bash Arsenal | Rt:CORE Sector]
# ============================================================
#
. /opt/muos/script/var/func.sh

FRONTEND stop

ORIG_FONT=""
[ -r /etc/vconsole.conf ] && ORIG_FONT=$(grep -i '^FONT=' /etc/vconsole.conf 2>/dev/null | cut -d= -f2-)
try_font() {
    [ -n "$1" ] || return 1
    for d in /usr/share/consolefonts /usr/share/kbd/consolefonts /usr/lib/kbd/consolefonts; do
        [ -d "$d" ] || continue
        for ext in .psf.gz .psf .fnt .fnt.gz; do
            if [ -f "$d/$1$ext" ] && command -v setfont >/dev/null 2>&1; then
                setfont "$d/$1$ext" 2>/dev/null && return 0
            fi
        done
    done
    return 1
}
FONT_OK=0
for f in ter-132n ter-124n ter-120n ter-116n LatArCyrHeb-22 LatArCyrHeb-19 LatArCyrHeb-16 sun12x22 VGA16; do
    if try_font "$f"; then FONT_OK=1; break; fi
done

clear
echo "============================================================"
echo "  Dolphin Rt:Core — Technical Manual"
echo "============================================================"
echo ""
echo "  ADVANCED OPTIONS — Graphics Mods & Load/"
echo "------------------------------------------------------------"
echo "  Automatically mirrors the Load/ folder structure."
echo "  For every subfolder, a mirror is created in the menu."
echo ""
echo "  WORKFLOW"
echo "   1. Install a mod into Load/GraphicMods/<Name>/"
echo "   2. Launch: 04. Advanced Options -> Refresh Mods List"
echo "   3. Toggle the mod on/off from the menu"
echo ""
echo "  HOW TOGGLES WORK"
echo "   GraphicMods  -> .disabled marker (native Dolphin)"
echo "   Others       -> folder renamed to .Name.disabled"
echo ""
echo "  BULK ACTIONS"
echo "   _Disable All    Disables every entry in the folder"
echo "   _Enable All     Enables every entry in the folder"
echo ""
echo "  RUNGIF"
echo "   The scanner runs a mysterious master who rebuilds"
echo "   the menu. If Load/ is empty, RUNGIF tells you."
echo "   If Load/ has mods, RUNGIF rebuilds the toggles."
echo ""
echo "  WHERE MODS LIVE"
echo "   /opt/muos/share/emulator/dolphin/Load/GraphicMods/"
echo "   /opt/muos/share/emulator/dolphin/Load/Textures/"
echo "   /opt/muos/share/emulator/dolphin/Load/Riivolution/"
echo ""
echo "============================================================"
echo "  End of page - closing in 15 seconds"
echo "============================================================"
sleep 15
if [ "$FONT_OK" = "1" ] && [ -n "$ORIG_FONT" ] && command -v setfont >/dev/null 2>&1; then
    setfont "$ORIG_FONT" 2>/dev/null || true
fi
FRONTEND start task
exit 0
