#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGER="$ROOT/dolphin-rtcore-muos/tools/build-muxupd.sh"
bash -n "$PACKAGER"
BASE_SYS="$ROOT/dolphin-rtcore-muos/emu/dolphin/Sys"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SYS="$TMP/Sys"
mkdir -p "$SYS"
cp -a "$BASE_SYS/." "$SYS/"
MARKER_REL="Resources/RtCore-packaging-probe.txt"
printf 'Sys tree from a specific Dolphin build revision\n' > "$SYS/$MARKER_REL"

# The packager validates the aarch64 ELF header; this minimal fixture is not
# an executable emulator and is used only to exercise archive assembly.
python3 - "$TMP/dolphin" <<'PY'
from pathlib import Path
import sys

header = bytes.fromhex("7f454c460201010000000000000000000300b700")
Path(sys.argv[1]).write_bytes(header + b"RtCore packaging test fixture\n")
PY
chmod 755 "$TMP/dolphin"

# A normal update must never be assembled without the actual Dolphin binary.
if bash "$PACKAGER" "$TMP/no-binary" >"$TMP/no-binary.log" 2>&1; then
  echo "[FAIL] packager accepted a full update without DOLPHIN_BIN" >&2
  exit 1
fi
grep -Fq "refusing to build an installable muOS update without Dolphin" "$TMP/no-binary.log"
echo "[OK] missing Dolphin executable is rejected by default"

# An explicitly labelled UI-only archive is allowed for source-level CI validation.
UI_OUT="$TMP/ui-only"
DOLPHIN_UI_ONLY=1 bash "$PACKAGER" "$UI_OUT"
UI_ARCHIVE="$UI_OUT/Dolphin_RtCore_v$(tr -d '[:space:]' < "$ROOT/dolphin-rtcore-muos/VERSION" | tr '.' '_')_Andromeda_ui-only.muxupd"
[ -s "$UI_ARCHIVE" ]
if unzip -Z1 "$UI_ARCHIVE" | grep -Fxq "opt/muos/share/emulator/dolphin/dolphin"; then
  echo "[FAIL] UI-only archive unexpectedly contains a Dolphin executable" >&2
  exit 1
fi
echo "[OK] UI-only archive is explicitly labelled and cannot be mistaken for a complete build"

LIBS="$TMP/lib"
mkdir -p "$LIBS"
printf "HIDAPI runtime fixture\n" > "$LIBS/libhidapi-hidraw.so.0"

OUT="$TMP/dist"
DOLPHIN_BIN="$TMP/dolphin" DOLPHIN_SYS_DIR="$SYS" DOLPHIN_LIB_DIR="$LIBS" \
  bash "$PACKAGER" "$OUT"

VERSION="$(tr -d '[:space:]' < "$ROOT/dolphin-rtcore-muos/VERSION")"
ARCHIVE="$OUT/Dolphin_RtCore_v${VERSION//./_}_Andromeda.muxupd"
[ -s "$ARCHIVE" ]

EMU_PATH="opt/muos/share/emulator/dolphin"
for asset in \
  "$EMU_PATH/dolphin" \
  "$EMU_PATH/lib/libhidapi-hidraw.so.0" \
  "$EMU_PATH/Sys/GC/font_western.bin" \
  "$EMU_PATH/Sys/GC/font_japanese.bin" \
  "$EMU_PATH/Sys/GC/dsp_rom.bin" \
  "$EMU_PATH/Sys/GC/dsp_coef.bin" \
  "$EMU_PATH/Sys/Resources/OSD_Font.ttf" \
  "$EMU_PATH/Sys/$MARKER_REL"; do
  unzip -Z1 "$ARCHIVE" | grep -Fxq "$asset"
done

unzip -p "$ARCHIVE" "$EMU_PATH/dolphin" | cmp -s "$TMP/dolphin" -
unzip -p "$ARCHIVE" "$EMU_PATH/lib/libhidapi-hidraw.so.0" | cmp -s "$LIBS/libhidapi-hidraw.so.0" -
if unzip -Z1 "$ARCHIVE" | grep -Fxq "run/muos/storage/application/Dolphin RtUI/data/settings.json"; then
  echo "[FAIL] MUXUPD would overwrite device-local Rt:UI settings.json" >&2
  exit 1
