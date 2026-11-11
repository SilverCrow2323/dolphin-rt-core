#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI"
EMU="$ROOT/dolphin-rtcore-muos/emu/dolphin"
SW="$EMU/RtSys/switch_weapon"

fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok() { printf '[OK] %s\n' "$*"; }
need() { grep -Fq -- "$2" "$1" || fail "$1 is missing: $2"; }

# Dolphin 2606 uses the [Hotkeys] section with grouped action paths.
HK="$APP/workshop/hotkeys/Default/Hotkeys.ini"
need "$HK" '[Hotkeys]'
need "$HK" 'Device = SDL/0/Keyboard Mouse'
need "$HK" 'General/Exit = Escape'
need "$HK" 'Save State/Save State Slot 1 = F1'
need "$HK" 'Load State/Load State Slot 1 = F2'
! grep -Fq '[Hotkeys1]' "$HK" || fail "legacy Hotkeys1 section is still shipped"
! grep -Fq 'Keys/Exit' "$HK" || fail "legacy Keys/Exit action is still shipped"
ok "default hotkeys use Dolphin 2606 schema"

# The SELECT+START chord must be consistent between the gptk virtual-key
# binding and the Dolphin hotkey profile; the raw overlay watcher remains
# a separate safety path using the same H700 physical button numbers.
GPTK="$APP/workshop/hotkeys/Default/ext-dolphin.gptk"
need "$GPTK" 'select+start    = escape'
! grep -Eq '^select\+m[[:space:]]*=[[:space:]]*escape' "$GPTK" || fail "Exit is incorrectly bound to MENU instead of physical START"
need "$HK" 'General/Exit = Escape'
WATCHER="$APP/scripts/overlay_exit.sh"
need "$WATCHER" 'START_BTN=7'
need "$WATCHER" 'SELECT_BTN=6'
ok "SELECT+START exit chord matches H700 raw input schema"

# GameCube Start and Wii Plus both use H700 Start button 7 in Dolphin SDL.
for f in \
  "$EMU/Config/GCPadNew.ini" \
  "$APP/workshop/base/GCPadNew.ini" \
  "$APP/workshop/controller/GameCube/Default/GCPadNew.ini"; do
    need "$f" 'Device = SDL/0/muOS-Keys'
    need "$f" 'Buttons/Start = `Button 7`'
done
for f in \
  "$EMU/Config/WiimoteNew.ini" \
  "$APP/workshop/base/WiimoteNew.ini" \
  "$APP/workshop/controller/Wii/Default/WiimoteNew.ini"; do
    need "$f" 'Device = SDL/0/muOS-Keys'
    need "$f" 'Buttons/+ = `Button 7`'
done
ok "GameCube Start and Wii Plus use H700 button 7 in packaged and UI profiles"

# Native Content Explorer folder aliases are generated from both switch modes.
for mode in 1 2; do
    need "$SW/gc/mode $mode/global.ini" 'gamecube'
done
ok "GameCube alias is present in both manifest/profile modes"
