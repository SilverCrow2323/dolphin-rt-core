#!/bin/bash
# Dolphin Rt:Core R - doctor: explains why the emulator does not start. Changes nothing.
#   ./rtcore.sh doctor            full report (paste it in an issue)
#   tools/doctor.sh --brief       short version, used by the launcher when the emulator exits immediately
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
CORE="$ROOT/core"; ST="${RTCORE_STORAGE:-/storage}"; BRIEF=0; [ "${1:-}" = "--brief" ] && BRIEF=1
h()  { [ "$BRIEF" = 1 ] || { echo; echo "== $*"; }; }
say() { echo "$*"; }
full() { [ "$BRIEF" = 0 ]; }

full && { say "Dolphin Rt:Core R $(cat "$ROOT/VERSION" 2>/dev/null)   $(date '+%F %T')"; say "kernel: $(uname -srm)"; }

# ---- binary
h "emulator binary"
VERDICT=""
if [ ! -f "$CORE/dolphin" ]; then say "core/dolphin: MISSING"; VERDICT="no emulator binary in $CORE"
else
  hdr="$(head -c 20 "$CORE/dolphin" | od -An -tx1 | tr -d ' \n')"
  case "$hdr" in 7f454c46020101*b700) ARCH=aarch64;; 7f454c46020101*3e00) ARCH=x86_64;; *) ARCH=unknown;; esac
  full && say "core/dolphin: $(du -h "$CORE/dolphin" | cut -f1), ELF $ARCH, executable=$([ -x "$CORE/dolphin" ] && echo yes || echo NO)"
  [ "$ARCH" = aarch64 ] || VERDICT="core/dolphin is not an aarch64 build"
fi

# ---- shared libraries (only when this machine can run the binary)
if [ -z "$VERDICT" ] && [ "$(uname -m)" = aarch64 ]; then
  export LD_LIBRARY_PATH="$ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  MISS="$(cd "$CORE" && LD_TRACE_LOADED_OBJECTS=1 ./dolphin 2>&1 | sed -n 's/^[[:space:]]*\(lib[^ ]*\) => not found.*/\1/p' | tr '\n' ' ')"
  h "shared libraries"
  if [ -n "$MISS" ]; then say "MISSING: $MISS"; VERDICT="missing libraries: $MISS"; else say "all libraries resolved"; fi
fi

# ---- C library: the binary needs a glibc at least as new as the one it was built with
if [ -f "$CORE/dolphin" ]; then
  NEED="$(grep -a -o 'GLIBC_2\.[0-9]*' "$CORE/dolphin" 2>/dev/null | sort -uV | tail -n 1 | sed 's/GLIBC_//')"
  HAVE="$( (ldd --version 2>&1 || true) | head -n 1 | grep -o '[0-9]\+\.[0-9]\+$')"
  h "C library"
  say "binary needs glibc >= ${NEED:-?}; this system has ${HAVE:-unknown (not glibc?)}"
  if [ -n "$NEED" ] && [ -n "$HAVE" ] && [ "${NEED#2.}" -gt "${HAVE#2.}" ] 2>/dev/null; then
    [ -z "$VERDICT" ] && VERDICT="the binary needs glibc $NEED but this system only has $HAVE: build it on an older base (see dolphin-build/)"
  fi
fi

# ---- display stack
h "display stack"
SWAY=no; pidof sway >/dev/null 2>&1 && SWAY=yes
ROCKNIX_HINT=0; [ -f /etc/os-release ] && grep -qi rocknix /etc/os-release && ROCKNIX_HINT=1
say "sway (Wayland compositor) running: $SWAY    WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}    DISPLAY=${DISPLAY:-}"
say "/dev/fb0: $([ -e /dev/fb0 ] && echo present || echo absent)    /dev/dri: $(ls /dev/dri 2>/dev/null | tr '\n' ' ')"
for d in /sys/class/drm/card*/device/driver; do [ -e "$d" ] && say "GPU driver: $(basename "$(readlink -f "$d")")"; done
full && say "EGL libraries: $(ls /usr/lib/libEGL* /usr/lib64/libEGL* /usr/lib/mali* 2>/dev/null | tr '\n' ' ')"

# ---- which window platforms does this build offer?
PLAT=""
if [ -z "$VERDICT" ] && [ "$(uname -m)" = aarch64 ] && [ -x "$CORE/dolphin" ]; then
  PLAT="$(cd "$CORE" && timeout 10 ./dolphin --help 2>&1 | grep -i -A2 'platform' | tr '\n' ' ' | tr -s ' ')"
  h "window platforms offered by this emulator build"
  say "${PLAT:-(could not read --help)}"
fi
case "$PLAT" in
  *fbdev*) case "$PLAT" in *x11*|*wayland*|*drm*|*gbm*) :;; *)
    [ "$SWAY" = yes ] && VERDICT="this build can only draw through fbdev/headless, but ROCKNIX runs a Wayland compositor (sway) on the GPU: it cannot open a window here. It needs a build with a Wayland/X11/KMS platform.";;
  esac;;
esac

# ---- static scan (works on any machine, even when the binary cannot be run here)
SCAN=""
if [ -f "$CORE/dolphin" ]; then
  for pf in FBDev Headless X11 Wayland DRM KMS GBM; do grep -a -q "Platform${pf}E" "$CORE/dolphin" 2>/dev/null && SCAN="$SCAN $(echo "$pf" | tr 'A-Z' 'a-z')"; done
  h "window platforms compiled into core/dolphin (static scan)"
  say "${SCAN:- (none recognised)}"
  case " $SCAN " in
    *" x11 "*|*" wayland "*|*" drm "*|*" kms "*|*" gbm "*) :;;
    *" fbdev "*) [ -z "$VERDICT" ] && [ "$SWAY" = yes ] && VERDICT="this build can only draw through fbdev/headless, but ROCKNIX runs a Wayland compositor (sway) on the GPU: it cannot open a window here. It needs a build with a Wayland/X11/KMS platform."
                 [ -z "$VERDICT" ] && [ "$ROCKNIX_HINT" = 1 ] && VERDICT="this build can only draw through fbdev/headless; ROCKNIX normally runs sway (Wayland) on Panfrost/Mesa, where that does not work. Run this on the device while the UI is up to confirm.";;
  esac
fi

# ---- EmulationStation integration
if full; then
  h "EmulationStation"
  ESD="$ST/.emulationstation"
  say "systems : $([ -f "$ESD/es_systems_rtcore.cfg" ] && echo installed || echo "NOT installed")"
  say "features: $(grep -q 'RTCORE-R BEGIN' "$ESD/es_features.cfg" 2>/dev/null && echo "installed ($(grep -c '<feature ' "$ESD/es_features.cfg") feature entries in the file)" || echo "NOT installed")"
  h "last launch log"
  [ -f "$ROOT/logs/launch.log" ] && tail -n 25 "$ROOT/logs/launch.log" || say "(no log yet: start a game once)"
fi

h "verdict"
if [ -n "$VERDICT" ]; then say "PROBLEM: $VERDICT"; exit 1; else say "nothing obviously wrong found; read the launch log above"; exit 0; fi
