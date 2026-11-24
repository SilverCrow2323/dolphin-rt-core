#!/usr/bin/env bash
# Headless functional smoke for both controller GUIs.
# Uses synthetic ROM filenames and temporary user-data/config directories only.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/roms/gamecube" "$TMP/roms/wii"
mkdir -p "$TMP/userdata-knulli/system"
mkdir -p "$TMP/userdata-rocknix/.config/system/configs"
: > "$TMP/roms/gamecube/RtCore GUI Test [GZLE01].iso"
: > "$TMP/roms/wii/RtCore GUI Test [RMCE01].rvz"

run_smoke() {
  local platform="$1" port="$2" userdata="$3" conf="$4"
  local app="$ROOT/dolphin-rtcore-$port/ui/gui"
  echo "== Rt:UI $platform =="
  SDL_AUDIODRIVER=dummy   RTCORE_PORT_ROOT="$ROOT/dolphin-rtcore-$port"   RTCORE_PLATFORM="$platform"   RTCORE_USERDATA="$userdata"   RTCORE_ROM_ROOT="$TMP/roms"   RTCORE_CONF="$conf"     xvfb-run -a love "$app" --smoke
}

run_smoke knulli k "$TMP/userdata-knulli" "$TMP/userdata-knulli/system/batocera.conf"
run_smoke rocknix r "$TMP/userdata-rocknix" "$TMP/userdata-rocknix/.config/system/configs/system.cfg"

echo "RTUI_PORT_SMOKE_ALL_OK"
