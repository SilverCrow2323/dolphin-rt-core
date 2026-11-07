#!/bin/sh
BASE="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE/conf/stream.conf"
OUT="$BASE/conf/latency.txt"
rm -f "$BASE/conf/latency.done"
: > "$OUT"

[ -z "$HOST" ] && { echo "ERR host not set" >> "$OUT"; touch "$BASE/conf/latency.done"; exit 1; }

if ! command -v ping >/dev/null 2>&1; then
  echo "ERR ping not available" >> "$OUT"
  touch "$BASE/conf/latency.done"; exit 1
fi

echo "Ping $HOST (10 packets, 1s timeout)" >> "$OUT"
RES=$(ping -c 10 -W 1 "$HOST" 2>&1)
echo "" >> "$OUT"
echo "$RES" | tail -3 >> "$OUT"
touch "$BASE/conf/latency.done"
