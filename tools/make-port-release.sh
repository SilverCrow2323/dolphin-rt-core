#!/usr/bin/env bash
# Builds a ready-to-install archive of a port (Knulli "k" or ROCKNIX "r") that includes core/:
#   core/ = the shared emulator tree (dolphin-rtcore-muos/emu/dolphin: Config, GameSettings, Load, Sys, GC, Wii)
#           + YOUR aarch64 dolphin binary.  RtSys/ is muOS tooling and is left out.
#
#   tools/make-port-release.sh k --binary /path/to/dolphin [--out DIR]
#   tools/make-port-release.sh r --binary /path/to/dolphin [--out DIR]
#
# The binary is NOT stored in git. If you distribute the archive you must also offer the corresponding source of
# your modified Dolphin (GPLv2+); see NOTICE.md.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-}"; shift || true
case "$PORT" in k) NAME=dolphin-rtcore-k; TAG=K;; r) NAME=dolphin-rtcore-r; TAG=R;; *) echo "usage: $0 k|r --binary FILE [--out DIR]"; exit 2;; esac
BIN=""; OUT="$REPO/dist"
while [ $# -gt 0 ]; do case "$1" in --binary) BIN="$2"; shift 2;; --out) OUT="$2"; shift 2;; *) echo "unknown option $1"; exit 2;; esac; done
[ -f "$BIN" ] || { echo "--binary FILE is required"; exit 2; }

# ELF64, little-endian, machine = AArch64 (0xB7)
hdr="$(head -c 20 "$BIN" | od -An -tx1 | tr -d ' \n')"
case "$hdr" in 7f454c46020101*b700) ;; *) echo "ERROR: $BIN is not an aarch64 ELF executable" >&2; exit 1;; esac

VER="$(tr -d '[:space:]' < "$REPO/$NAME/VERSION")"
S="$(mktemp -d)"; trap 'rm -rf "$S"' EXIT
D="$S/$NAME"; mkdir -p "$D"
cp -a "$REPO/$NAME/." "$D/"
rm -rf "$D/.git" "$D/logs" "$D/.installed" "$D/.theme_installed" "$D/legacy-muos" "$D/docs/screens"
C="$D/core"; mkdir -p "$C/bios"
for d in Config GameSettings Load Sys GC Wii; do cp -a "$REPO/dolphin-rtcore-muos/emu/dolphin/$d" "$C/"; done
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
