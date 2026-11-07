#!/usr/bin/env bash
# Dry-run tests for the Knulli (dolphin-rtcore-k) and ROCKNIX (dolphin-rtcore-r) ports on a fake device filesystem.
# No emulator is started: a stub "dolphin" and the launcher's RTCORE_DRYRUN mode are used.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; failn=0
ok()   { pass=$((pass+1)); echo "  ok   $*"; }
bad()  { failn=$((failn+1)); echo "  FAIL $*"; }
chk()  { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

make_release() {   # make_release <src dir> <dest>  -> copy + fake core/
  cp -a "$1" "$2"; mkdir -p "$2/core/Config"
  printf '#!/bin/sh\nexit 0\n' > "$2/core/dolphin"; chmod +x "$2/core/dolphin"
  for f in Dolphin.ini GFX.ini; do printf '[Core]\nSaveDir=/run/muos/storage/save/dolphin/\n' > "$2/core/Config/$f.default"; done
  printf '[Core]\nSaveDir=/run/muos/storage/save/dolphin/\nBIOS=/run/muos/storage/bios/dolphin/\n' > "$2/core/Config/Dolphin.ini.default"
  for p in GCPadNew.ini.2joy WiimoteNew.ini.2joy Hotkeys.ini; do printf '[Profile]\nDevice = SDL/0/Old\n' > "$2/core/Config/$p"; done
}
check_es_xml() {   # xml must parse and contain both systems with our command
  python3 - "$1" "$2" <<'PY'
import sys, xml.etree.ElementTree as ET
t = ET.parse(sys.argv[1]).getroot()
names = [s.findtext("name") for s in t.findall("system")]
assert names == ["wii", "gamecube"], names
for s in t.findall("system"):
    assert sys.argv[2] in s.findtext("command"), s.findtext("command")
    assert len(s.findall(".//core")) >= 10
print("xml ok")
PY
}

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

echo "== ROCKNIX port (dolphin-rtcore-r), fake /storage"
ST="$T/storage"; mkdir -p "$ST/.config/system/configs" "$ST/roms/wii" "$ST/roms/gamecube"
cat > "$ST/.config/system/configs/system.cfg" <<'CFG'
global.rtc_fps=on
wii["/x/Mario Kart Wii.rvz"].rtc_orient=sideways
wii["/x/Mario Kart Wii.rvz"].rtc_cheats=on
CFG
make_release "$REPO/dolphin-rtcore-r" "$T/r"
RTCORE_STORAGE="$ST" bash "$T/r/install.sh" --offline --no-restart >"$T/r_install.log" 2>&1; rc=$?
chk "installer exits 0" "[ $rc -eq 0 ]"
chk "ES systems file written in \$HOME/.emulationstation" "[ -f '$ST/.emulationstation/es_systems_rtcore.cfg' ]"
chk "no es_features file (this ES reads a single es_features.cfg)" "[ ! -e '$ST/.emulationstation/es_features_rtcore.cfg' ]"
chk "ES xml valid, 2 systems, command points to rtcore-r.sh" "check_es_xml '$ST/.emulationstation/es_systems_rtcore.cfg' rtcore-r.sh >/dev/null"
ROM="/x/Mario Kart Wii.rvz"; mkdir -p /x 2>/dev/null; touch "$ROM" 2>/dev/null || ROM="$T/Mario Kart Wii.rvz"
if [ "$ROM" = "$T/Mario Kart Wii.rvz" ]; then touch "$ROM"; sed -i "s#/x/Mario#$T/Mario#" "$ST/.config/system/configs/system.cfg"; fi
out="$(RTCORE_STORAGE="$ST" RTCORE_DRYRUN=1 bash "$T/r/bin/rtcore-r.sh" "$ROM" rtboost-std 2>&1)"
chk "launcher dry-run builds the dolphin command" "echo '$out' | grep -q 'cmd: .*dolphin -e'"
chk "per-game option read from system.cfg (sideways orientation)" "echo '$out' | grep -q 'sideways'"
chk "global option read (FPS on)" "echo '$out' | grep -q 'fps=on'"
chk "cheats per game on" "echo '$out' | grep -q 'EnableCheats=True'"
chk "muOS paths rewritten into the release folder" "grep -q \"SaveDir=$T/r/core\" '$T/r/core/Config/Dolphin.ini' || grep -q \"$T/r/core\" '$T/r/core/Config/Dolphin.ini'"

echo "== Knulli port (dolphin-rtcore-k), fake /userdata (regression)"
UDIR="$T/userdata"; mkdir -p "$UDIR/system" "$UDIR/roms/wii" "$UDIR/roms/gamecube"
printf 'global.rtc_fps=on\n' > "$UDIR/system/batocera.conf"
make_release "$REPO/dolphin-rtcore-k" "$T/k"
USERDATA="$UDIR" bash "$T/k/install.sh" --offline --no-restart --userdata "$UDIR" --no-theme >"$T/k_install.log" 2>&1; rc=$?
chk "installer exits 0" "[ $rc -eq 0 ]"
chk "ES xml valid, command points to rtcore-k.sh" "check_es_xml '$UDIR/system/configs/emulationstation/es_systems_rtcore.cfg' rtcore-k.sh >/dev/null"
touch "$T/Game.rvz"
out="$(USERDATA="$UDIR" RTCORE_DRYRUN=1 bash "$T/k/bin/rtcore-k.sh" "$T/Game.rvz" rtprime-std 2>&1)"
chk "launcher dry-run builds the dolphin command" "echo '$out' | grep -q 'cmd: .*dolphin -e'"
chk "global option read from batocera.conf" "echo '$out' | grep -q 'fps=on'"

echo "== release archive builder (fake aarch64 ELF, no real emulator needed)"
printf '\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\xb7\x00' > "$T/fake_dolphin"; printf '#!/bin/sh\n' >> "$T/fake_dolphin"
bash "$REPO/tools/make-port-release.sh" k --binary "$T/fake_dolphin" --out "$T/rel" >/dev/null 2>&1; rc=$?
chk "K archive built" "[ $rc -eq 0 ] && [ -f '$T/rel/Dolphin-RtCore-K_v'*'_emulators.tar.gz' ]"
mkdir -p "$T/x" && tar -xzf "$T"/rel/Dolphin-RtCore-K_v*_emulators.tar.gz -C "$T/x" 2>/dev/null
chk "archive has core/dolphin (executable) and the wrapper" "[ -x '$T/x/dolphin-rtcore-k/core/dolphin' ] && [ -x '$T/x/dolphin-rtcore-k.sh' ]"
chk "archive has no muOS tooling (RtSys) and no legacy-muos" "[ ! -e '$T/x/dolphin-rtcore-k/core/RtSys' ] && [ ! -e '$T/x/dolphin-rtcore-k/legacy-muos' ]"
chk "Wii 2joy profiles have balanced backticks" "! grep -E '^Nunchuk/Stick/' '$T/x/dolphin-rtcore-k/core/Config/WiimoteNew.ini.2joy' | awk '{c=gsub(/\`/,\"x\"); if (c%2) f=1} END{exit !f}'"
chk "every profile in cores.list has Dolphin.ini + GFX.ini" "for p in \$(grep -v '^#' '$REPO/dolphin-rtcore-k/config/cores.list' | awk '{print \$1}'); do [ -f '$T/x/dolphin-rtcore-k/core/Config/Dolphin.ini.'\$p ] && [ -f '$T/x/dolphin-rtcore-k/core/Config/GFX.ini.'\$p ] || exit 1; done"
printf 'not an elf' > "$T/notelf"; bash "$REPO/tools/make-port-release.sh" k --binary "$T/notelf" --out "$T/rel2" >/dev/null 2>&1
chk "a non-aarch64 file is refused" "[ \$? -ne 0 ]"

echo; echo "passed=$pass failed=$failn"; [ "$failn" -eq 0 ]
