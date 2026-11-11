#!/usr/bin/env bash
# Stage the legacy external-core assignment INIs into a MUXUPD root.
# Jacaranda (2601.x) reads these folders directly from /opt/muos/share/info/assign.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:?usage: stage-legacy-assign.sh <muxupd-root> [profile-mode]}"
MODE="${2:-1}"
case "$MODE" in 1|2) ;; *) echo "ERROR: profile mode must be 1 or 2" >&2; exit 2;; esac

SOURCE="$ROOT/emu/dolphin/RtSys/switch_weapon"
GC_SOURCE="$SOURCE/gc/mode $MODE"
WII_SOURCE="$SOURCE/wii/mode $MODE"
GC_TARGET="$DEST/opt/muos/share/info/assign/Nintendo GameCube"
WII_TARGET="$DEST/opt/muos/share/info/assign/Nintendo Wii"

for kind in gc wii; do
    if [ "$kind" = gc ]; then src="$GC_SOURCE"; dst="$GC_TARGET"; else src="$WII_SOURCE"; dst="$WII_TARGET"; fi
    [ -s "$src/global.ini" ] || { echo "ERROR: missing legacy assignment source: $src/global.ini" >&2; exit 1; }
    default="$(sed -n 's/^default=//p' "$src/global.ini" | head -n 1 | tr -d '\r')"
    [ -n "$default" ] && [ -s "$src/$default.ini" ] || { echo "ERROR: missing default INI in $src" >&2; exit 1; }
    count=0
    for ini in "$src"/*.ini; do
        [ -f "$ini" ] || continue
        [ "$(basename "$ini")" = global.ini ] || count=$((count + 1))
    done
    [ "$count" -gt 0 ] || { echo "ERROR: no profile INIs in $src" >&2; exit 1; }
    mkdir -p "$dst"
    cp -f "$src"/*.ini "$dst/"
    echo "[OK] $(basename "$dst"): $count profiles (default: $default)"
done
