#!/bin/bash
# config_show.sh — show current active configuration
CFG="/opt/muos/share/emulator/dolphin/Config"
REPORT="/opt/muos/share/emulator/dolphin/RtSys/logs/launcher_report.log"
clear
echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   DOLPHIN Rt:CORE — ACTIVE CONFIGURATION        ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
if [ -f "$REPORT" ]; then
    echo "  ── Last Launcher Report ──"
    grep -E "^(NAME|CORE|ORIENT|GAMEID|GAMENAME|Exit code|Status)" "$REPORT" | sed 's/^/    /'
    echo ""
fi
echo "  ── Current Active INI Files ──"
echo -n "    Dolphin.ini  : "; grep -q "CPUCore = 4" "$CFG/Dolphin.ini" 2>/dev/null && echo "JITARM64 OK" || echo "UNKNOWN"
echo -n "    Overclock    : "; grep -E "^Overclock = " "$CFG/Dolphin.ini" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' '
echo -n "    Shader mode  : "; grep -E "^ShaderCompilationMode = " "$CFG/GFX.ini" 2>/dev/null | cut -d= -f2 | tr -d ' '
echo -n "    ShowFPS      : "; grep -E "^ShowFPS = " "$CFG/GFX.ini" 2>/dev/null | cut -d= -f2 | tr -d ' '
echo -n "    ShowVPS      : "; grep -E "^ShowVPS = " "$CFG/GFX.ini" 2>/dev/null | cut -d= -f2 | tr -d ' '
echo ""
echo "  ── Graphics Mods Active ──"
GM="/opt/muos/share/emulator/dolphin/Load/GraphicMods"
if [ -d "$GM" ]; then
    for d in "$GM"/*/; do
        [ -f "$d/.disabled" ] && continue
        echo "    ✓ $(basename "$d")"
    done
fi
echo ""
echo "  ── GameSettings Overrides ──"
GS="/opt/muos/share/emulator/dolphin/GameSettings"
[ -d "$GS" ] && ls -1 "$GS"/*.ini 2>/dev/null | while read f; do echo "    $(basename "$f")"; done
echo ""
echo "  Closing in 5 seconds..."
sleep 5
