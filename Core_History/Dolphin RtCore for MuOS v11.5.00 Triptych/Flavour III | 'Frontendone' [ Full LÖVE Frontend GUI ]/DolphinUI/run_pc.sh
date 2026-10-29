#!/bin/bash
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SELF_DIR" || exit 1
[ -f "main.lua" ] || { echo "ERR: main.lua non trovato in $SELF_DIR" >&2; exit 1; }

ARCH="$(uname -m)"
LOVE_BIN=""

# su ARM (handheld) usa il bundled; su x86_64 usa il love di sistema
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "armv8l" ]; then
    [ -x "./lib/love" ] && LOVE_BIN="./lib/love"
fi
if [ -z "$LOVE_BIN" ] && command -v love >/dev/null 2>&1; then
    LOVE_BIN="love"
fi
if [ -z "$LOVE_BIN" ]; then
    echo "ERR: love non trovato." >&2
    echo "     su PC:  sudo apt install love" >&2
    echo "     su ARM: ./lib/love non eseguibile (arch=$ARCH)" >&2
    exit 1
fi

export DOLPHINUI_FPS="${DOLPHINUI_FPS:-60}"
echo "[rtui] arch=$ARCH  bin=$LOVE_BIN  dir=$(pwd)"
"$LOVE_BIN" . 2>&1 | tee /tmp/rtui_last.log
RC=${PIPESTATUS[0]}
echo ""; echo "[rtui] exit $RC  (log: /tmp/rtui_last.log)"
exit "$RC"
