#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI"
EMU="$ROOT/dolphin-rtcore-muos/emu/dolphin"

fail() { echo "FAIL: $*" >&2; exit 1; }
ini_value() {
    local file="$1" section="$2" key="$3"
    awk -v section="$section" -v wanted="$key" '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }
        /^[[:space:]]*\[/ {
            current = trim($0)
            in_section = (current == "[" section "]")
            next
        }
        in_section {
            pos = index($0, "=")
            if (pos > 0) {
                name = trim(substr($0, 1, pos - 1))
                if (name == wanted) {
                    value = trim(substr($0, pos + 1))
                    sub(/[[:space:]]*[#;].*$/, "", value)
                    print trim(value)
                    exit
                }
            }
        }
    ' "$file"
}
expect() {
    local file="$1" section="$2" key="$3" expected="$4" actual pattern
    [ -f "$file" ] || fail "missing profile $file"
    actual="$(ini_value "$file" "$section" "$key")"
    case "$expected" in
        '`Button '*)
            pattern="(^|[( &])${expected}([ )&]|$)"
            printf '%s\n' "$actual" | grep -Eq "$pattern" ||
                fail "$file [$section] $key: expected positive binding $expected, got '${actual:-<missing>}'"
            ;;
        *)
            [ "$actual" = "$expected" ] ||
                fail "$file [$section] $key: expected '$expected', got '${actual:-<missing>}'"
            ;;
    esac
}

check_gc() {
    local f="$1"
    expect "$f" GCPad1 Device 'SDL/0/muOS-Keys'
    expect "$f" GCPad1 Buttons/A '`Button 1`'
    expect "$f" GCPad1 Buttons/B '`Button 0`'
    expect "$f" GCPad1 Buttons/Z '`Button 11`'
    expect "$f" GCPad1 Buttons/Start '`Button 7`'
    expect "$f" GCPad1 Triggers/L '`Button 4`'
    expect "$f" GCPad1 Triggers/L-Analog '`Button 9`'
    expect "$f" GCPad1 Triggers/R '`Button 5`'
    expect "$f" GCPad1 Triggers/R-Analog '`Button 12`'
}
check_wii() {
    local f="$1"
    expect "$f" Wiimote1 Device 'SDL/0/muOS-Keys'
    expect "$f" Wiimote1 Buttons/A '`Button 1`'
    expect "$f" Wiimote1 Buttons/B '`Button 0`'
    expect "$f" Wiimote1 Buttons/1 '`Button 2`'
    expect "$f" Wiimote1 Buttons/2 '`Button 3`'
    expect "$f" Wiimote1 Buttons/+ '`Button 7`'
    expect "$f" Wiimote1 Buttons/- '`Button 6`'
    expect "$f" Wiimote1 Buttons/Home '`Button 8`'
    if grep -q '^Nunchuk/Buttons/C[[:space:]]*=' "$f"; then
        expect "$f" Wiimote1 Nunchuk/Buttons/C '`Button 4`'
        expect "$f" Wiimote1 Nunchuk/Buttons/Z '`Button 5`'
    fi
}

gc_count=0
while IFS= read -r file; do
    check_gc "$file"
    gc_count=$((gc_count + 1))
done < <(find "$APP/workshop/controller/GameCube" -mindepth 2 -maxdepth 2 -type f -name GCPadNew.ini | sort)
[ "$gc_count" -ge 1 ] || fail "no bundled GameCube profiles found"

wii_count=0
while IFS= read -r file; do
    check_wii "$file"
    wii_count=$((wii_count + 1))
done < <(find "$APP/workshop/controller/Wii" -mindepth 2 -maxdepth 2 -type f -name WiimoteNew.ini | sort)
[ "$wii_count" -ge 1 ] || fail "no bundled Wii profiles found"

for file in \
    "$APP/workshop/base/GCPadNew.ini" \
    "$EMU/Config/GCPadNew.ini" \
    "$EMU/Config/GCPadNew.ini.2joy" \
    "$EMU/Config/GCPadNew.ini.default" \
    "$EMU/RtSys/factory/Config/GCPadNew.ini" \
    "$EMU/RtSys/factory/Config/GCPadNew.ini.2joy" \
    "$EMU/RtSys/factory/Config/GCPadNew.ini.default"; do
    check_gc "$file"
done
for file in \
    "$APP/workshop/base/WiimoteNew.ini" \
    "$EMU/Config/WiimoteNew.ini" \
    "$EMU/Config/WiimoteNew.ini.2joy" \
    "$EMU/Config/WiimoteNew.ini.default" \
    "$EMU/RtSys/factory/Config/WiimoteNew.ini" \
    "$EMU/RtSys/factory/Config/WiimoteNew.ini.2joy" \
    "$EMU/RtSys/factory/Config/WiimoteNew.ini.default"; do
    check_wii "$file"
done

echo "muOS Andromeda controller profiles: $gc_count GameCube and $wii_count Wii profiles verified"
