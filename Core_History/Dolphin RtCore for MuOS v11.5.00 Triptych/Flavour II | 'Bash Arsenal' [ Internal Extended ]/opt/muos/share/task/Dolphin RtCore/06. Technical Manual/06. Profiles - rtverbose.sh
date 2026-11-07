#!/bin/sh
# HELP: Technical Manual — rtverbose | Debug profile with verbose logging.
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
echo "  PROFILE — rtverbose (Debug)"
echo "------------------------------------------------------------"
echo "  Same settings as rtprime, but with verbose logging."
echo ""
echo "  SETTINGS"
echo "   Identical to rtprime, PLUS:"
echo "   Logger.ini          Verbosity = 4"
echo "   WriteToFile         True"
echo ""
echo "  PURPOSE"
echo "   Generate detailed logs of a game session."
echo "   Useful to diagnose crashes, glitched textures, missing audio,"
echo "   or any issue you want to report to the community."
echo ""
echo "  HOW TO USE"
echo "   1. Assign 'rtverbose' to the ROM folder"
echo "   2. Launch the game"
echo "   3. Reproduce the issue"
echo "   4. Exit with START+SELECT"
echo "   5. Collect the logs from:"
echo "      /opt/muos/share/emulator/dolphin/RtSys/logs/"
echo ""
echo "  WARNING"
echo "   Verbose logging writes many MB per session."
echo "   Only use rtverbose when you are debugging."
echo "   Clean logs afterwards (05. Logs -> Clean Logs)."
echo ""
echo "  HOW TO APPLY"
echo "   Content Explorer -> Assign Core -> Dolphin - rtverbose - upright"
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
