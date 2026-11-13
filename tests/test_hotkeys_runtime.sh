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
[Hotkeys1]
Device = Keyboard # keyboard mode
Keys/Exit = `Escape`
INI
cat > "$TMP/pad.ini" <<'INI'
[Hotkeys1]
Device = SDL/0/muOS-Keys
Keys/Exit = `Button 6` & `Button 7`
INI
cat > "$TMP/missing.ini" <<'INI'
[Other]
Device = Keyboard
[Hotkeys1]
Keys/Exit = `Escape`
INI

[ "$(hotkeys_device "$TMP/keyboard.ini")" = "Keyboard" ]
hotkeys_uses_keyboard "$TMP/keyboard.ini"
[ "$(hotkeys_device "$TMP/pad.ini")" = "SDL/0/muOS-Keys" ]
if hotkeys_uses_keyboard "$TMP/pad.ini"; then
    echo "FAIL: SDL hotkeys must not start gptokeyb2" >&2
    exit 1
fi
if hotkeys_uses_keyboard "$TMP/missing.ini"; then
    echo "FAIL: missing Hotkeys1 Device must not be assumed to be Keyboard" >&2
    exit 1
fi
hotkeys_uses_keyboard "$DEFAULT"

grep -Fq 'hotkeys_uses_keyboard "$CONFIG/Hotkeys.ini"' "$LAUNCH"
grep -Fq 'gptokeyb2 skipped: Hotkeys.ini uses native/non-keyboard device' "$LAUNCH"

bash -n "$HELPER" "$LAUNCH"
echo "muOS hotkey runtime mode: all tests passed"
