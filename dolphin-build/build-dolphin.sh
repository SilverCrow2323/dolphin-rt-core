#!/usr/bin/env bash
# Builds the Dolphin no-GUI binary for an aarch64 handheld.  Run it ON an aarch64 Debian/Ubuntu machine (or in the CI job).
#
#   ./build-dolphin.sh --target muos                # muOS Andromeda / H700 (FBDev + SDL/EGL, NoGUI)
#   ./build-dolphin.sh --target muos-qt --frontend gui # EXPERIMENTAL: Qt GUI on EGLFS
#   ./build-dolphin.sh --target knulli              # Knulli / H700 (fbdev + SDL/EGL, no Qt)
#   ./build-dolphin.sh --target rocknix             # ROCKNIX Wayland (patches 000,011,012,013,015)
#   ./build-dolphin.sh --target desktop --frontend both  # ARM64 Linux Qt GUI + NoGUI
#   options: --frontend nogui|gui|both --ref SHA --out DIR --jobs N --no-lto --tune cortex-a53|none --deps --no-deps
#
# Output (in --out, default ./out): dolphin, BUILDINFO.txt, source-<ref>.tar.xz;
# Handheld targets also include a relocatable Sys/ directory next to the binary.
#
# STATUS: patch validation is provided by verify-patches.sh. The native ARM64 CI build is the authoritative
# build/test path; output discovery expects upstream's Binaries/dolphin-emu-nogui executable.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REF="$(tr -d '[:space:]' < "$HERE/DOLPHIN_REF")"; TARGET=""; FRONTEND=nogui; OUT="$PWD/out"; JOBS="$(nproc)"; LTO=ON; TUNE=cortex-a53; DEPS=auto
while [ $# -gt 0 ]; do case "$1" in
  --target) TARGET="$2"; shift 2;; --frontend) FRONTEND="$2"; shift 2;; --ref) REF="$2"; shift 2;; --out) OUT="$2"; shift 2;; --jobs) JOBS="$2"; shift 2;;
  --no-lto) LTO=OFF; shift;; --tune) TUNE="$2"; shift 2;; --deps) DEPS=yes; shift;; --no-deps) DEPS=no; shift;;
  *) echo "unknown option $1"; exit 2;; esac; done
case "$TARGET" in muos|muos-qt|knulli|fbdev|rocknix|desktop) ;; *) echo "usage: $0 --target muos|knulli|rocknix|desktop [options]"; exit 2;; esac
case "$FRONTEND" in nogui|gui|both) ;; *) echo "usage: $0 --target TARGET --frontend nogui|gui|both"; exit 2;; esac
if [ "$TARGET" = muos-qt ] && [ "$FRONTEND" != gui ]; then echo "muos-qt is a GUI-only experimental target"; exit 2; fi
if [ "$TARGET" != desktop ] && [ "$TARGET" != muos-qt ] && [ "$FRONTEND" != nogui ]; then echo "Qt GUI builds are supported only by desktop and experimental muos-qt"; exit 2; fi
# Every packaged handheld target installs Sys/ beside its Dolphin executable:
# muOS: /opt/muos/share/emulator/dolphin/Sys
# Knulli/ROCKNIX: <release>/core/Sys
# Make all firmware binaries resolve the colocated resources rather than the
# host's compiled /usr/local/share/dolphin-emu/sys path.
LOCAL_SYS=OFF
case "$TARGET" in muos|muos-qt|knulli|fbdev|rocknix) LOCAL_SYS=ON;; esac
[ "$(uname -m)" = aarch64 ] || echo "WARNING: this is $(uname -m), the result will not run on the handheld"

if [ "$DEPS" = yes ] || { [ "$DEPS" = auto ] && [ "$(id -u)" = 0 ] && command -v apt-get >/dev/null; }; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends build-essential cmake ninja-build git patch pkg-config python3 ca-certificates xz-utils \
    libevdev-dev libudev-dev libusb-1.0-0-dev libpulse-dev libasound2-dev libcurl4-openssl-dev liblzo2-dev libzstd-dev liblzma-dev \
    libpng-dev zlib1g-dev libbz2-dev libegl-dev libgles-dev libgl-dev libdrm-dev libbluetooth-dev libhidapi-dev libxi-dev \
    libwayland-dev wayland-protocols libxkbcommon-dev libdecor-0-dev
  if [ "$TARGET" = desktop ] || [ "$TARGET" = muos-qt ]; then apt-get install -y -qq --no-install-recommends qt6-base-dev qt6-base-private-dev libqt6svg6-dev qt6-qpa-plugins; fi
