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
wii["/x/Mario Kart Wii.rvz"].rtc_res=2
wii["/x/Mario Kart Wii.rvz"].rtc_oc=0.75
wii["/x/Mario Kart Wii.rvz"].rtc_msaa=4;touch /tmp/PWNED_OPT
wii["/x/Mario Kart Wii.rvz"].rtc_vsync=on
global.rtc_vol=50
CFG
make_release "$REPO/dolphin-rtcore-r" "$T/r"
RTCORE_STORAGE="$ST" bash "$T/r/install.sh" --offline --no-restart >"$T/r_install.log" 2>&1; rc=$?
chk "installer exits 0" "[ $rc -eq 0 ]"
chk "ES systems file written in \$HOME/.emulationstation" "[ -f '$ST/.emulationstation/es_systems_rtcore.cfg' ]"
chk "option menu merged into the user es_features.cfg (this ES reads a single file)" "grep -q 'RTCORE-R BEGIN' '$ST/.emulationstation/es_features.cfg'"
python3 - "$ST/.emulationstation/es_features.cfg" <<'PY' && ok "features XML: emulator rtcore-r, 24 options in 6 submenus, every option has >=2 choices" || bad "features XML structure"
import sys, xml.etree.ElementTree as ET
r = ET.parse(sys.argv[1]).getroot(); e = [x for x in r.findall("emulator") if x.get("name") == "rtcore-r"]
assert len(e) == 1; f = e[0].findall("feature")
assert len(f) == 24 and len({x.get("value") for x in f}) == 24
assert {x.get("submenu") for x in f} == {"GAME","CONTROLS","GRAPHICS","PERFORMANCE","AUDIO","SYSTEM"}
assert all(len(x.findall("choice")) >= 2 and x.get("name") and x.get("description") for x in f)
PY
bash "$T/r/tools/es-features.sh" install "$ST/.emulationstation" >/dev/null 2>&1
chk "installing twice keeps exactly one block (idempotent)" "[ \$(grep -c 'RTCORE-R BEGIN' '$ST/.emulationstation/es_features.cfg') -eq 1 ]"
chk "ES xml valid, 2 systems, command points to rtcore-r.sh" "check_es_xml '$ST/.emulationstation/es_systems_rtcore.cfg' rtcore-r.sh >/dev/null"
ROM="/x/Mario Kart Wii.rvz"; mkdir -p /x 2>/dev/null; touch "$ROM" 2>/dev/null || ROM="$T/Mario Kart Wii.rvz"
if [ "$ROM" = "$T/Mario Kart Wii.rvz" ]; then touch "$ROM"; sed -i "s#/x/Mario#$T/Mario#" "$ST/.config/system/configs/system.cfg"; fi
out="$(RTCORE_STORAGE="$ST" RTCORE_DRYRUN=1 bash "$T/r/bin/rtcore-r.sh" "$ROM" rtboost-std 2>&1)"
chk "launcher dry-run builds the dolphin command" "echo '$out' | grep -q 'cmd: .*dolphin -e'"
chk "per-game option read from system.cfg (sideways orientation)" "echo '$out' | grep -q 'sideways'"
chk "generic option: internal resolution 2x" "echo '$out' | grep -q -e '-C GFX.Settings.InternalResolution=2' || echo '$out' | grep -q 'GFX.Settings.InternalResolution=2'"
chk "generic option: CPU clock 0.75x sets both keys" "echo '$out' | grep -q 'Dolphin.Core.OverclockEnable=True' && echo '$out' | grep -q 'Dolphin.Core.Overclock=0.75'"
chk "generic option: V-Sync on" "echo '$out' | grep -q 'GFX.Hardware.VSync=True'"
chk "global option applies to every game (volume 50)" "echo '$out' | grep -q 'Dolphin.DSP.Volume=50'"
chk "a hostile option value is ignored and runs nothing" "! echo '$out' | grep -q 'MSAA' && [ ! -e /tmp/PWNED_OPT ]"
chk "options left on 'auto' add no override (anisotropic)" "! echo '$out' | grep -q 'MaxAnisotropy'"
chk "global option read (FPS on)" "echo '$out' | grep -q 'fps=on'"
chk "cheats per game on" "echo '$out' | grep -q 'EnableCheats=True'"
chk "muOS paths rewritten into the release folder" "grep -q \"SaveDir=$T/r/core\" '$T/r/core/Config/Dolphin.ini' || grep -q \"$T/r/core\" '$T/r/core/Config/Dolphin.ini'"

