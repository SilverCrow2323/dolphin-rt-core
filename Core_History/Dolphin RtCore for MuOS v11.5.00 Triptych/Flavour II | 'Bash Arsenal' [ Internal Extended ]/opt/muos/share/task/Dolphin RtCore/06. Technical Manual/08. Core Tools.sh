#!/bin/sh
# HELP: Technical Manual — Core Tools | What each task in the menu does.
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
echo "  CORE TOOLS — Task Toolkit Sections"
echo "------------------------------------------------------------"
echo "  01. Profile Adjusters"
echo "        Change profile tiers (Lite / Standard / Max)."
echo ""
echo "  02. Toggles"
echo "        FPS / VPS / Speed overlay, OSD, Cursor."
echo ""
echo "  03. Config Management"
echo "        Show Active, Reset, Expose All Tiers,"
echo "        Standard Only."
echo ""
echo "  04. Advanced Options"
echo "        Refresh Mods List, per-mod toggles."
echo ""
echo "  05. Logs"
echo "        Clean Logs, View Launcher Report."
echo ""
echo "  06. Technical Manual"
echo "        You are here."
echo ""
echo "  07. Save Data"
echo "        Delete GC Saves, Delete Wii Saves, Delete All."
echo ""
echo "  ERADICATE"
echo "        Removes Dolphin entirely. No undo."
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