fi
echo "[OK] MUXUPD preserves device-local Rt:UI settings and ROM paths"
unzip -p "$ARCHIVE" "$EMU_PATH/Sys/$MARKER_REL" | cmp -s "$SYS/$MARKER_REL" -

MARKER_SHA="$(sha256sum "$SYS/$MARKER_REL" | awk '{print $1}')"
unzip -p "$ARCHIVE" manifest.sha256 | grep -Fqx "$MARKER_SHA  $EMU_PATH/Sys/$MARKER_REL"

echo "[OK] binary, private HIDAPI runtime and supplied Sys tree are included at the muOS runtime paths"
echo "[OK] GameCube fonts, DSP assets, and the Sys-tree marker are present"

# Official per-game settings, stock texture packs and graphics mods are user-facing
# Dolphin payload. A supplied build Sys tree must not erase the curated resources.
for asset in \
  "$EMU_PATH/GameSettings/GOWP69.ini" \
  "$EMU_PATH/Load/Textures/GCN/tex1_512x256_c8101281265628cc_14.png" \
  "$EMU_PATH/Sys/Load/GraphicMods/Dragon Ball Z Budokai Tenkaichi 3/metadata.json" \
  "run/muos/storage/application/Dolphin RtUI/workshop/gamesettings/GD7E70/base.ini"; do
  unzip -Z1 "$ARCHIVE" | grep -Fxq "$asset" || {
    echo "[FAIL] official Dolphin settings/mod payload missing from MUXUPD: $asset" >&2
    exit 1
  }
done
echo "[OK] official GameSettings, texture packs, graphics mods and Rt:UI game profiles are retained"
echo "[OK] manifest.sha256 covers the supplied Sys-tree marker"

# Publishing is atomic: an interrupted ZIP write must preserve the previous
# valid package byte-for-byte and remove the incomplete temporary file.
ATOMIC_OUT="$TMP/atomic-dist"
mkdir -p "$ATOMIC_OUT"
ATOMIC_ARCHIVE="$ATOMIC_OUT/$(basename "$ARCHIVE")"
cp "$ARCHIVE" "$ATOMIC_ARCHIVE"
ATOMIC_BEFORE="$(sha256sum "$ATOMIC_ARCHIVE" | awk '{print $1}')"
FAILING_ZIP="$TMP/failing-zip-bin"
mkdir -p "$FAILING_ZIP"
cat > "$FAILING_ZIP/zip" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
target=""
for arg in "$@"; do
  case "$arg" in *.muxupd.tmp.*) target="$arg" ;; esac
done
[ -n "$target" ] || { echo "test wrapper did not receive a temporary archive path" >&2; exit 97; }
printf 'deliberately incomplete ZIP data\n' > "$target"
exit 1
SH
chmod 755 "$FAILING_ZIP/zip"
if PATH="$FAILING_ZIP:$PATH" DOLPHIN_BIN="$TMP/dolphin" DOLPHIN_SYS_DIR="$SYS" DOLPHIN_LIB_DIR="$LIBS" \
  bash "$PACKAGER" "$ATOMIC_OUT" >"$TMP/atomic-zip-failure.log" 2>&1; then
  echo "[FAIL] packager reported success after a failed ZIP write" >&2
  exit 1
fi
ATOMIC_AFTER="$(sha256sum "$ATOMIC_ARCHIVE" | awk '{print $1}')"
[ "$ATOMIC_BEFORE" = "$ATOMIC_AFTER" ] || {
  echo "[FAIL] failed ZIP write changed the previously published MUXUPD" >&2
  exit 1
}
unzip -tq "$ATOMIC_ARCHIVE" >/dev/null
if find "$ATOMIC_OUT" -maxdepth 1 -type f -name "$(basename "$ATOMIC_ARCHIVE").tmp.*" -print -quit | grep -q .; then
  echo "[FAIL] failed ZIP write left a temporary archive behind" >&2
  exit 1
fi
echo "[OK] failed ZIP write preserves the prior valid MUXUPD and cleans the temporary archive"

