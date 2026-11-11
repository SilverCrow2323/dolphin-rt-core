#!/usr/bin/env bash
# Builds dist/Dolphin_RtCore_v<version>_Andromeda.muxupd for muOS 2606.0 "Andromeda".
# Andromeda requires an integrity manifest (manifest.sha256) in every .muxupd; this script generates it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
OUT="${1:-$ROOT/dist}"; mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
ARCHIVE="$OUT/Dolphin_RtCore_v${VERSION//./_}_Andromeda.muxupd"
# Optional build outputs:
#   DOLPHIN_BIN=/path/to/aarch64/dolphin
#   DOLPHIN_SYS_DIR=/path/to/build/Sys
# Keep binary and Sys from the same Dolphin build revision.
DOLPHIN_BIN="${DOLPHIN_BIN:-}"
DOLPHIN_SYS_DIR="${DOLPHIN_SYS_DIR:-}"
DOLPHIN_LIB_DIR="${DOLPHIN_LIB_DIR:-}"

# Require complete GameCube/Wii assignment definitions in every release.
# Andromeda consumes them through core.json -> generated assign.json;
# Jacaranda installs the legacy INI tree under share/info/assign.
validate_assignment_sources() {
  local switch_root="$ROOT/emu/dolphin/RtSys/switch_weapon"
  local system mode dir expected_name default profile profile_count alias required_aliases
  for mode in 1 2; do
    for system in gc wii; do
      dir="$switch_root/$system/mode $mode"
      [ -s "$dir/global.ini" ] || {
        echo "ERROR: missing assignment source: $dir/global.ini" >&2
        return 1
      }
      default="$(sed -n 's/^default=//p' "$dir/global.ini" | head -n 1)"
      [ -n "$default" ] && [ -s "$dir/$default.ini" ] || {
        echo "ERROR: missing default $system profile '$default' in mode $mode" >&2
        return 1
      }
      if [ "$system" = gc ]; then
        expected_name="Nintendo Gamecube"
        required_aliases="nintendogamecube nintendogc gamecube gamecubez ngc gc"
      else
        expected_name="Nintendo Wii"
        required_aliases="nintendowii nwii wii wiiz"
      fi
      grep -Fxq "name=$expected_name" "$dir/global.ini" || {
        echo "ERROR: unexpected platform name in $dir/global.ini" >&2
        return 1
      }
      for alias in $required_aliases; do
        grep -Fxq "$alias" "$dir/global.ini" || {
          echo "ERROR: missing $system folder alias '$alias' in mode $mode" >&2
          return 1
        }
      done
      profile_count=0
      for profile in "$dir"/*.ini; do
        [ -f "$profile" ] || continue
        [ "$(basename "$profile")" = global.ini ] && continue
        grep -Eq '^name=.+if [ -z "$DOLPHIN_LIB_DIR" ] && [ -n "$DOLPHIN_BIN" ] && [ -d "$(dirname "$DOLPHIN_BIN")/lib" ]; then
  DOLPHIN_LIB_DIR="$(dirname "$DOLPHIN_BIN")/lib"
fi
DEFAULT_SYS_SOURCE="$(cd "$ROOT/emu/dolphin/Sys" && pwd -P)"
SYS_SOURCE="$DEFAULT_SYS_SOURCE"
if [ -n "$DOLPHIN_SYS_DIR" ]; then
  [ -d "$DOLPHIN_SYS_DIR" ] || { echo "ERROR: DOLPHIN_SYS_DIR is not a directory: $DOLPHIN_SYS_DIR" >&2; exit 1; }
  SYS_SOURCE="$(cd "$DOLPHIN_SYS_DIR" && pwd -P)"
fi
if [ -n "$DOLPHIN_BIN" ]; then
  hdr="$(head -c 20 "$DOLPHIN_BIN" | od -An -tx1 | tr -d ' \n')"
  case "$hdr" in 7f454c46020101*b700) ;; *) echo "ERROR: DOLPHIN_BIN is not an aarch64 ELF executable" >&2; exit 1;; esac
  ARCHIVE="${ARCHIVE%.muxupd}_with-dolphin.muxupd"
fi
S="$(mktemp -d)"; trap 'rm -rf "$S"' EXIT

# GameCube IPL text rendering depends on these Dolphin system resources.
# When a freshly built Sys tree is supplied, validate and package that exact tree.
for font in font_western.bin font_japanese.bin; do
  [ -s "$SYS_SOURCE/GC/$font" ] || { echo "ERROR: missing GameCube system font: $SYS_SOURCE/GC/$font" >&2; exit 1; }
done
for resource in dsp_rom.bin dsp_coef.bin; do
  [ -s "$SYS_SOURCE/GC/$resource" ] || { echo "ERROR: missing GameCube DSP resource: $SYS_SOURCE/GC/$resource" >&2; exit 1; }
done
[ -s "$SYS_SOURCE/Resources/OSD_Font.ttf" ] || { echo "ERROR: missing Dolphin OSD font: $SYS_SOURCE/Resources/OSD_Font.ttf" >&2; exit 1; }

APP="run/muos/storage/application/Dolphin RtUI"; EMU="opt/muos/share/emulator/dolphin"
mkdir -p "$S/$APP" "$S/$EMU"
cp -a "$ROOT/emu/dolphin/." "$S/$EMU/"
if [ "$SYS_SOURCE" != "$DEFAULT_SYS_SOURCE" ]; then
  rm -rf "$S/$EMU/Sys"
  mkdir -p "$S/$EMU/Sys"
  cp -a "$SYS_SOURCE/." "$S/$EMU/Sys/"
fi
cp -a "$ROOT/app/Dolphin RtUI/." "$S/$APP/"
cp -a "$ROOT/overlay/." "$S/"                         # muOS-only files (launcher, tasks, manifest tool, update hook)
[ -n "$DOLPHIN_BIN" ] && install -m755 "$DOLPHIN_BIN" "$S/$EMU/dolphin"
if [ -n "$DOLPHIN_LIB_DIR" ]; then
  [ -d "$DOLPHIN_LIB_DIR" ] || { echo "ERROR: DOLPHIN_LIB_DIR is not a directory: $DOLPHIN_LIB_DIR" >&2; exit 1; }
  mkdir -p "$S/$EMU/lib"
  cp -a "$DOLPHIN_LIB_DIR/." "$S/$EMU/lib/"
fi
if [ -n "$DOLPHIN_BIN" ] && readelf -d "$DOLPHIN_BIN" 2>/dev/null | grep -q "libhidapi-hidraw.so.0"; then
  [ -s "$S/$EMU/lib/libhidapi-hidraw.so.0" ] || { echo "ERROR: missing bundled HIDAPI runtime; set DOLPHIN_LIB_DIR" >&2; exit 1; }
fi
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
 "$profile" || {
          echo "ERROR: assignment profile has no name: $profile" >&2
          return 1
        }
        grep -Eq '^core=ext-dolphin-[A-Za-z0-9_-]+if [ -z "$DOLPHIN_LIB_DIR" ] && [ -n "$DOLPHIN_BIN" ] && [ -d "$(dirname "$DOLPHIN_BIN")/lib" ]; then
  DOLPHIN_LIB_DIR="$(dirname "$DOLPHIN_BIN")/lib"
fi
DEFAULT_SYS_SOURCE="$(cd "$ROOT/emu/dolphin/Sys" && pwd -P)"
SYS_SOURCE="$DEFAULT_SYS_SOURCE"
if [ -n "$DOLPHIN_SYS_DIR" ]; then
  [ -d "$DOLPHIN_SYS_DIR" ] || { echo "ERROR: DOLPHIN_SYS_DIR is not a directory: $DOLPHIN_SYS_DIR" >&2; exit 1; }
  SYS_SOURCE="$(cd "$DOLPHIN_SYS_DIR" && pwd -P)"
fi
if [ -n "$DOLPHIN_BIN" ]; then
  hdr="$(head -c 20 "$DOLPHIN_BIN" | od -An -tx1 | tr -d ' \n')"
  case "$hdr" in 7f454c46020101*b700) ;; *) echo "ERROR: DOLPHIN_BIN is not an aarch64 ELF executable" >&2; exit 1;; esac
  ARCHIVE="${ARCHIVE%.muxupd}_with-dolphin.muxupd"
fi
S="$(mktemp -d)"; trap 'rm -rf "$S"' EXIT

# GameCube IPL text rendering depends on these Dolphin system resources.
# When a freshly built Sys tree is supplied, validate and package that exact tree.
for font in font_western.bin font_japanese.bin; do
  [ -s "$SYS_SOURCE/GC/$font" ] || { echo "ERROR: missing GameCube system font: $SYS_SOURCE/GC/$font" >&2; exit 1; }
done
for resource in dsp_rom.bin dsp_coef.bin; do
  [ -s "$SYS_SOURCE/GC/$resource" ] || { echo "ERROR: missing GameCube DSP resource: $SYS_SOURCE/GC/$resource" >&2; exit 1; }
done
[ -s "$SYS_SOURCE/Resources/OSD_Font.ttf" ] || { echo "ERROR: missing Dolphin OSD font: $SYS_SOURCE/Resources/OSD_Font.ttf" >&2; exit 1; }

APP="run/muos/storage/application/Dolphin RtUI"; EMU="opt/muos/share/emulator/dolphin"
mkdir -p "$S/$APP" "$S/$EMU"
cp -a "$ROOT/emu/dolphin/." "$S/$EMU/"
if [ "$SYS_SOURCE" != "$DEFAULT_SYS_SOURCE" ]; then
  rm -rf "$S/$EMU/Sys"
  mkdir -p "$S/$EMU/Sys"
  cp -a "$SYS_SOURCE/." "$S/$EMU/Sys/"
fi
cp -a "$ROOT/app/Dolphin RtUI/." "$S/$APP/"
cp -a "$ROOT/overlay/." "$S/"                         # muOS-only files (launcher, tasks, manifest tool, update hook)
[ -n "$DOLPHIN_BIN" ] && install -m755 "$DOLPHIN_BIN" "$S/$EMU/dolphin"
if [ -n "$DOLPHIN_LIB_DIR" ]; then
  [ -d "$DOLPHIN_LIB_DIR" ] || { echo "ERROR: DOLPHIN_LIB_DIR is not a directory: $DOLPHIN_LIB_DIR" >&2; exit 1; }
  mkdir -p "$S/$EMU/lib"
  cp -a "$DOLPHIN_LIB_DIR/." "$S/$EMU/lib/"
fi
if [ -n "$DOLPHIN_BIN" ] && readelf -d "$DOLPHIN_BIN" 2>/dev/null | grep -q "libhidapi-hidraw.so.0"; then
  [ -s "$S/$EMU/lib/libhidapi-hidraw.so.0" ] || { echo "ERROR: missing bundled HIDAPI runtime; set DOLPHIN_LIB_DIR" >&2; exit 1; }
fi
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
 "$profile" || {
          echo "ERROR: assignment profile has invalid Dolphin core identifier: $profile" >&2
          return 1
        }
        grep -Fxq 'exec=/opt/muos/script/launch/ext-dolphinrt.sh' "$profile" || {
          echo "ERROR: assignment profile has no Rt:Core launcher: $profile" >&2
          return 1
        }
        profile_count=$((profile_count + 1))
      done
      [ "$profile_count" -gt 0 ] || {
        echo "ERROR: no $system assignment profiles found in mode $mode" >&2
        return 1
      }
      echo "validated $system mode $mode: $profile_count profiles, default=$default"
    done
  done
}
validate_assignment_sources
if [ -z "$DOLPHIN_LIB_DIR" ] && [ -n "$DOLPHIN_BIN" ] && [ -d "$(dirname "$DOLPHIN_BIN")/lib" ]; then
  DOLPHIN_LIB_DIR="$(dirname "$DOLPHIN_BIN")/lib"
fi
DEFAULT_SYS_SOURCE="$(cd "$ROOT/emu/dolphin/Sys" && pwd -P)"
SYS_SOURCE="$DEFAULT_SYS_SOURCE"
if [ -n "$DOLPHIN_SYS_DIR" ]; then
  [ -d "$DOLPHIN_SYS_DIR" ] || { echo "ERROR: DOLPHIN_SYS_DIR is not a directory: $DOLPHIN_SYS_DIR" >&2; exit 1; }
  SYS_SOURCE="$(cd "$DOLPHIN_SYS_DIR" && pwd -P)"
fi
if [ -n "$DOLPHIN_BIN" ]; then
  hdr="$(head -c 20 "$DOLPHIN_BIN" | od -An -tx1 | tr -d ' \n')"
  case "$hdr" in 7f454c46020101*b700) ;; *) echo "ERROR: DOLPHIN_BIN is not an aarch64 ELF executable" >&2; exit 1;; esac
  ARCHIVE="${ARCHIVE%.muxupd}_with-dolphin.muxupd"
fi
S="$(mktemp -d)"; trap 'rm -rf "$S"' EXIT

# GameCube IPL text rendering depends on these Dolphin system resources.
# When a freshly built Sys tree is supplied, validate and package that exact tree.
for font in font_western.bin font_japanese.bin; do
  [ -s "$SYS_SOURCE/GC/$font" ] || { echo "ERROR: missing GameCube system font: $SYS_SOURCE/GC/$font" >&2; exit 1; }
done
for resource in dsp_rom.bin dsp_coef.bin; do
  [ -s "$SYS_SOURCE/GC/$resource" ] || { echo "ERROR: missing GameCube DSP resource: $SYS_SOURCE/GC/$resource" >&2; exit 1; }
done
[ -s "$SYS_SOURCE/Resources/OSD_Font.ttf" ] || { echo "ERROR: missing Dolphin OSD font: $SYS_SOURCE/Resources/OSD_Font.ttf" >&2; exit 1; }

APP="run/muos/storage/application/Dolphin RtUI"; EMU="opt/muos/share/emulator/dolphin"
mkdir -p "$S/$APP" "$S/$EMU"
cp -a "$ROOT/emu/dolphin/." "$S/$EMU/"
if [ "$SYS_SOURCE" != "$DEFAULT_SYS_SOURCE" ]; then
  rm -rf "$S/$EMU/Sys"
  mkdir -p "$S/$EMU/Sys"
  cp -a "$SYS_SOURCE/." "$S/$EMU/Sys/"
fi
cp -a "$ROOT/app/Dolphin RtUI/." "$S/$APP/"
cp -a "$ROOT/overlay/." "$S/"                         # muOS-only files (launcher, tasks, manifest tool, update hook)
[ -n "$DOLPHIN_BIN" ] && install -m755 "$DOLPHIN_BIN" "$S/$EMU/dolphin"
if [ -n "$DOLPHIN_LIB_DIR" ]; then
  [ -d "$DOLPHIN_LIB_DIR" ] || { echo "ERROR: DOLPHIN_LIB_DIR is not a directory: $DOLPHIN_LIB_DIR" >&2; exit 1; }
  mkdir -p "$S/$EMU/lib"
  cp -a "$DOLPHIN_LIB_DIR/." "$S/$EMU/lib/"
fi
if [ -n "$DOLPHIN_BIN" ] && readelf -d "$DOLPHIN_BIN" 2>/dev/null | grep -q "libhidapi-hidraw.so.0"; then
  [ -s "$S/$EMU/lib/libhidapi-hidraw.so.0" ] || { echo "ERROR: missing bundled HIDAPI runtime; set DOLPHIN_LIB_DIR" >&2; exit 1; }
fi
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
