#!/bin/bash
# Dolphin Rt:Stream — desktop launcher (MX Linux XFCE)
# Opens the GUI in a 640x480 window. Does not touch mux_launch.sh (muOS only).
set -e
cd "$(dirname "$0")"

export DOLPHINSTREAM_WINDOWED=1
# fallback to system love (does not use the muOS shim binary)
LOVE_BIN="$(command -v love || echo '')"
if [ -z "$LOVE_BIN" ]; then
  echo "ERROR: love not found. sudo apt install love" >&2
  exit 1
fi

echo "[desktop] love: $LOVE_BIN"
echo "[desktop] folder: $(pwd)"
echo "[desktop] starting GUI (windowed 640x480)..."
exec "$LOVE_BIN" gui "$@"
