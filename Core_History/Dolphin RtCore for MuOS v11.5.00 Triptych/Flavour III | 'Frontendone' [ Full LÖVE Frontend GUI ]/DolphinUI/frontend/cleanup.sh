#!/bin/bash
# frontend/cleanup.sh — remove dead files no longer referenced by main.lua.
# Run ONCE from frontend/ directory. Idempotent.
#
# Removed:
#   screens/enhancer.lua           superseded by ethostore.lua
#   screens/workshop_configs.lua   absorbed into workshop.lua
#   screens/workshop_advanced.lua  broken (missing "Disabled" hotkey profile)
#   theme_rtcore.lua               unreachable (THEME_ORDER = gc/wii)
#   update_checker.lua             inlined in main.lua

set -e
cd "$(dirname "$0")"

FILES=(
    "screens/enhancer.lua"
    "screens/workshop_configs.lua"
    "screens/workshop_advanced.lua"
    "theme_rtcore.lua"
    "update_checker.lua"
)

echo "DolphinUI — dead file cleanup"
echo "================================================"
for f in "${FILES[@]}"; do
    if [ -f "$f" ]; then
        echo "  rm  $f"
        rm -f "$f"
    else
        echo "  ok  $f (already gone)"
    fi
done
echo "================================================"
echo "Done."

# Optional: also clear stale lock/marker files from previous sessions
rm -f /tmp/dolphinui_dl_ready /tmp/dolphinui_dl_running 2>/dev/null || true
rm -f /tmp/dolphinui_dl.sh 2>/dev/null || true
echo "Cleared /tmp markers."