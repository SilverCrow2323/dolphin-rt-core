#!/bin/bash
# Dolphin Rt:Core R — persistent Art Book Next logo integration for ROCKNIX.
# ROCKNIX's supported customization path survives firmware/theme updates.
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
LOGOS="$ROOT/theme/logos"
MANIFEST="$ROOT/.theme_installed"
USERDATA=""
UNINSTALL=0
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --userdata) USERDATA="$2"; shift 2;;
    --uninstall) UNINSTALL=1; shift;;
    --dry-run) DRY=1; shift;;
    *) echo "[rtcore-r-theme] unknown option: $1" >&2; exit 2;;
  esac
done

if [ "$UNINSTALL" = 1 ]; then
  [ -f "$MANIFEST" ] || { echo "[rtcore-r-theme] nothing to remove"; exit 0; }
  while IFS= read -r dest; do
    [ -n "$dest" ] || continue
    rm -f "$dest"
    [ -f "$dest.rtcore.bak" ] && mv -f "$dest.rtcore.bak" "$dest"
    echo "[rtcore-r-theme] restored $dest"
  done < "$MANIFEST"
  rm -f "$MANIFEST"
  exit 0
fi

[ -n "$USERDATA" ] && [ -d "$USERDATA" ] || { echo "Usage: install-theme.sh --userdata /storage [--dry-run]" >&2; exit 2; }
CUSTOM_LOGOS="$USERDATA/roms/rocknix/theme-customizations/art-book-next/logos"
if [ "$DRY" = 1 ]; then
  echo "[dry-run] install GameCube and Wii logos into $CUSTOM_LOGOS"
  echo "[dry-run] in UI Settings > Theme Configuration, keep Distribution=ROCKNIX and set Color Scheme=Custom"
  exit 0
fi
mkdir -p "$CUSTOM_LOGOS"
: > "$MANIFEST"
for system in wii gamecube; do
  src="$LOGOS/$system.svg"
  dst="$CUSTOM_LOGOS/$system.svg"
  [ -s "$src" ] || { echo "[rtcore-r-theme] missing logo: $src" >&2; exit 1; }
  [ -f "$dst" ] && [ ! -f "$dst.rtcore.bak" ] && cp -p "$dst" "$dst.rtcore.bak"
  cp -f "$src" "$dst"
  echo "$dst" >> "$MANIFEST"
  echo "[rtcore-r-theme] installed $dst"
done
echo "[rtcore-r-theme] logos copied. In EmulationStation set UI Settings > Theme Configuration > Distribution=ROCKNIX and Color Scheme=Custom."
