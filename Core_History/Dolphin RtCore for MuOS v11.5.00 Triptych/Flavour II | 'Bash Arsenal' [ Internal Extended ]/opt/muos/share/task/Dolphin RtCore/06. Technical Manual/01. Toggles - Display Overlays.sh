#!/bin/sh
# HELP: Technical Manual — Display Overlays | FPS, VPS, Speed overlays.
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
echo "  TOGGLES — DISPLAY OVERLAYS"
echo "------------------------------------------------------------"
echo "  These write to GFX.ini (and all profile variants)."
echo ""
echo "  FPS (ShowFPS)"
echo "    Frames-per-second counter. Cost: minimal."
echo "    Recommended: ON for testing, OFF for normal play."
echo ""
echo "  VPS (ShowVPS)"
echo "    Vertical sync rate. Cost: minimal."
echo "    Use when chasing stutter or frame pacing issues."
echo ""
echo "  Speed (ShowSpeed)"
echo "    Emulation speed %. Cost: minimal."
echo "    Useful to spot CPU bottleneck (below 100% = struggling)."
echo ""
echo "  HOW TO ACTIVATE"
echo "    Task Toolkit -> Dolphin RtCore -> 02. Toggles"
echo "    Pick ON/OFF for each overlay."
echo ""
echo "  Files updated: all Config/GFX.ini and GFX.ini.* variants."
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
