#!/bin/sh
# HELP: Technical Manual — Assign & Tiers | How profiles appear in Content Explorer.
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

CONF="/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/manual_time.conf"
MANUAL_SLEEP=10
[ -f "$CONF" ] && . "$CONF" 2>/dev/null
[ -z "$MANUAL_SLEEP" ] && MANUAL_SLEEP=10

clear
echo "============================================================"
echo "  Dolphin Rt:Core — Technical Manual"
echo "============================================================"
echo ""
echo "  ASSIGN & TIERS"
echo "------------------------------------------------------------"
echo "  Two modes for the Content Explorer -> Assign Core menu."
echo ""
echo "  MODE 1 — STANDARD ONLY (default)"
echo "------------------------------------------------------------"
echo "  Only base profiles are visible:"
echo "    Dolphin - rtboost - upright"
echo "    Dolphin - rtprime - upright"
echo "    Dolphin - rtpure - upright"
echo "    Dolphin - rtverbose - upright"
echo ""
echo "  Clean. Compact. The tier is set separately."
echo ""
echo "  MODE 2 — ALL TIERS EXPOSED"
echo "------------------------------------------------------------"
echo "  Every tier variant is visible:"
echo "    Dolphin - rtboost - upright"
echo "    Dolphin - rtboost lite - upright"
echo "    Dolphin - rtboost std - upright"
echo "    Dolphin - rtboost max - upright"
echo "    ... same for rtprime / rtpure"
echo ""
echo "  For users who want to assign a specific tier"
echo "  to a specific game without using the adjusters."
echo ""
echo "  HOW TO SWITCH"
echo "------------------------------------------------------------"
echo "  Task Toolkit -> 03. Config Management:"
echo ""
echo "    Expose All Tiers   ->  Enable MODE 2"
echo "    Standard Only      ->  Return to MODE 1"
echo ""
echo "  HOW TO CHANGE TIER (MODE 1)"
echo "------------------------------------------------------------"
echo "  Task Toolkit -> 01. Profile Adjusters:"
echo ""
echo "    RtBoost [Performance]  ->  Lite / Standard / Max"
echo "    RtPrime [Balanced]     ->  Lite / Standard / Max"
echo "    RtPure  [Accuracy]     ->  Lite / Standard / Max"
echo ""
echo "  The tier you pick replaces the base profile file."
echo "  When you then launch from Content Explorer, the"
echo "  tier you selected is used automatically."
echo ""
echo "  RULE"
echo "------------------------------------------------------------"
echo "   Start with MODE 1. Keep it clean."
echo "   Only use MODE 2 if you need per-game tiers."
echo "   Return to MODE 1 when done experimenting."
echo ""
echo "============================================================"
echo "  End of page - closing in ${MANUAL_SLEEP} seconds"
echo "============================================================"
sleep "$MANUAL_SLEEP"
if [ "$FONT_OK" = "1" ] && [ -n "$ORIG_FONT" ] && command -v setfont >/dev/null 2>&1; then
    setfont "$ORIG_FONT" 2>/dev/null || true
fi
FRONTEND start task
exit 0
