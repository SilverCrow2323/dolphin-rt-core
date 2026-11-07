#!/bin/sh
BASE="$(cd "$(dirname "$0")/.." && pwd)"
export LOVEDIR="$BASE"
. "$BASE/tools/paths.sh"

. "$BASE/conf/stream.conf"
LOG="$BASE/conf/pair.log"
: > "$LOG"
mkdir -p "$KEYDIR"

if [ -z "$HOST" ]; then
    echo "ERR Host not set (START > Streaming > PC host)" >> "$LOG"
    exit 1
fi
cd "$MOONDIR" || { echo "ERR moonlight folder not found ($MOONDIR)" >> "$LOG"; exit 1; }

if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL -eL ./moonlight pair -keydir "$KEYDIR" "$HOST" >> "$LOG" 2>&1 &
else
    ./moonlight pair -keydir "$KEYDIR" "$HOST" >> "$LOG" 2>&1 &
fi
echo $! > "$BASE/conf/pair.pid"
wait $!
RC=$?
rm -f "$BASE/conf/pair.pid"
if [ "$RC" -eq 0 ]; then echo "OK  Pairing complete" >> "$LOG"
else echo "ERR Pairing ended (code $RC)" >> "$LOG"; fi
