#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
. "$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI/scripts/ce_shared_profile_runtime.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PROFILES="$TMP/workshop/rtcoreprofile"
mkdir -p "$PROFILES/Default" "$PROFILES/RtPrime/lite" "$PROFILES/RtPrime/std" "$PROFILES/RtPrime/max" \
    "$PROFILES/Black Screen Fix" "$PROFILES/Custom_Test"

rt_resolve_ce_core "ext-dolphin-rtprime-lite-upright" "$PROFILES"
[[ "$RT_PROFILE" == "RtPrime" && "$RT_VARIANT" == "lite" && "$RT_ORIENT" == "upright" ]]
rt_resolve_ce_core "ext-dolphin-rtprime-sideways" "$PROFILES"
[[ "$RT_PROFILE" == "RtPrime" && "$RT_VARIANT" == "std" && "$RT_ORIENT" == "sideways" ]]
rt_resolve_ce_core "ext-dolphin-blackscreenfix-upright" "$PROFILES"
[[ "$RT_PROFILE" == "Black Screen Fix" && -z "$RT_VARIANT" ]]
rt_resolve_ce_core "ext-dolphin-unknown-upright" "$PROFILES"
[[ "$RT_PROFILE" == "Default" ]]

CARD="$TMP/rtid_GM8E01.ini"
cat > "$CARD" <<'INI'
[Meta]
Name = Example game

[LAUNCH]
RtProfile = Custom_Test
RtProfileVariant = max
Controller = Arcade
Hotkeys = Disabled
GameSettings = Performance.ini
Logger = Verbose
Cheats = yes
Mods = yes
OverlayFPS = yes
OverlayVPS = no
OverlaySpeed = yes
OverlayOSD = no
INI
[[ "$(rt_read_rtid_launch "$CARD" RtProfile)" == "Custom_Test" ]]
[[ "$(rt_read_rtid_launch "$CARD" Controller)" == "Arcade" ]]
[[ "$(rt_read_rtid_launch "$CARD" Mods)" == "yes" ]]
[[ -z "$(rt_read_rtid_launch "$CARD" Unknown)" ]]
rt_safe_profile_name "Custom_Test"
rt_safe_profile_name "Black Screen Fix"
! rt_safe_profile_name "../escape"
! rt_safe_profile_name "folder/name"
rt_safe_leaf_name "Performance.ini"
! rt_safe_leaf_name "../outside.ini"
rt_safe_game_id "GM8E01"
! rt_safe_game_id "../escape"

# ActiveConfig is the shared, canonical GameSettings selector.
GSROOT="$TMP/workshop/gamesettings"
mkdir -p "$GSROOT/GM8E01"
cat > "$GSROOT/GM8E01/Performance.ini" <<'INI'
[Core]
CPUThread = True
INI
cat > "$GSROOT/GM8E01/Arcade.ini" <<'INI'
[Core]
Overclock = 0.9
INI
cat > "$GSROOT/GM8E01/rtgameset_data.ini" <<'INI'
[Cheats]
Enabled = yes

[GameSettings]
ActiveConfig = Performance.ini
INI
[[ "$(rt_read_active_gameset "GM8E01" "$GSROOT")" == "Performance.ini" ]]

rt_write_active_gameset "GM8E01" "$GSROOT" "Arcade.ini"
[[ "$(rt_read_active_gameset "GM8E01" "$GSROOT")" == "Arcade.ini" ]]
grep -q '^Enabled = yes$' "$GSROOT/GM8E01/rtgameset_data.ini"

# Dolphin's per-game GameINI lives in the user root, beside Config/.
RUNTIME="$TMP/emu/GameSettings"
PROJECTOR="$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI/tools/project_gamesettings.py"
rt_project_active_gameset "GM8E01" "$GSROOT" "$RUNTIME" "" "$PROJECTOR"
[[ "$RT_ACTIVE_GAMESET" == "Arcade.ini" ]]
grep -q '^Overclock = 0.9$' "$RUNTIME/GM8E01.ini"

