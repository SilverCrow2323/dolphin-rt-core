#!/usr/bin/env bash
# Builds the Dolphin no-GUI binary for an aarch64 handheld.  Run it ON an aarch64 Debian/Ubuntu machine (or in the CI job).
#
#   ./build-dolphin.sh --target rocknix            # Wayland window platform (ROCKNIX patches 000,011,012,013,015)
#   ./build-dolphin.sh --target fbdev              # same feature set as the existing muOS/Knulli binary (fbdev + headless)
#   options: --ref SHA   --out DIR   --jobs N   --no-lto   --tune cortex-a53|none   --deps   --no-deps
#
# Output (in --out, default ./out): dolphin, BUILDINFO.txt, source-<ref>.tar.xz  (the GPL "corresponding source")
#
# STATUS: the patch series and the new Wayland sources are verified (see verify-patches.sh); a full build has NOT been run
# yet. The first run may need dependency tweaks: BUILDINFO.txt and the log tell you what.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REF="$(tr -d '[:space:]' < "$HERE/DOLPHIN_REF")"; TARGET=""; OUT="$PWD/out"; JOBS="$(nproc)"; LTO=ON; TUNE=cortex-a53; DEPS=auto
while [ $# -gt 0 ]; do case "$1" in
  --target) TARGET="$2"; shift 2;; --ref) REF="$2"; shift 2;; --out) OUT="$2"; shift 2;; --jobs) JOBS="$2"; shift 2;;
  --no-lto) LTO=OFF; shift;; --tune) TUNE="$2"; shift 2;; --deps) DEPS=yes; shift;; --no-deps) DEPS=no; shift;;
  *) echo "unknown option $1"; exit 2;; esac; done
case "$TARGET" in rocknix|fbdev) ;; *) echo "usage: $0 --target rocknix|fbdev [options]"; exit 2;; esac
[ "$(uname -m)" = aarch64 ] || echo "WARNING: this is $(uname -m), the result will not run on the handheld"

if [ "$DEPS" = yes ] || { [ "$DEPS" = auto ] && [ "$(id -u)" = 0 ] && command -v apt-get >/dev/null; }; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends build-essential cmake ninja-build git patch pkg-config python3 ca-certificates xz-utils \
    libevdev-dev libudev-dev libusb-1.0-0-dev libpulse-dev libasound2-dev libcurl4-openssl-dev liblzo2-dev libzstd-dev liblzma-dev \
    libpng-dev zlib1g-dev libbz2-dev libegl-dev libgles-dev libgl-dev libdrm-dev libbluetooth-dev libhidapi-dev libxi-dev \
    libwayland-dev wayland-protocols libxkbcommon-dev libdecor-0-dev
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

FLAGS=(-DCMAKE_BUILD_TYPE=Release -DENABLE_NOGUI=ON -DENABLE_QT=OFF -DENABLE_HEADLESS=OFF -DENABLE_TESTS=OFF
  -DENABLE_ANALYTICS=OFF -DENABLE_AUTOUPDATE=OFF -DENABLE_CLI_TOOL=OFF -DENCODE_FRAMEDUMPS=OFF -DUSE_DISCORD_PRESENCE=OFF
  -DUSE_MGBA=OFF -DUSE_RETRO_ACHIEVEMENTS=OFF -DENABLE_LLVM=OFF -DENABLE_VULKAN=OFF "-DENABLE_LTO=$LTO"
  -DENABLE_EVDEV=ON -DENABLE_SDL=ON -DENABLE_ALSA=ON -DENABLE_PULSEAUDIO=ON -DENABLE_EGL=ON -DENABLE_X11=OFF
  -DLINUX_LOCAL_DEV=OFF -DBUILD_SHARED_LIBS=OFF -DMBEDTLS_FATAL_WARNINGS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DDISTRIBUTOR=Rt:Core)
[ "$TARGET" = rocknix ] && FLAGS+=(-DENABLE_WAYLAND=ON) || FLAGS+=(-DENABLE_WAYLAND=OFF)
if [ "$TUNE" != none ]; then   # tune only (no new instructions), so the binary still runs on every aarch64 core
  FLAGS+=("-DCMAKE_C_FLAGS=-mtune=$TUNE" "-DCMAKE_CXX_FLAGS=-mtune=$TUNE"); fi

cmake -S . -B build -G Ninja "${FLAGS[@]}"
cmake --build build --target dolphin-nogui -j"$JOBS"
BIN="$SRC/build/Binaries/dolphin-emu-nogui"; [ -x "$BIN" ] || { echo "dolphin-emu-nogui was not produced at $BIN"; find "$SRC/build" -type f -perm -u+x -name "*nogui*" -print; exit 1; }
cp "$BIN" "$OUT/dolphin"; strip --strip-unneeded "$OUT/dolphin" 2>/dev/null || true; chmod 755 "$OUT/dolphin"

{
  echo "Dolphin Rt:Core build"; echo "date:      $(date -u '+%F %T') UTC"; echo "target:    $TARGET"
  echo "upstream:  $(git -C "$SRC" log -1 --format='%H %ad' --date=short)"
  echo "compiler:  $(c++ --version | head -n 1)"; echo "tune/lto:  $TUNE / $LTO"; echo "host:      $(uname -srm)"
  echo; echo "patches (sha256):"; for p in "${PATCHES[@]}"; do echo "  $(sha256sum "$p" | cut -c1-16)  $(basename "$p")"; done
  echo; echo "cmake flags:"; printf '  %s\n' "${FLAGS[@]}"
  echo; echo "binary: $(du -h "$OUT/dolphin" | cut -f1)  sha256 $(sha256sum "$OUT/dolphin" | cut -d' ' -f1)"
  echo "needed libraries:"; readelf -d "$OUT/dolphin" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/  \1/p'
  echo "needs glibc >= $(strings -n 6 "$OUT/dolphin" | grep -o 'GLIBC_2\.[0-9]*' | sort -uV | tail -n 1)"
  echo "window platforms: $(timeout 20 "$OUT/dolphin" --help 2>&1 | grep -i -A2 'platform' | tr '\n' ' ' | tr -s ' ' || true)"
  echo "version: $(timeout 20 "$OUT/dolphin" --version 2>&1 | head -n 1 || true)"
} > "$OUT/BUILDINFO.txt"

# GPL: the exact source this binary was built from (sources + our patches + this script), not the build tree
tar --exclude=.git --exclude=build -C "$W" -cJf "$OUT/source-${REF:0:12}.tar.xz" dolphin -C "$HERE/.." dolphin-build
cat "$OUT/BUILDINFO.txt"; echo; echo "done: $OUT/dolphin  $OUT/BUILDINFO.txt  $OUT/source-${REF:0:12}.tar.xz"
