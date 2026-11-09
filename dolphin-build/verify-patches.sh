#!/usr/bin/env bash
# Checks (without building Dolphin) that the Wayland patch series still applies to the pinned upstream commit and that the
# new C++ files compile (syntax only) against the real Wayland headers.
#   ./verify-patches.sh [--ref SHA] [--syntax]      (--syntax needs libwayland-dev wayland-protocols libegl-dev g++)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REF="$(tr -d '[:space:]' < "$HERE/DOLPHIN_REF")"; SYNTAX=0
while [ $# -gt 0 ]; do case "$1" in --ref) REF="$2"; shift 2;; --syntax) SYNTAX=1; shift;; *) echo "unknown option $1"; exit 2;; esac; done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; S="$W/dolphin"; mkdir -p "$S"; cd "$S"
git init -q; git remote add origin https://github.com/dolphin-emu/dolphin.git
git fetch -q --depth 1 origin "$REF"; git checkout -q FETCH_HEAD
echo "upstream: $(git log -1 --format='%h %ad %s' --date=short | cut -c1-80)"
fail=0
for p in "$HERE"/patches/rocknix-wayland/*.patch; do
  if patch -p1 --dry-run -s < "$p" >/dev/null 2>&1; then patch -p1 -s < "$p"; echo "  applies  $(basename "$p")"; else echo "  FAILS    $(basename "$p")"; fail=1; break; fi
done
[ $fail -eq 0 ] || exit 1
grep -q 'ENABLE_WAYLAND' CMakeLists.txt && echo "  ok       ENABLE_WAYLAND option present" || { echo "  FAILS    ENABLE_WAYLAND missing"; exit 1; }
[ -f Source/Core/DolphinNoGUI/PlatformWayland.cpp ] && echo "  ok       PlatformWayland.cpp added" || { echo "  FAILS    PlatformWayland.cpp missing"; exit 1; }
if [ $SYNTAX -eq 1 ]; then
  git submodule update --init --depth 1 Externals/fmt/fmt >/dev/null 2>&1
  WP="$(pkg-config --variable=pkgdatadir wayland-protocols)"; G="$W/gen"; mkdir -p "$G"
  for x in "stable/xdg-shell/xdg-shell.xml xdg-shell" "unstable/xdg-decoration/xdg-decoration-unstable-v1.xml xdg-decoration" "staging/fractional-scale/fractional-scale-v1.xml fractional-scale" "stable/viewporter/viewporter.xml viewporter"; do
    set -- $x; wayland-scanner client-header "$WP/$1" "$G/wayland-$2-client-protocol.h"; done
  FL="-std=c++23 -fsyntax-only -DHAVE_WAYLAND=1 -DHAVE_X11=0 -DUSE_EGL=1 -I$G -ISource/Core -IExternals/fmt/fmt/include -IExternals/imgui/imgui -IExternals/imgui -IExternals/Vulkan/Include $(pkg-config --cflags wayland-client wayland-egl egl)"
  for f in Source/Core/DolphinNoGUI/PlatformWayland.cpp Source/Core/Common/GL/GLInterface/EGLWayland.cpp Source/Core/Common/GL/GLContext.cpp; do
    if g++ $FL "$f" 2>"$W/err.txt"; then echo "  syntax   OK  $f"; else echo "  syntax   ERR $f"; head -3 "$W/err.txt"; fail=1; fi
  done
fi
[ $fail -eq 0 ] && echo "verify-patches: OK" || { echo "verify-patches: FAILED"; exit 1; }