fi

W="$OUT/work"; SRC="$W/dolphin"; rm -rf "$W"; mkdir -p "$SRC" "$OUT"; cd "$SRC"
git init -q; git remote add origin https://github.com/dolphin-emu/dolphin.git
git fetch -q --depth 1 origin "$REF"; git checkout -q FETCH_HEAD
git submodule update --init --depth 1 --recursive >/dev/null
echo "upstream: $(git log -1 --format='%H %ad' --date=short)"

PATCHES=()
[ "$TARGET" = rocknix ] && for p in "$HERE"/patches/rocknix-wayland/*.patch; do PATCHES+=("$p"); done
for p in "$HERE"/patches/local/*.patch; do [ -f "$p" ] && PATCHES+=("$p"); done
for p in "${PATCHES[@]}"; do patch -p1 -s < "$p" && echo "applied $(basename "$p")"; done

ENABLE_QT=OFF; ENABLE_X11=OFF; ENABLE_WAYLAND=OFF
case "$TARGET" in desktop) ENABLE_QT=ON; ENABLE_X11=ON;; muos-qt) ENABLE_QT=ON;; rocknix) ENABLE_WAYLAND=ON;; esac
FLAGS=(-DCMAKE_BUILD_TYPE=Release -DENABLE_NOGUI=ON "-DENABLE_QT=$ENABLE_QT" -DENABLE_HEADLESS=OFF -DENABLE_TESTS=OFF
  -DENABLE_ANALYTICS=OFF -DENABLE_AUTOUPDATE=OFF -DENABLE_CLI_TOOL=OFF -DENCODE_FRAMEDUMPS=OFF -DUSE_DISCORD_PRESENCE=OFF
  -DUSE_MGBA=OFF -DUSE_RETRO_ACHIEVEMENTS=OFF -DENABLE_LLVM=OFF -DENABLE_VULKAN=OFF "-DENABLE_LTO=$LTO"
  -DENABLE_EVDEV=ON -DENABLE_SDL=ON -DENABLE_ALSA=ON -DENABLE_PULSEAUDIO=ON -DENABLE_EGL=ON "-DENABLE_X11=$ENABLE_X11"
  "-DLINUX_LOCAL_DEV=$LOCAL_SYS" -DBUILD_SHARED_LIBS=OFF -DMBEDTLS_FATAL_WARNINGS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DDISTRIBUTOR=Rt:Core)
FLAGS+=("-DENABLE_WAYLAND=$ENABLE_WAYLAND")
if [ "$TUNE" != none ]; then   # tune only (no new instructions), so the binary still runs on every aarch64 core
  FLAGS+=("-DCMAKE_C_FLAGS=-mtune=$TUNE" "-DCMAKE_CXX_FLAGS=-mtune=$TUNE"); fi

cmake -S . -B build -G Ninja "${FLAGS[@]}"
if [ "$FRONTEND" = nogui ] || [ "$FRONTEND" = both ]; then
  cmake --build build --target dolphin-nogui -j"$JOBS"
  BIN="$SRC/build/Binaries/dolphin-emu-nogui"; [ -x "$BIN" ] || { echo "dolphin-emu-nogui was not produced at $BIN"; find "$SRC/build" -type f -perm -u+x -name "*nogui*" -print; exit 1; }
  cp "$BIN" "$OUT/dolphin"; strip --strip-unneeded "$OUT/dolphin" 2>/dev/null || true; chmod 755 "$OUT/dolphin"
  [ "$FRONTEND" != both ] || cp "$OUT/dolphin" "$OUT/dolphin-nogui"
fi
if [ "$FRONTEND" = gui ] || [ "$FRONTEND" = both ]; then
  cmake --build build --target dolphin-emu -j"$JOBS"
  BIN="$SRC/build/Binaries/dolphin-emu"; [ -x "$BIN" ] || { echo "dolphin-emu Qt GUI was not produced at $BIN"; exit 1; }
  cp "$BIN" "$OUT/dolphin-gui"; strip --strip-unneeded "$OUT/dolphin-gui" 2>/dev/null || true; chmod 755 "$OUT/dolphin-gui"
fi

# A relocatable firmware binary resolves its system resources from <exe-dir>/Sys.
# Ship the exact Sys data from the same upstream revision used for this build.
# muOS does not ship HIDAPI on every firmware image. Dolphin links the hidraw
# backend when ENABLE_EVDEV is enabled, so bundle the matching runtime SONAME.
if [ "$TARGET" = muos ] || [ "$TARGET" = muos-qt ]; then
  HIDAPI_SOURCE="$(ldconfig -p 2>/dev/null | awk '/libhidapi-hidraw\.so\.0 / {print $NF; exit}')"
  if [ -z "$HIDAPI_SOURCE" ]; then
    HIDAPI_SOURCE="$(find /usr/lib /lib -type f -name 'libhidapi-hidraw.so.0*' -print -quit 2>/dev/null || true)"
  fi
  [ -n "$HIDAPI_SOURCE" ] && [ -f "$HIDAPI_SOURCE" ] || {
    echo "missing build dependency: libhidapi-hidraw.so.0 (install libhidapi-dev)" >&2; exit 1;
  }
  readelf -h "$HIDAPI_SOURCE" | grep -q 'Machine:.*AArch64' || {
    echo "HIDAPI runtime library is not AArch64: $HIDAPI_SOURCE" >&2; exit 1;
  }
  mkdir -p "$OUT/lib"
  install -m755 "$(readlink -f "$HIDAPI_SOURCE")" "$OUT/lib/libhidapi-hidraw.so.0"
fi

if [ "$LOCAL_SYS" = ON ]; then
  [ -d "$SRC/Data/Sys" ] || { echo "missing upstream resource directory: $SRC/Data/Sys"; exit 1; }
  # Recreate the resource tree so rerunning into an existing output directory
  # cannot leave stale files from a different Dolphin revision.
  rm -rf "$OUT/Sys"
  mkdir -p "$OUT/Sys"
  cp -a "$SRC/Data/Sys/." "$OUT/Sys/"
  for asset in GC/font_western.bin GC/font_japanese.bin GC/dsp_rom.bin GC/dsp_coef.bin Resources/OSD_Font.ttf; do
    [ -s "$OUT/Sys/$asset" ] || { echo "missing required Sys resource: $OUT/Sys/$asset"; exit 1; }
  done
fi

{
  echo "Dolphin Rt:Core build"; echo "date:      $(date -u '+%F %T') UTC"; echo "target:    $TARGET"; echo "frontend:  $FRONTEND"
  echo "upstream:  $(git -C "$SRC" log -1 --format='%H %ad' --date=short)"
  echo "compiler:  $(c++ --version | head -n 1)"; echo "tune/lto:  $TUNE / $LTO"; echo "host:      $(uname -srm)"; echo "relocatable Sys: $LOCAL_SYS"
  echo; echo "patches (sha256):"; for p in "${PATCHES[@]}"; do echo "  $(sha256sum "$p" | cut -c1-16)  $(basename "$p")"; done
  echo; echo "cmake flags:"; printf '  %s\n' "${FLAGS[@]}"
  for b in "$OUT/dolphin" "$OUT/dolphin-gui"; do [ -x "$b" ] || continue; echo; echo "binary: $(basename "$b") $(du -h "$b" | cut -f1) sha256 $(sha256sum "$b" | cut -d' ' -f1)"; echo "needed libraries:"; readelf -d "$b" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/  \1/p'; echo "needs glibc >= $(strings -n 6 "$b" | grep -o 'GLIBC_2\.[0-9]*' | sort -uV | tail -n 1)"; done
  PROBE="$OUT/dolphin"; [ -x "$PROBE" ] || PROBE="$OUT/dolphin-gui"
  echo "window platforms: $(timeout 20 "$PROBE" --help 2>&1 | grep -i -A2 'platform' | tr '\n' ' ' | tr -s ' ' || true)"
  echo "version: $(timeout 20 "$PROBE" --version 2>&1 | head -n 1 || true)"
} > "$OUT/BUILDINFO.txt"

# GPL: the exact source this binary was built from (sources + our patches + this script), not the build tree
tar --exclude=.git --exclude=build -C "$W" -cJf "$OUT/source-${REF:0:12}.tar.xz" dolphin -C "$HERE/.." dolphin-build
cat "$OUT/BUILDINFO.txt"; echo; echo "done: $OUT/dolphin*  $OUT/Sys  $OUT/BUILDINFO.txt  $OUT/source-${REF:0:12}.tar.xz"
