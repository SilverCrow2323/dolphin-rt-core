#!/bin/bash
. "/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/_common.sh"
REPORT="$LOGDIR/launcher_report.log"
MODS="$EMU/Load/GraphicMods"
GS="$EMU/GameSettings"

echo "  ── Last Launcher Report ─────────────────────"
if [ -f "$REPORT" ]; then
    grep -E "^(NAME|CORE|ORIENT|GAMEID|GAMENAME|Exit code|Status)" "$REPORT" | sed 's/^/    /'
else
    echo "    (no report yet — launch a game first)"
fi
echo ""
echo "  ── Active INI Values ─────────────────────────"
printf "    CPUCore               : %s\n" "$(get_ini "$CFG/Dolphin.ini" CPUCore)"
printf "    Overclock             : %s\n" "$(get_ini "$CFG/Dolphin.ini" Overclock)"
printf "    ShaderCompilationMode : %s\n" "$(get_ini "$CFG/GFX.ini" ShaderCompilationMode)"
printf "    VISkip                : %s\n" "$(get_ini "$CFG/GFX.ini" VISkip)"
printf "    NoMipmapping          : %s\n" "$(get_ini "$CFG/GFX.ini" NoMipmapping)"
printf "    DisableFog            : %s\n" "$(get_ini "$CFG/GFX.ini" DisableFog)"
printf "    ShowFPS               : %s\n" "$(get_ini "$CFG/GFX.ini" ShowFPS)"
printf "    ShowVPS               : %s\n" "$(get_ini "$CFG/GFX.ini" ShowVPS)"
echo ""
echo "  ── Active Graphics Mods ─────────────────────"
if [ -d "$MODS" ]; then
    FOUND=0
    for d in "$MODS"/*/; do
        [ -f "$d/.disabled" ] && continue
        echo "    ✓ $(basename "$d")"
        FOUND=1
    done
    [ "$FOUND" = "0" ] && echo "    (none active)"
fi
echo ""
echo "  ── GameSettings Overrides ───────────────────"
if [ -d "$GS" ]; then
    ls -1 "$GS"/*.ini 2>/dev/null | while read f; do echo "    $(basename "$f")"; done
fi
