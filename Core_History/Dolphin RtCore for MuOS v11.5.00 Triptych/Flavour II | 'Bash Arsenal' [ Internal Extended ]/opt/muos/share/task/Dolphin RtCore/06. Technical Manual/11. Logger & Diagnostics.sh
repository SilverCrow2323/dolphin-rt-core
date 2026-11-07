#!/bin/sh
# HELP: Technical Manual — Logger & Diagnostics | Where to find logs.
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
echo "  LOGGER & DIAGNOSTICS"
echo "------------------------------------------------------------"
echo "  WHERE LOGS LIVE"
echo "   /opt/muos/share/emulator/dolphin/RtSys/logs/"
echo ""
echo "  LOG FILES"
echo "   launcher_report.log   Last session summary (overwritten)"
echo "   watcher.log           START+SELECT events (append)"
echo "   dolphin_debug.log     Only written by rtverbose"
echo ""
echo "  HOW TO ACCESS"
echo "   Task Toolkit -> 05. Logs -> View Launcher Report"
echo "   Or from a PC: SSH into the device and read directly."
echo ""
echo "  LOGGER VERBOSITY"
echo "   Default profiles    Verbosity 1, no file write"
echo "   rtverbose           Verbosity 4, file write ON"
echo ""
echo "  WHEN TO USE rtverbose"
echo "   - Debugging a crash"
echo "   - Reporting an issue on the forum"
echo "   - Understanding what Dolphin is doing"
echo ""
echo "  CLEANUP"
echo "   Task Toolkit -> 05. Logs -> Clean Logs"
echo "   Deletes all log files, preserves folders."
echo ""
echo "  TIP"
echo "   rtverbose writes 10+ MB per 5-minute session."
echo "   Clean up after every debugging session."
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
