#!/usr/bin/env bash
# Builds a ready-to-install archive of a port (Knulli "k" or ROCKNIX "r") that includes core/:
#   core/ = the shared emulator tree (Config, Load, Sys, GC, Wii; no GameSettings or texture packs)
#           + YOUR aarch64 dolphin binary. RtSys/ is muOS tooling and is left out.
#
#   tools/make-port-release.sh k --binary /path/to/dolphin [--sys-dir /path/to/Sys] [--out DIR]
#   tools/make-port-release.sh r --binary /path/to/dolphin [--sys-dir /path/to/Sys] [--out DIR]
#
# The binary is NOT stored in git. If you distribute the archive you must also offer the corresponding source of
# your modified Dolphin (GPLv2+); see NOTICE.md.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-}"; shift || true
case "$PORT" in k) NAME=dolphin-rtcore-k; TAG=K;; r) NAME=dolphin-rtcore-r; TAG=R;; *) echo "usage: $0 k|r --binary FILE [--out DIR]"; exit 2;; esac
BIN=""; SYS_DIR="${DOLPHIN_SYS_DIR:-}"; OUT="$REPO/dist"
while [ $# -gt 0 ]; do case "$1" in --binary) BIN="$2"; shift 2;; --sys-dir) SYS_DIR="$2"; shift 2;; --out) OUT="$2"; shift 2;; *) echo "unknown option $1"; exit 2;; esac; done
[ -f "$BIN" ] || { echo "--binary FILE is required"; exit 2; }
if [ -n "$SYS_DIR" ]; then
  [ -d "$SYS_DIR" ] || { echo "ERROR: --sys-dir is not a directory: $SYS_DIR" >&2; exit 1; }
  SYS_SOURCE="$(cd "$SYS_DIR" && pwd -P)"
else
  SYS_SOURCE="$(cd "$REPO/dolphin-rtcore-muos/emu/dolphin/Sys" && pwd -P)"
fi

# A relocatable firmware build reads these assets from the Sys/ directory
# next to core/dolphin. Reject incomplete payloads before producing archives.
for font in font_western.bin font_japanese.bin; do
  [ -s "$SYS_SOURCE/GC/$font" ] || { echo "ERROR: missing GameCube system font: $SYS_SOURCE/GC/$font" >&2; exit 1; }
done
for resource in dsp_rom.bin dsp_coef.bin; do
  [ -s "$SYS_SOURCE/GC/$resource" ] || { echo "ERROR: missing GameCube DSP resource: $SYS_SOURCE/GC/$resource" >&2; exit 1; }
done

# ELF64, little-endian, machine = AArch64 (0xB7)
hdr="$(head -c 20 "$BIN" | od -An -tx1 | tr -d ' \n')"
case "$hdr" in 7f454c46020101*b700) ;; *) echo "ERROR: $BIN is not an aarch64 ELF executable" >&2; exit 1;; esac

VER="$(tr -d '[:space:]' < "$REPO/$NAME/VERSION")"
S="$(mktemp -d)"; trap 'rm -rf "$S"' EXIT
D="$S/$NAME"; mkdir -p "$D"
cp -a "$REPO/$NAME/." "$D/"
rm -rf "$D/.git" "$D/logs" "$D/.installed" "$D/.theme_installed" "$D/legacy-muos" "$D/docs/screens"
C="$D/core"; mkdir -p "$C/bios"
for d in Config Load Sys GC Wii; do
  [ -d "$REPO/dolphin-rtcore-muos/emu/dolphin/$d" ] || continue
  cp -a "$REPO/dolphin-rtcore-muos/emu/dolphin/$d" "$C/"
done
# Match the muOS package policy: no per-game GameSettings database, no HD
# texture packs, and no graphics mods beyond the opt-in Bloom Removal mod.
rm -rf "$C/GameSettings" "$C/Sys/GameSettings" "$C/Load/Textures" "$C/Sys/Load/Textures"
for mod_root in "$C/Load/GraphicMods" "$C/Sys/Load/GraphicMods"; do
  [ -d "$mod_root" ] || continue
  find "$mod_root" -mindepth 1 -maxdepth 1 ! -name "All Games Bloom Removal" -exec rm -rf {} +
done
if [ "$SYS_SOURCE" != "$(cd "$REPO/dolphin-rtcore-muos/emu/dolphin/Sys" && pwd -P)" ]; then
  rm -rf "$C/Sys"
  mkdir -p "$C/Sys"
  cp -a "$SYS_SOURCE/." "$C/Sys/"
fi
install -m755 "$BIN" "$C/dolphin"
find "$D" -name '*.sh' -exec chmod 755 {} +
# archive layout from the README: extracted into <userdata>/emulators, "dolphin-rtcore-<k|r>.sh" registers everything
cat > "$S/$NAME.sh" <<WRAP
#!/bin/sh
# registers Dolphin Rt:Core $TAG in EmulationStation (same as: $NAME/rtcore.sh install)
exec "\$(dirname "\$(readlink -f "\$0")")/$NAME/rtcore.sh" install "\$@"
WRAP
chmod 755 "$S/$NAME.sh"

mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
BASE="Dolphin-RtCore-${TAG}_v${VER}"
( cd "$S" && tar -czf "$OUT/${BASE}_emulators.tar.gz" "$NAME.sh" "$NAME" )
( cd "$S" && zip -q -r -9 -X "$OUT/${BASE}.zip" "$NAME" )
echo "built: $OUT/${BASE}_emulators.tar.gz  ($(du -h "$OUT/${BASE}_emulators.tar.gz" | cut -f1))"
echo "built: $OUT/${BASE}.zip"
echo "binary: $(strings -n 8 "$BIN" | grep -m1 -E '^Dolphin [0-9]') sha256=$(sha256sum "$BIN" | cut -c1-16)…"
echo "Sys: $SYS_SOURCE"