echo "== ROCKNIX: window platform is chosen from what the binary was built with"
printf '#!/bin/sh\n# PlatformWaylandE PlatformFBDevE\n' > "$T/r/core/dolphin"; chmod +x "$T/r/core/dolphin"
: > "$T/empty.cfg"
o1="$(WAYLAND_DISPLAY=wayland-1 RTCORE_STORAGE="$ST" RTCORE_CONF="$T/empty.cfg" RTCORE_DRYRUN=1 bash "$T/r/bin/rtcore-r.sh" "$ROM" default 2>&1)"
chk "wayland-capable build + a compositor -> --platform=wayland" "echo '$o1' | grep -q -e '--platform=wayland'"
o2="$(env -u WAYLAND_DISPLAY -u DISPLAY RTCORE_STORAGE="$ST" RTCORE_CONF="$T/empty.cfg" RTCORE_DRYRUN=1 bash "$T/r/bin/rtcore-r.sh" "$ROM" default 2>&1)"
chk "no compositor -> no --platform (keeps the build's default)" "! echo '$o2' | grep -q -e '--platform'"
printf '#!/bin/sh\n# PlatformFBDevE only\n' > "$T/r/core/dolphin"
o3="$(WAYLAND_DISPLAY=wayland-1 RTCORE_STORAGE="$ST" RTCORE_CONF="$T/empty.cfg" RTCORE_DRYRUN=1 bash "$T/r/bin/rtcore-r.sh" "$ROM" default 2>&1)"
chk "fbdev-only build (the muOS/Knulli binary) is never told to use wayland" "! echo '$o3' | grep -q -e '--platform=wayland'"
printf 'wii["%s"].rtc_platform=x11\n' "$ROM" > "$T/force.cfg"
o4="$(RTCORE_STORAGE="$ST" RTCORE_CONF="$T/force.cfg" RTCORE_DRYRUN=1 bash "$T/r/bin/rtcore-r.sh" "$ROM" default 2>&1)"
chk "the per-game option can force a platform" "echo '$o4' | grep -q -e '--platform=x11'"

echo "== ROCKNIX: a pre-existing user es_features.cfg is preserved and uninstall restores it"
ST2="$T/storage2"; mkdir -p "$ST2/.config/system/configs" "$ST2/roms/wii" "$ST2/roms/gamecube" "$ST2/.emulationstation"
printf '<?xml version="1.0"?>\n<features>\n  <emulator name="other"><feature name="X" value="x"><choice name="a" value="a"/></feature></emulator>\n</features>\n' > "$ST2/.emulationstation/es_features.cfg"
cp "$ST2/.emulationstation/es_features.cfg" "$T/features.orig"
RTCORE_STORAGE="$ST2" bash "$T/r/install.sh" --offline --no-restart >/dev/null 2>&1
chk "other emulators' features are kept" "grep -q 'name=\"other\"' '$ST2/.emulationstation/es_features.cfg' && grep -q 'rtcore-r' '$ST2/.emulationstation/es_features.cfg'"
chk "a one-time backup of the original exists" "cmp -s '$ST2/.emulationstation/es_features.cfg.rtcore.bak' '$T/features.orig'"
bash "$T/r/uninstall.sh" --es-dir "$ST2/.emulationstation" >/dev/null 2>&1
chk "uninstall restores the user's file exactly" "diff <(grep -v '^\$' '$ST2/.emulationstation/es_features.cfg') <(grep -v '^\$' '$T/features.orig') >/dev/null"
chk "uninstall removes the systems file" "[ ! -e '$ST2/.emulationstation/es_systems_rtcore.cfg' ]"
echo "== ROCKNIX: doctor explains a missing/foreign binary"
dout="$(cd "$T/r" && RTCORE_STORAGE="$ST" bash rtcore.sh doctor 2>&1)"; drc=$?
chk "doctor runs and reports a verdict" "echo '$dout' | grep -q '== verdict'"

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
