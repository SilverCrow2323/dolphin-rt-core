#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/dolphin-rtcore-muos/overlay/opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh"
SOURCES="$ROOT/dolphin-rtcore-muos/emu/dolphin/RtSys/switch_weapon"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  [OK] %s\n' "$*"; }
check() {
    if "$@"; then ok "$1"; else fail=$((fail + 1)); printf '  [FAIL] %s\n' "$1"; fi
}

make_assign_stub() {
    root="$1"
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
    root="$1"
    store="$2"
    layout="$3"
    shift 3
    RT_MUOS_ROOT="$root" RT_MUOS_STORE_DIR="$store" RT_MUOS_ASSIGN_DIR="$root/share/info/assign" \
    RT_MUOS_MANIFEST_DIR="$root/share/info/manifest" RT_SWITCH_WEAPON_DIR="$SOURCES" \
    RT_MUOS_ASSIGN_REFRESH="$root/script/system/assign.sh" RT_TEST_REFRESH_LOG="$root/refresh.log" \
    sh "$TOOL" "$@"
}

# Andromeda: 2606.0 uses one user core.json and a regenerated assign.json.
A="$TMP/andromeda"
AS="$TMP/andromeda-store"
mkdir -p "$A/config/system" "$A/share/info/manifest" "$AS/info/manifest"
printf '2606.0_ANDROMEDA\n' > "$A/config/system/version"
cat > "$AS/info/manifest/core.json" <<'JSON'
{"Nintendo DS":{"name":"Nintendo DS","namespace":"Nintendo","catalogue":"Nintendo DS","default":"nds","friendly":["nds"],"bios":[],"external":{}},"Sony PlayStation":{"name":"Sony PlayStation","namespace":"Sony","catalogue":"Sony PlayStation","default":"pcsx","friendly":["ps"],"bios":[],"external":{}}}
JSON
make_assign_stub "$A"
RT_MUOS_ROOT="$A" RT_MUOS_STORE_DIR="$AS" RT_MUOS_ASSIGN_DIR="$A/share/info/assign" \
RT_MUOS_MANIFEST_DIR="$A/share/info/manifest" RT_SWITCH_WEAPON_DIR="$SOURCES" \
RT_MUOS_ASSIGN_REFRESH="$A/script/system/assign.sh" RT_TEST_REFRESH_LOG="$A/refresh.log" \
sh "$TOOL" apply 1
jq -e '.["Nintendo Gamecube"].namespace=="Nintendo" and .["Nintendo Wii"].namespace=="Nintendo" and has("Nintendo DS") and has("Sony PlayStation")' "$AS/info/manifest/core.json" >/dev/null
[ -s "$AS/info/manifest/core.json.rtcore.bak" ]
jq -e '.nintendogamecube=="Nintendo Gamecube" and .nintendowii=="Nintendo Wii"' "$AS/info/manifest/assign.json" >/dev/null
ok "Andromeda single manifest registers the Nintendo systems and preserves other systems"
[ "$(grep -c '^refresh$' "$A/refresh.log")" -eq 1 ]
ok "Andromeda automatic assignment refresh runs"
RT_MUOS_ROOT="$A" RT_MUOS_STORE_DIR="$AS" RT_MUOS_ASSIGN_DIR="$A/share/info/assign" \
RT_MUOS_MANIFEST_DIR="$A/share/info/manifest" RT_SWITCH_WEAPON_DIR="$SOURCES" \
RT_MUOS_ASSIGN_REFRESH="$A/script/system/assign.sh" RT_TEST_REFRESH_LOG="$A/refresh.log" \
sh "$TOOL" ensure
[ "$(grep -c '^refresh$' "$A/refresh.log")" -eq 1 ]
ok "Andromeda ensure is idempotent"

# Split-manifest generation: systems are written under core/Nintendo/*.json.
S="$TMP/split"
SS="$TMP/split-store"
mkdir -p "$S/config/system" "$S/share/info/manifest/core/Existing" "$SS/info/manifest"
printf '2612.0_SUPERNOVA\n' > "$S/config/system/version"
printf '{"catalogue":"Existing","lookup":0,"default":"default","friendly":["existing"],"bios":[],"external":{}}\n' > "$S/share/info/manifest/core/Existing/Existing.json"
make_assign_stub "$S"
RT_MUOS_ROOT="$S" RT_MUOS_STORE_DIR="$SS" RT_MUOS_ASSIGN_DIR="$S/share/info/assign" \
RT_MUOS_MANIFEST_DIR="$S/share/info/manifest" RT_SWITCH_WEAPON_DIR="$SOURCES" \
RT_MUOS_ASSIGN_REFRESH="$S/script/system/assign.sh" RT_TEST_REFRESH_LOG="$S/refresh.log" \
sh "$TOOL" apply 1
jq -e '(.catalogue=="Nintendo Gamecube") and (.external|length>0)' "$SS/info/manifest/core/Nintendo/Nintendo Gamecube.json" >/dev/null
jq -e '(.catalogue=="Nintendo Wii") and (.external|length>0)' "$SS/info/manifest/core/Nintendo/Nintendo Wii.json" >/dev/null
[ -f "$S/share/info/manifest/core/Existing/Existing.json" ]
ok "Split manifest stores both systems under the Nintendo namespace and preserves existing files"

# Jacaranda: legacy info/assign/*.ini format, with user files in the same folder preserved.
J="$TMP/jacaranda"
JS="$TMP/jacaranda-store"
mkdir -p "$J/config/system" "$J/share/info/assign/Nintendo Gamecube" "$JS"
printf '2601.1_JACARANDA\n' > "$J/config/system/version"
printf 'keep me\n' > "$J/share/info/assign/Nintendo Gamecube/user-note.txt"
RT_MUOS_ROOT="$J" RT_MUOS_STORE_DIR="$JS" RT_MUOS_ASSIGN_DIR="$J/share/info/assign" \
RT_MUOS_MANIFEST_DIR="$J/share/info/manifest" RT_SWITCH_WEAPON_DIR="$SOURCES" \
sh "$TOOL" apply 1
[ -s "$J/share/info/assign/Nintendo Gamecube/global.ini" ]
[ -s "$J/share/info/assign/Nintendo Wii/global.ini" ]
[ -s "$J/share/info/assign/Nintendo Gamecube/dolphin - rtprime - upright.ini" ]
grep -q 'keep me' "$J/share/info/assign/Nintendo Gamecube/user-note.txt"
ok "Jacaranda legacy assignment installs GameCube/Wii profiles without deleting unrelated files"
RT_MUOS_ROOT="$J" RT_MUOS_STORE_DIR="$JS" RT_MUOS_ASSIGN_DIR="$J/share/info/assign" \
RT_MUOS_MANIFEST_DIR="$J/share/info/manifest" RT_SWITCH_WEAPON_DIR="$SOURCES" \
sh "$TOOL" ensure
ok "Jacaranda ensure accepts an already-current legacy installation"
RT_MUOS_ROOT="$J" RT_MUOS_STORE_DIR="$JS" RT_MUOS_ASSIGN_DIR="$J/share/info/assign" \
RT_MUOS_MANIFEST_DIR="$J/share/info/manifest" RT_SWITCH_WEAPON_DIR="$SOURCES" \
sh "$TOOL" remove
[ ! -e "$J/share/info/assign/Nintendo Gamecube/dolphin - rtprime - upright.ini" ]
[ -f "$J/share/info/assign/Nintendo Gamecube/user-note.txt" ]
ok "Jacaranda remove cleans only Rt:Core profile files"

printf '\nmuOS registration tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