# A faulty ZIP tool can also return zero while producing an invalid archive.
# Integrity validation must reject it just as safely as a non-zero exit.
CORRUPT_ZIP="$TMP/corrupt-zip-bin"
mkdir -p "$CORRUPT_ZIP"
cat > "$CORRUPT_ZIP/zip" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
target=""
for arg in "$@"; do
  case "$arg" in *.muxupd.tmp.*) target="$arg" ;; esac
done
[ -n "$target" ] || { echo "test wrapper did not receive a temporary archive path" >&2; exit 97; }
printf 'not a ZIP archive, despite exit zero\n' > "$target"
exit 0
SH
chmod 755 "$CORRUPT_ZIP/zip"
if PATH="$CORRUPT_ZIP:$PATH" DOLPHIN_BIN="$TMP/dolphin" DOLPHIN_SYS_DIR="$SYS" DOLPHIN_LIB_DIR="$LIBS" \
  bash "$PACKAGER" "$ATOMIC_OUT" >"$TMP/corrupt-zip.log" 2>&1; then
  echo "[FAIL] packager accepted an invalid ZIP after zero exit status" >&2
  exit 1
fi
grep -Eiq 'not a zip archive|zipfile|end-of-central-directory|cannot find zipfile directory' "$TMP/corrupt-zip.log" || {
  echo "[FAIL] invalid ZIP was rejected for an unexpected reason" >&2
  cat "$TMP/corrupt-zip.log" >&2
  exit 1
}
[ "$ATOMIC_BEFORE" = "$(sha256sum "$ATOMIC_ARCHIVE" | awk '{print $1}')" ] || {
  echo "[FAIL] invalid ZIP validation changed the existing package" >&2
  exit 1
}
unzip -tq "$ATOMIC_ARCHIVE" >/dev/null
if find "$ATOMIC_OUT" -maxdepth 1 -type f -name "$(basename "$ATOMIC_ARCHIVE").tmp.*" -print -quit | grep -q .; then
  echo "[FAIL] invalid ZIP validation left a temporary archive behind" >&2
  exit 1
fi
echo "[OK] invalid ZIP is rejected even after zip exits zero; prior MUXUPD stays intact"



# Missing assets must fail before an update archive is produced.
BROKEN_SYS="$TMP/Sys-missing-font"
cp -a "$SYS" "$BROKEN_SYS"
rm -f "$BROKEN_SYS/GC/font_japanese.bin"
FAIL_OUT="$TMP/fail-dist"
if DOLPHIN_BIN="$TMP/dolphin" DOLPHIN_SYS_DIR="$BROKEN_SYS" \
  bash "$PACKAGER" "$FAIL_OUT" >"$TMP/missing-font.log" 2>&1; then
  echo "[FAIL] packager accepted a Sys tree without font_japanese.bin" >&2
  exit 1
fi
grep -Fq "missing GameCube system font" "$TMP/missing-font.log"
if find "$FAIL_OUT" -maxdepth 1 -type f -name '*.muxupd' -print -quit 2>/dev/null | grep -q .; then
  echo "[FAIL] failed resource validation left a .muxupd archive" >&2
  exit 1
fi
echo "[OK] missing GameCube font is rejected before archive creation"

# Missing DSP data is also fatal before an update archive is written.
DSP_SYS="$TMP/Sys-missing-dsp"
mkdir -p "$DSP_SYS/GC"
cp "$SYS/GC/font_western.bin" "$DSP_SYS/GC/"
cp "$SYS/GC/font_japanese.bin" "$DSP_SYS/GC/"
cp "$SYS/GC/dsp_rom.bin" "$DSP_SYS/GC/"
if DOLPHIN_BIN="$TMP/dolphin" DOLPHIN_SYS_DIR="$DSP_SYS" \
  bash "$PACKAGER" "$TMP/fail-dsp-dist" >"$TMP/missing-dsp.log" 2>&1; then
  echo "[FAIL] packager accepted a Sys tree without dsp_coef.bin" >&2
  exit 1
fi
grep -Fq "missing GameCube DSP resource" "$TMP/missing-dsp.log"
if find "$TMP/fail-dsp-dist" -maxdepth 1 -type f -name '*.muxupd' -print -quit 2>/dev/null | grep -q .; then
  echo "[FAIL] DSP validation failure left a .muxupd archive" >&2
  exit 1
fi
echo "[OK] missing GameCube DSP data is rejected before archive creation"
