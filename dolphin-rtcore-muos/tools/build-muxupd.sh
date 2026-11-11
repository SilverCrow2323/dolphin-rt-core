#!/usr/bin/env bash
# Builds dist/Dolphin_RtCore_v<version>_Andromeda.muxupd for muOS 2606.0 "Andromeda".
# Andromeda requires an integrity manifest (manifest.sha256) in every .muxupd; this script generates it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
OUT="${1:-$ROOT/dist}"; mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
ARCHIVE="$OUT/Dolphin_RtCore_v${VERSION//./_}_Andromeda.muxupd"
# Optional: DOLPHIN_BIN=/path/to/aarch64/dolphin includes the emulator binary (not stored in git; see NOTICE.md for GPL source duties)
DOLPHIN_BIN="${DOLPHIN_BIN:-}"
if [ -n "$DOLPHIN_BIN" ]; then
  hdr="$(head -c 20 "$DOLPHIN_BIN" | od -An -tx1 | tr -d ' \n')"
  case "$hdr" in 7f454c46020101*b700) ;; *) echo "ERROR: DOLPHIN_BIN is not an aarch64 ELF executable" >&2; exit 1;; esac
  ARCHIVE="${ARCHIVE%.muxupd}_with-dolphin.muxupd"
fi
S="$(mktemp -d)"; trap 'rm -rf "$S"' EXIT

# GameCube IPL text rendering depends on these bundled Dolphin 2412 resources.
for font in font_western.bin font_japanese.bin; do
  [ -s "$ROOT/emu/dolphin/Sys/GC/$font" ] || { echo "ERROR: missing GameCube system font: $ROOT/emu/dolphin/Sys/GC/$font" >&2; exit 1; }
done
for resource in dsp_rom.bin dsp_coef.bin; do
  [ -s "$ROOT/emu/dolphin/Sys/GC/$resource" ] || { echo "ERROR: missing GameCube DSP resource: $ROOT/emu/dolphin/Sys/GC/$resource" >&2; exit 1; }
done

APP="run/muos/storage/application/Dolphin RtUI"; EMU="opt/muos/share/emulator/dolphin"
mkdir -p "$S/$APP" "$S/$EMU"
cp -a "$ROOT/emu/dolphin/." "$S/$EMU/"
cp -a "$ROOT/app/Dolphin RtUI/." "$S/$APP/"
cp -a "$ROOT/overlay/." "$S/"                         # muOS-only files (launcher, tasks, manifest tool, update hook)
[ -n "$DOLPHIN_BIN" ] && install -m755 "$DOLPHIN_BIN" "$S/$EMU/dolphin"
mkdir -p "$S/$APP/data/logs" "$S/$APP/data/stream/covers" "$S/$APP/data/stream/keys"

find "$S" -name '*.sh' -exec chmod 755 {} +
chmod 755 "$S/$APP"/lib/love "$S/$APP"/lib/moonlight "$S/$APP"/lib/gptokeyb2 2>/dev/null || true
find "$S" \( -name __pycache__ -o -name '*.rt.*' -o -name '*.tmp' -o -name '*.bak' \) -prune -exec rm -rf {} +

# Never ship personal / runtime data
if find "$S" -path '*/data/stream/*' -type f | grep -q .; then echo "ERROR: runtime stream data in the package" >&2; exit 1; fi

( cd "$S" && rm -f manifest.sha256 \
  && find . -type f | sed 's|^\./||' | LC_ALL=C sort > /tmp/.rt_files.$$ \
  && if grep -q -E '[][*?\\]|^/|\.\.' /tmp/.rt_files.$$; then echo "ERROR: unsafe file name" >&2; exit 1; fi \
  && xargs -d '\n' sha256sum < /tmp/.rt_files.$$ > manifest.sha256 && rm -f /tmp/.rt_files.$$ \
  && rm -f "$ARCHIVE" && zip -q -X -r -9 "$ARCHIVE" manifest.sha256 opt run )
echo "built $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1), $(wc -l < <(unzip -Z1 "$ARCHIVE" | grep -v '/$')) files)"
