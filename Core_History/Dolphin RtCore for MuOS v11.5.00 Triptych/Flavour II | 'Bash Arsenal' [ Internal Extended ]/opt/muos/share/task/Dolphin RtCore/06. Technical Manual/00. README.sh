#!/bin/sh
# HELP: Technical Manual — README | Index of reference pages.
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
echo "  SPDW Factory Lab / sirpips aka SilverCrow2323"
echo "============================================================"
echo ""
echo "  README — Index"
echo "------------------------------------------------------------"
echo "  Reference pages for Dolphin Rt:Core."
echo "  Every page is READ-ONLY and auto-closes in 15 seconds."
echo ""
echo "  INDEX"
echo "   01. Toggles — Display Overlays"
echo "   02. Toggles — On-Screen Info"
echo "   03. Profiles — rtboost (Performance)"
echo "   04. Profiles — rtpure (Compatibility)"
echo "   05. Profiles — rtprime (Balanced)"
echo "   06. Profiles — rtverbose (Debug)"
echo "   07. Profiles — How To Choose"
echo "   08. Core Tools"
echo "   09. Advanced Options"
echo "   10. Save Data"
echo "   11. Logger & Diagnostics"
echo "   12. Assign & Tiers"
echo ""
echo "  Each page covers ONE topic to stay readable."
echo ""
echo "  Recommendation: start from 07. How To Choose"
echo "  if you are new to the Rt:Core lineup."
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
