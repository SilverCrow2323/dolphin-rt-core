#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/dolphin-rtcore-muos/overlay/opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh"
SOURCES="$ROOT/dolphin-rtcore-muos/emu/dolphin/RtSys/switch_weapon"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ok() { printf '  [OK] %s\n' "$*"; }

make_assign_stub() {
    local root="$1"
    mkdir -p "$root/script/system"
    cat > "$root/script/system/assign.sh" <<'STUB'
#!/bin/sh
set -eu
manifest="$RT_MUOS_STORE_DIR/info/manifest"
mkdir -p "$manifest"
pairs="$(mktemp)"
trap 'rm -f "$pairs"' EXIT
if [ -r "$manifest/core.json" ]; then
    jq -r 'to_entries[] | . as $system | (.value.friendly // [])[] | [., $system.key] | @tsv' "$manifest/core.json" >> "$pairs"
fi
if [ -d "$manifest/core" ]; then
    find "$manifest/core" -type f -name '*.json' -print | LC_ALL=C sort | while IFS= read -r file; do
        key="$(basename "$file" .json)"
        jq -r --arg key "$key" '(.friendly // [])[] | [., $key] | @tsv' "$file"
    done >> "$pairs"
fi
jq -Rn '[inputs | split("\t")] as $pairs | reduce $pairs[] as $pair ({}; .[$pair[0]] = $pair[1])' < "$pairs" > "$manifest/assign.json"
echo refresh >> "$RT_TEST_REFRESH_LOG"
STUB
    chmod 755 "$root/script/system/assign.sh"
}

run_tool() {
    local root="$1" store="$2" source="$3"
    shift 3
    RT_MUOS_ROOT="$root" RT_MUOS_STORE_DIR="$store" RT_MUOS_ASSIGN_DIR="$root/share/info/assign" RT_MUOS_MANIFEST_DIR="$root/share/info/manifest" RT_SWITCH_WEAPON_DIR="$source" RT_MUOS_ASSIGN_REFRESH="$root/script/system/assign.sh" RT_TEST_REFRESH_LOG="$root/refresh.log" sh "$TOOL" "$@"
}

# Andromeda 2606.0: single user core.json + muOS-generated assign.json.
A="$TMP/andromeda"
AS="$TMP/andromeda-store"
mkdir -p "$A/config/system" "$A/share/info/manifest" "$AS/info/manifest"
printf '2606.0_ANDROMEDA\n' > "$A/config/system/version"
cat > "$AS/info/manifest/core.json" <<'JSON'
{"Nintendo DS":{"name":"Nintendo DS","namespace":"Nintendo","catalogue":"Nintendo DS","default":"nds","friendly":["nds"],"bios":[],"external":{}},"Sony PlayStation":{"name":"Sony PlayStation","namespace":"Sony","catalogue":"Sony PlayStation","default":"pcsx","friendly":["ps"],"bios":[],"external":{}}}
JSON
make_assign_stub "$A"
run_tool "$A" "$AS" "$SOURCES" apply 1
jq -e '.["Nintendo Gamecube"].namespace=="Nintendo" and .["Nintendo Wii"].namespace=="Nintendo" and has("Nintendo DS") and has("Sony PlayStation")' "$AS/info/manifest/core.json" >/dev/null
[ -s "$AS/info/manifest/core.json.rtcore.bak" ]
jq -e '.nintendogamecube=="Nintendo Gamecube" and .nintendowii=="Nintendo Wii" and .gamecube=="Nintendo Gamecube" and .gamecubez=="Nintendo Gamecube" and .wii=="Nintendo Wii" and .wiiz=="Nintendo Wii"' "$AS/info/manifest/assign.json" >/dev/null
for mode in 1 2; do
    for alias in nintendogamecube nintendogc gamecube gamecubez ngc gc; do
        grep -Fxq "$alias" "$SOURCES/gc/mode $mode/global.ini"
    done
    for alias in nintendowii nwii wii wiiz; do
        grep -Fxq "$alias" "$SOURCES/wii/mode $mode/global.ini"
    done
done
[ "$(grep -c '^refresh$' "$A/refresh.log")" -eq 1 ]
ok "Andromeda registers built-in aliases and preserves existing systems"

run_tool "$A" "$AS" "$SOURCES" alias-add gc rtgamecubez
run_tool "$A" "$AS" "$SOURCES" alias-add wii rtwiiz
jq -e '.rtgamecubez=="Nintendo Gamecube" and .rtwiiz=="Nintendo Wii"' "$AS/info/manifest/assign.json" >/dev/null
[ -s "$AS/info/manifest/rtcore-folder-aliases-gc.txt" ]
[ -s "$AS/info/manifest/rtcore-folder-aliases-wii.txt" ]
[ "$(grep -c '^refresh$' "$A/refresh.log")" -eq 3 ]
ok "Andromeda persists custom folder aliases and regenerates assign.json"

run_tool "$A" "$AS" "$SOURCES" ensure
[ "$(grep -c '^refresh$' "$A/refresh.log")" -eq 3 ]
ok "Andromeda ensure is idempotent with custom aliases"

