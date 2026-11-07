#!/bin/sh
# HELP: Technical Manual — Save Data | Delete GC and Wii saves safely.
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
echo "  SAVE DATA — Delete GC and Wii save files"
echo "------------------------------------------------------------"
echo "  Three tools in 07. Save Data:"
echo ""
echo "  Delete GC Saves"
echo "    Removes:"
echo "      GC/MemoryCardA.USA.raw"
echo "      GC/MemoryCardB.USA.raw"
echo "      GC/USA/  (per-game saves)"
echo "      GC/EUR/  (per-game saves)"
echo "    Keeps:"
echo "      GC/SRAM.raw  (system SRAM)"
echo ""
echo "  Delete Wii Saves"
echo "    Removes:"
echo "      Wii/title/00010000/*  (game saves only)"
echo "    Keeps:"
echo "      Wii/title/00000001/  (system menu)"
echo "      Wii/shared2/sys/SYSCONF"
echo ""
echo "  Delete All Saves"
echo "    Both of the above, in one command."
echo ""
echo "  WHEN TO USE"
echo "   Fresh start on a game."
echo "   Fix a corrupted save file."
echo "   Free up space."
echo ""
echo "  WARNING"
echo "   Deletion is immediate. No trash bin. No undo."
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