# Replace non-cheat runtime values with the selected Workshop preset, while
# preserving Rt-generated and handwritten Gecko/ActionReplay blocks.
cat >> "$RUNTIME/GM8E01.ini" <<'INI'

[Gecko]
$[Rt] Speed Patch
04000000 12345678
$Manual Runtime Cheat
87654321 00000001

[Gecko_Enabled]
$[Rt] Speed Patch
INI
rt_project_active_gameset "GM8E01" "$GSROOT" "$RUNTIME" "Performance.ini" "$PROJECTOR"
[[ "$RT_ACTIVE_GAMESET" == "Performance.ini" ]]
grep -q '^CPUThread = True$' "$RUNTIME/GM8E01.ini"
! grep -q '^Overclock = 0.9$' "$RUNTIME/GM8E01.ini"
grep -q '^\$\[Rt\] Speed Patch$' "$RUNTIME/GM8E01.ini"
grep -q '^04000000 12345678$' "$RUNTIME/GM8E01.ini"
grep -q '^\$Manual Runtime Cheat$' "$RUNTIME/GM8E01.ini"
[[ "$(rt_read_active_gameset "GM8E01" "$GSROOT")" == "Performance.ini" ]]
grep -q '^Enabled = yes$' "$GSROOT/GM8E01/rtgameset_data.ini"

# Disabled removes the selected preset but leaves only the per-game cheat blocks.
rt_project_active_gameset "GM8E01" "$GSROOT" "$RUNTIME" "Disabled" "$PROJECTOR"
[[ -e "$RUNTIME/GM8E01.ini" ]]
grep -q '^\$\[Rt\] Speed Patch$' "$RUNTIME/GM8E01.ini"
grep -q '^\$Manual Runtime Cheat$' "$RUNTIME/GM8E01.ini"
! grep -q '^CPUThread = ' "$RUNTIME/GM8E01.ini"
! grep -q '^Overclock = ' "$RUNTIME/GM8E01.ini"
[[ -z "$(rt_read_active_gameset "GM8E01" "$GSROOT" || true)" ]]
grep -q '^Enabled = yes$' "$GSROOT/GM8E01/rtgameset_data.ini"

# Invalid/traversal ActiveConfig values never resolve outside the GameID folder.
cat > "$GSROOT/GM8E01/rtgameset_data.ini" <<'INI'
[GameSettings]
ActiveConfig = ../outside.ini
INI
! rt_read_active_gameset "GM8E01" "$GSROOT"
! rt_write_active_gameset "GM8E01" "$GSROOT" "../outside.ini"

# Disc ID extraction: raw ISO, WBFS, RVZ, CISO and filename-tagged GCZ.
printf 'GM8E01' > "$TMP/test.iso"
[[ "$(rt_extract_game_id "$TMP/test.iso")" == "GM8E01" ]]

python3 - "$TMP/test.wbfs" "$TMP/test.rvz" "$TMP/test.ciso" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(b"WBFS" + bytes(512 - 4) + b"RMCE01")
Path(sys.argv[2]).write_bytes(b"RVZ\x01" + bytes(0x58 - 4) + b"RMCE01")
Path(sys.argv[3]).write_bytes(b"CISO" + bytes(0x8000 - 4) + b"RMCE01")
PY
[[ "$(rt_extract_game_id "$TMP/test.wbfs")" == "RMCE01" ]]
[[ "$(rt_extract_game_id "$TMP/test.rvz")" == "RMCE01" ]]
[[ "$(rt_extract_game_id "$TMP/test.ciso")" == "RMCE01" ]]
touch "$TMP/packed [GM8E01].gcz"
[[ "$(rt_extract_game_id "$TMP/packed [GM8E01].gcz")" == "GM8E01" ]]

echo "Content Explorer shared-profile runtime tests: OK"
