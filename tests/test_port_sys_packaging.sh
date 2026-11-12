#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILDER="$ROOT/tools/make-port-release.sh"
BASE_SYS="$ROOT/dolphin-rtcore-muos/emu/dolphin/Sys"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SYS="$TMP/Sys"
mkdir -p "$SYS"
cp -a "$BASE_SYS/." "$SYS/"
MARKER_REL="Resources/RtCore-port-packaging-probe.txt"
printf 'matching Sys tree for the supplied aarch64 binary\n' > "$SYS/$MARKER_REL"

# Minimal AArch64 ELF header fixture: archives are inspected, never executed.
python3 - "$TMP/dolphin" <<'PY'
from pathlib import Path
import sys

header = bytes.fromhex("7f454c460201010000000000000000000300b700")
Path(sys.argv[1]).write_bytes(header + b"RtCore port packaging fixture\n")
PY
chmod 755 "$TMP/dolphin"

for port in k r; do
  case "$port" in
    k) name="dolphin-rtcore-k"; tag="K" ;;
    r) name="dolphin-rtcore-r"; tag="R" ;;
  esac
  out="$TMP/out-$port"
  bash "$BUILDER" "$port" --binary "$TMP/dolphin" --sys-dir "$SYS" --out "$out"

  version="$(tr -d '[:space:]' < "$ROOT/$name/VERSION")"
  archive="$out/Dolphin-RtCore-${tag}_v${version}_emulators.tar.gz"
  [ -s "$archive" ]
  listing="$TMP/$port-archive-files.txt"
  tar -tzf "$archive" > "$listing"
  for asset in \
    "$name/core/dolphin" \
    "$name/core/Sys/GC/font_western.bin" \
    "$name/core/Sys/GC/font_japanese.bin" \
    "$name/core/Sys/GC/dsp_rom.bin" \
    "$name/core/Sys/GC/dsp_coef.bin" \
    "$name/core/Sys/$MARKER_REL"; do
    grep -Fxq "$asset" "$listing"
  done
  tar -xOzf "$archive" "$name/core/dolphin" | cmp -s "$TMP/dolphin" -
  tar -xOzf "$archive" "$name/core/Sys/$MARKER_REL" | cmp -s "$SYS/$MARKER_REL" -
  if grep -Eq '(^|/)(GameSettings|gamesettings)(/|\.json$)|/(Load|Sys/Load)/Textures/' "$listing"; then
    echo "[FAIL] $name archive contains GameSettings or texture packs" >&2
    exit 1
  fi
  if grep -E '/(Sys/)?Load/GraphicMods/' "$listing" | grep -v -E '/GraphicMods/$|/All Games Bloom Removal/'; then
    echo "[FAIL] $name archive contains a non-Bloom-Removal graphics mod" >&2
    exit 1
  fi
  grep -Fq '/Load/GraphicMods/All Games Bloom Removal/' "$listing" ||
    grep -Fq '/Sys/Load/GraphicMods/All Games Bloom Removal/' "$listing"
  echo "[OK] $name archive has no GameSettings or textures and keeps only Bloom Removal"
  echo "[OK] $name archive includes matching binary and supplied Sys tree"
done

# Both fonts and both DSP assets are mandatory for every port archive.
for missing in font_western.bin font_japanese.bin dsp_rom.bin dsp_coef.bin; do
  BROKEN="$TMP/Sys-missing-$missing"
  cp -a "$SYS" "$BROKEN"
  rm -f "$BROKEN/GC/$missing"
  OUT="$TMP/fail-$missing"
  if DOLPHIN_SYS_DIR="$BROKEN" bash "$BUILDER" k --binary "$TMP/dolphin" --out "$OUT" >"$TMP/$missing.log" 2>&1; then
    echo "[FAIL] port builder accepted Sys without $missing" >&2
    exit 1
  fi
  grep -Eq 'missing GameCube (system font|DSP resource)' "$TMP/$missing.log"
  if find "$OUT" -maxdepth 1 -type f \( -name '*.zip' -o -name '*.tar.gz' \) -print -quit 2>/dev/null | grep -q .; then
    echo "[FAIL] failed resource validation left a release archive ($missing)" >&2
    exit 1
  fi
  echo "[OK] missing $missing is rejected before archive creation"
done
