#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI"
EMU="$ROOT/dolphin-rtcore-muos/emu/dolphin"
SW="$EMU/RtSys/switch_weapon"
fail() { printf '[FAIL] %s\\n' "$*" >&2; exit 1; }
ok() { printf '[OK] %s\\n' "$*"; }
need() { grep -Fq -- "$2" "$1" || fail "$1 is missing: $2"; }

for HK in "$APP/workshop/base/Hotkeys.ini" "$APP/workshop/hotkeys/Default/Hotkeys.ini"; do
    need "$HK" '[Hotkeys]'
    need "$HK" 'Device = SDL/0/Keyboard Mouse'
    need "$HK" 'General/Exit = Escape'
    need "$HK" 'Save State/Save State Slot 1 = F1'
    need "$HK" 'Load State/Load State Slot 1 = F2'
    ! grep -Fq '[Hotkeys1]' "$HK" || fail "legacy Hotkeys1 section is shipped: $HK"
    ! grep -Fq 'Keys/Exit' "$HK" || fail "legacy Keys/Exit action is shipped: $HK"
done
ok "Base and Default profiles use Dolphin 2606 [Hotkeys] action schema"

GPTK="$APP/workshop/hotkeys/Default/ext-dolphin.gptk"
need "$GPTK" '[controls]'
need "$GPTK" 'l2 = hold_state rt_hotkeys'
need "$GPTK" '[controls:rt_hotkeys]'
need "$GPTK" 'a = f1'
! grep -Fq 'select+start' "$GPTK" || fail "global shortcut must not replace Safe Exit"
WATCHER="$APP/scripts/overlay_exit.sh"
need "$WATCHER" 'COMBO=(8 9)'
need "$WATCHER" 'CONFIG="${RT_SAFE_EXIT_CONFIG:-$APP_DIR/data/safe_exit.conf}"'
need "$WATCHER" 'kill -TERM "$DOLPHIN_PID"'
ok "gptokeyb2 hotkeys and raw joydev Safe Exit remain independent"

for LAUNCHER in "$APP/scripts/launch.sh" "$ROOT/dolphin-rtcore-muos/overlay/opt/muos/script/launch/ext-dolphinrt.sh"; do
    need "$LAUNCHER" 'SDL/0/Keyboard Mouse'
    need "$LAUNCHER" '"$GPTK_BIN" -c "$GPTK_CFG" -D states,keyboard'
    ! grep -Fq '"$GPTK_BIN" -c "$GPTK_CFG" -1 dolphin' "$LAUNCHER" || fail "unexpected process target in $LAUNCHER"
done
ok "Both launch paths detect the Dolphin 2606 virtual-keyboard device"

for file in \
  "$EMU/Config/GCPadNew.ini" \
  "$APP/workshop/base/GCPadNew.ini" \
  "$APP/workshop/controller/GameCube/Default/GCPadNew.ini"; do
    need "$file" 'Device = SDL/0/muOS-Keys'
    need "$file" 'Buttons/Start = `Button 7`'
done
for file in \
  "$EMU/Config/WiimoteNew.ini" \
  "$APP/workshop/base/WiimoteNew.ini" \
  "$APP/workshop/controller/Wii/Default/WiimoteNew.ini"; do
    need "$file" 'Device = SDL/0/muOS-Keys'
    need "$file" 'Buttons/+ = `Button 7`'
done
ok "GameCube Start and Wii Plus use H700 button 7"
for mode in 1 2; do
    need "$SW/gc/mode $mode/global.ini" 'gamecube'
done
ok "GameCube alias is present in both profile modes"
