#!/bin/sh
# HELP: Technical Manual — rtprime | Balanced daily driver profile.
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
echo "  PROFILE — rtprime (Balanced / Stability)"
echo "------------------------------------------------------------"
echo "  Daily driver. Best balance between speed and quality."
echo ""
echo "  SETTINGS"
echo "   CPUCore             4       (JITARM64)"
echo "   OverclockEnable     False"
echo "   Overclock           1.0     (no underclock)"
echo "   SyncGPU             False"
echo "   EnableIdleSkipping  True"
echo "   TimingVariance      40"
echo "   ShaderCompilation   Async"
echo "   InternalResolution  1x"
echo ""
echo "  VISUAL HACKS (moderate)"
echo "   VISkip              True    (harmless)"
echo "   NoMipmapping        False   (kept for quality)"
echo "   DisableFog          False   (kept for atmosphere)"
echo "   EFBToTextureEnable  True    (fast path, no glitches)"
echo "   EFBAccessEnable     False"
echo "   ImmediateXFBEnable  False"
echo "   SkipDuplicateXFBs   True"
echo ""
echo "  TRADE-OFFS"
echo "   Best stability across the widest range of titles."
echo "   Fewer glitches than rtboost, more FPS than rtpure."
echo ""
echo "  WHEN TO USE"
echo "   90% of your library."
echo "   Start here if you don't know which profile to pick."
echo ""
echo "  HOW TO APPLY"
echo "   Content Explorer -> Assign Core -> Dolphin - rtprime - upright"
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
