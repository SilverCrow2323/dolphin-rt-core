#!/bin/sh
# HELP: Technical Manual — rtboost | Maximum performance profile.
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
echo "  PROFILE — rtboost (Performance)"
echo "------------------------------------------------------------"
echo "  Maximum performance. Push the H700 to its limit."
echo ""
echo "  SETTINGS"
echo "   CPUCore             4       (JITARM64)"
echo "   OverclockEnable     True"
echo "   Overclock           0.60    (aggressive underclock)"
echo "   SyncGPU             False"
echo "   EnableIdleSkipping  True"
echo "   TimingVariance      60"
echo "   ShaderCompilation   Async"
echo "   InternalResolution  1x"
echo ""
echo "  VISUAL HACKS (all ON)"
echo "   VISkip              True"
echo "   NoMipmapping        True"
echo "   DisableFog          True"
echo "   EFBToTextureEnable  True"
echo "   ImmediateXFBEnable  True"
echo "   SkipDuplicateXFBs   True"
echo ""
echo "  TRADE-OFFS"
echo "   May show graphical glitches in some titles."
echo "   Fog, mipmaps and vertical interrupt skipped."
echo "   Best used when FPS is the top priority."
echo ""
echo "  WHEN TO USE"
echo "   Titles that stutter on rtprime."
echo "   Games where visual fidelity does not matter."
echo ""
echo "  HOW TO APPLY"
echo "   Content Explorer -> Assign Core -> Dolphin - rtboost - upright"
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