BROKEN="$TMP/broken-sources"
cp -a "$SOURCES" "$BROKEN"
rm -f "$BROKEN/gc/mode 1/global.ini" "$BROKEN/wii/mode 1/global.ini"
run_tool "$A" "$AS" "$BROKEN" remove
jq -e 'has("Nintendo Gamecube")|not' "$AS/info/manifest/core.json" >/dev/null
jq -e 'has("Nintendo Wii")|not' "$AS/info/manifest/core.json" >/dev/null
jq -e 'has("Nintendo DS") and has("Sony PlayStation")' "$AS/info/manifest/core.json" >/dev/null
jq -e '((has("nintendogamecube")|not) and (has("nintendogc")|not) and (has("gamecube")|not) and (has("gamecubez")|not) and (has("ngc")|not) and (has("gc")|not) and (has("nintendowii")|not) and (has("nwii")|not) and (has("wii")|not) and (has("wiiz")|not) and (has("rtgamecubez")|not) and (has("rtwiiz")|not))' "$AS/info/manifest/assign.json" >/dev/null
[ ! -e "$AS/info/manifest/rtcore-folder-aliases-gc.txt" ]
[ ! -e "$AS/info/manifest/rtcore-folder-aliases-wii.txt" ]
[ "$(grep -c '^refresh$' "$A/refresh.log")" -eq 4 ]
ok "Andromeda remove cleans Rt:Core aliases and preserves unrelated systems"

cat > "$A/share/info/manifest/core.json" <<'JSON'
{"Nintendo DS":{"name":"Nintendo DS","namespace":"Nintendo","catalogue":"Nintendo DS","default":"nds","friendly":["nds"],"bios":[],"external":{}}}
JSON
rm -f "$AS/info/manifest/core.json"
run_tool "$A" "$AS" "$BROKEN" remove
jq -e '((has("nintendogamecube")|not) and (has("nintendowii")|not))' "$AS/info/manifest/assign.json" >/dev/null
ok "Andromeda remove refreshes the assignment map when user core.json is already absent"

# Split-manifest API: core/<Namespace>/<System>.json.
S="$TMP/split"
SS="$TMP/split-store"
mkdir -p "$S/config/system" "$S/share/info/manifest/core/Existing" "$SS/info/manifest"
printf '2612.0_SUPERNOVA\n' > "$S/config/system/version"
printf '{"catalogue":"Existing","lookup":0,"default":"default","friendly":["existing"],"bios":[],"external":{}}\n' > "$S/share/info/manifest/core/Existing/Existing.json"
make_assign_stub "$S"
run_tool "$S" "$SS" "$SOURCES" apply 1
jq -e '(.catalogue=="Nintendo Gamecube") and (.external|length>0)' "$SS/info/manifest/core/Nintendo/Nintendo Gamecube.json" >/dev/null
jq -e '(.catalogue=="Nintendo Wii") and (.external|length>0)' "$SS/info/manifest/core/Nintendo/Nintendo Wii.json" >/dev/null
[ -f "$S/share/info/manifest/core/Existing/Existing.json" ]
ok "Split manifest writes both Nintendo systems and preserves existing files"
run_tool "$S" "$SS" "$SOURCES" remove
[ ! -e "$SS/info/manifest/core/Nintendo/Nintendo Gamecube.json" ]
[ ! -e "$SS/info/manifest/core/Nintendo/Nintendo Wii.json" ]
[ -f "$S/share/info/manifest/core/Existing/Existing.json" ]
jq -e '((has("nintendogamecube")|not) and (has("nintendowii")|not))' "$SS/info/manifest/assign.json" >/dev/null
ok "Split manifest remove cleans only GameCube/Wii"

# Jacaranda: legacy info/assign/<System>/*.ini, preserving unrelated files.
J="$TMP/jacaranda"
JS="$TMP/jacaranda-store"
mkdir -p "$J/config/system" "$J/share/info/assign/Nintendo Gamecube" "$JS"
printf '2601.1_JACARANDA\n' > "$J/config/system/version"
printf 'keep me\n' > "$J/share/info/assign/Nintendo Gamecube/user-note.txt"
run_tool "$J" "$JS" "$SOURCES" apply 1
[ -s "$J/share/info/assign/Nintendo Gamecube/global.ini" ]
[ -s "$J/share/info/assign/Nintendo Wii/global.ini" ]
[ -s "$J/share/info/assign/Nintendo Gamecube/dolphin - rtprime - upright.ini" ]
[ -s "$J/share/info/assign/Nintendo Wii/dolphin - rtprime - upright.ini" ]
for alias in nintendogamecube nintendogc gamecube gamecubez ngc gc; do
    grep -Fxq "$alias" "$J/share/info/assign/Nintendo Gamecube/global.ini"
done
for alias in nintendowii nwii wii wiiz; do
    grep -Fxq "$alias" "$J/share/info/assign/Nintendo Wii/global.ini"
done
grep -q 'keep me' "$J/share/info/assign/Nintendo Gamecube/user-note.txt"
ok "Jacaranda installs legacy assignments without deleting unrelated files"

run_tool "$J" "$JS" "$SOURCES" alias-add gc rtgamecubez
run_tool "$J" "$JS" "$SOURCES" alias-add wii rtwiiz
grep -Fxq 'rtgamecubez' "$J/share/info/assign/Nintendo Gamecube/global.ini"
grep -Fxq 'rtwiiz' "$J/share/info/assign/Nintendo Wii/global.ini"
[ -s "$JS/info/manifest/rtcore-folder-aliases-gc.txt" ]
[ -s "$JS/info/manifest/rtcore-folder-aliases-wii.txt" ]
ok "Jacaranda adds persistent custom aliases to both legacy systems"

run_tool "$J" "$JS" "$SOURCES" ensure
ok "Jacaranda ensure accepts an already-current legacy installation"
run_tool "$J" "$JS" "$SOURCES" remove
[ ! -e "$J/share/info/assign/Nintendo Gamecube/dolphin - rtprime - upright.ini" ]
[ -f "$J/share/info/assign/Nintendo Gamecube/user-note.txt" ]
[ ! -e "$JS/info/manifest/rtcore-folder-aliases-gc.txt" ]
[ ! -e "$JS/info/manifest/rtcore-folder-aliases-wii.txt" ]
ok "Jacaranda remove cleans Rt:Core profiles while preserving unrelated files"

printf '\nmuOS registration tests: passed\n'
