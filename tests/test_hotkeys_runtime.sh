#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI/scripts/hotkeys_runtime.sh"
LAUNCH="$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI/scripts/launch.sh"
DEFAULT="$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI/workshop/hotkeys/Default/Hotkeys.ini"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# shellcheck source=/dev/null
. "$HELPER"

cat > "$TMP/keyboard.ini" <<'INI'
[Other]
Device = SDL/0/muOS-Keys
[Hotkeys]
Device = SDL/0/Keyboard Mouse # current Dolphin 2606 virtual keyboard
General/Exit = Escape
INI
cat > "$TMP/pad.ini" <<'INI'
[Hotkeys]
Device = SDL/0/muOS-Keys
General/Exit = (\`Button 6\` & \`Button 7\`)
INI
cat > "$TMP/missing.ini" <<'INI'
[Other]
Device = SDL/0/Keyboard Mouse
[Hotkeys]
General/Exit = Escape
INI
cat > "$TMP/mixed.ini" <<'INI'
[Hotkeys1]
Device = SDL/0/muOS-Keys
[Hotkeys]
Device = SDL/0/Keyboard Mouse
INI
cat > "$TMP/legacy.ini" <<'INI'
[Hotkeys1]
Device = Keyboard
Keys/Exit = \`Escape\`
INI

[ "$(hotkeys_device "$TMP/keyboard.ini")" = "SDL/0/Keyboard Mouse" ]
hotkeys_uses_keyboard "$TMP/keyboard.ini"
[ "$(hotkeys_device "$TMP/pad.ini")" = "SDL/0/muOS-Keys" ]
if hotkeys_uses_keyboard "$TMP/pad.ini"; then
    echo "FAIL: native SDL hotkeys must not start gptokeyb2" >&2
    exit 1
fi
if hotkeys_uses_keyboard "$TMP/missing.ini"; then
    echo "FAIL: a device outside [Hotkeys] must not be assumed to be keyboard" >&2
    exit 1
fi
[ "$(hotkeys_device "$TMP/mixed.ini")" = "SDL/0/Keyboard Mouse" ]
hotkeys_uses_keyboard "$TMP/mixed.ini"
[ "$(hotkeys_device "$TMP/legacy.ini")" = "Keyboard" ]
hotkeys_uses_keyboard "$TMP/legacy.ini"
hotkeys_uses_keyboard "$DEFAULT"

grep -Fq 'hotkeys_uses_keyboard "$CONFIG/Hotkeys.ini"' "$LAUNCH"
grep -Fq 'gptokeyb2 skipped: Hotkeys.ini uses native/non-keyboard device' "$LAUNCH"

bash -n "$HELPER" "$LAUNCH"
echo "muOS Dolphin 2606 hotkey runtime mode: all tests passed"
