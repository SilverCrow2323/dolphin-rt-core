#!/bin/bash
# Dolphin Rt:UI — ROCKNIX controller-first per-game settings app
set -u

SELF="$(readlink -f "$0")"
ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
APP_DIR="$ROOT/ui/gui"
PLATFORM="rocknix"
case "$PLATFORM" in
  knulli)  USERDATA="${RTCORE_USERDATA:-/userdata}" ;;
  rocknix) USERDATA="${RTCORE_USERDATA:-/storage}" ;;
  *) echo "[Dolphin Rt:UI] unsupported platform: $PLATFORM" >&2; exit 2 ;;
esac

ROM_ROOT="${RTCORE_ROM_ROOT:-$USERDATA/roms}"
if [ "$PLATFORM" = rocknix ]; then
  CONF="${RTCORE_CONF:-$USERDATA/.config/system/configs/system.cfg}"
else
  CONF="${RTCORE_CONF:-$USERDATA/system/batocera.conf}"
fi

export RTCORE_PORT_ROOT="$ROOT"
export RTCORE_PLATFORM="$PLATFORM"
export RTCORE_USERDATA="$USERDATA"
export RTCORE_ROM_ROOT="$ROM_ROOT"
export RTCORE_CONF="$CONF"

# PortMaster supplies one shared LÖVE runtime. Never bundle a duplicate copy
# into this port: use the runtime already installed by the user's PortMaster.
controlfolder="${PORTMASTER_CONTROL_DIR:-}"
candidates=(
  "$controlfolder"
  "$USERDATA/roms/ports/PortMaster"
  "$USERDATA/roms/tools/PortMaster"
  "/roms/ports/PortMaster"
  "/roms/tools/PortMaster"
  "/userdata/roms/ports/PortMaster"
  "/storage/roms/ports/PortMaster"
  "/opt/system/Tools/PortMaster"
  "${HOME:-/userdata}/.local/share/PortMaster"
)
controlfolder=""
for candidate in "${candidates[@]}"; do
  [ -n "$candidate" ] && [ -s "$candidate/control.txt" ] || continue
  controlfolder="$candidate"
  break
done

if [ -z "$controlfolder" ]; then
  echo "[Dolphin Rt:UI] PortMaster was not found." >&2
  echo "Install PortMaster, then install its shared LÖVE 11.5 runtime." >&2
  exit 1
fi

# control.txt defines pm_finish/get_controls and platform variables.
# love_11.5/love.txt defines LOVE_RUN and LOVE_BINARY for this device.
. "$controlfolder/control.txt"
if command -v get_controls >/dev/null 2>&1; then get_controls; fi

LOVE_RUNTIME="$controlfolder/runtimes/love_11.5/love.txt"
if [ ! -s "$LOVE_RUNTIME" ]; then
  echo "[Dolphin Rt:UI] Missing PortMaster LÖVE 11.5 runtime: $LOVE_RUNTIME" >&2
  echo "Install the shared Love 11.5 runtime from PortMaster and retry." >&2
  exit 1
fi
. "$LOVE_RUNTIME"

if [ -z "${LOVE_RUN:-}" ]; then
  echo "[Dolphin Rt:UI] PortMaster did not define LOVE_RUN." >&2
  exit 1
fi

if [ -n "${LOVE_BINARY:-}" ] && command -v pm_platform_helper >/dev/null 2>&1; then
  pm_platform_helper "$LOVE_BINARY"
fi

cd "$APP_DIR" || exit 1
# PortMaster's runtime launcher can be a command plus flags; keep its standard
# invocation convention (unquoted LOVE_RUN) and pass all app arguments through.
$LOVE_RUN "$APP_DIR" "$@"
RESULT=$?

if command -v pm_finish >/dev/null 2>&1; then pm_finish; fi
exit "$RESULT"
