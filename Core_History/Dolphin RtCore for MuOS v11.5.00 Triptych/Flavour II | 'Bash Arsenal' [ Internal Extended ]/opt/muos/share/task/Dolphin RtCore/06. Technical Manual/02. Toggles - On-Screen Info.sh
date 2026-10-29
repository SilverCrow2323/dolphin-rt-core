#!/bin/sh
# HELP: Technical Manual — On-Screen Info | OSD, Cursor, and misc toggles.
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
echo "  TOGGLES — ON-SCREEN INFO"
echo "------------------------------------------------------------"
echo "  These write to Dolphin.ini (and all profile variants)."
echo ""
echo "  OSD (OnScreenDisplayMessages)"
echo "    In-game messages and notifications. Keep ON."
echo ""
echo "  OSDDuration"
echo "    Duration of OSD messages. 1000 / 2500 / 5000 ms."
echo ""
echo "  ActiveTitle (ShowActiveTitle)"
echo "    Window title with game name. Pointless on handheld."
echo ""
echo "  Cursor (CursorVisibility)"
echo "    Wii pointer cursor. 1 = on, 0 = off."
echo "    Mostly relevant for Wii titles that use the IR pointer."
echo ""
echo "  InputDisplay (ShowInputDisplay)"
echo "    Live controller overlay. Useful for debugging inputs."
echo ""
echo "  RTC (ShowRTC)"
echo "    Real-Time Clock during movie playback. TAS only."
echo ""
echo "  Lag (ShowLag)"
echo "    Input lag counter. Diagnostic only."
echo ""
echo "  NetPlayPing (ShowNetPlayPing)"
echo "    Ping display for NetPlay. Online only."
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
