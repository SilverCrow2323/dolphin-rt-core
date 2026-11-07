#!/bin/sh
BASE="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE/conf/stream.conf"
OUT="$BASE/conf/wake.txt"
rm -f "$BASE/conf/wake.done"
: > "$OUT"

[ -z "$MAC" ] && { echo "ERR MAC not set in stream.conf" >> "$OUT"; touch "$BASE/conf/wake.done"; exit 1; }

if command -v etherwake >/dev/null 2>&1; then
  etherwake "$MAC" >> "$OUT" 2>&1
elif command -v wakeonlan >/dev/null 2>&1; then
  wakeonlan "$MAC" >> "$OUT" 2>&1
else
  echo "ERR need etherwake or wakeonlan (sudo apt install etherwake)" >> "$OUT"
  touch "$BASE/conf/wake.done"; exit 1
fi

echo "Wake packet sent, waiting 5s..." >> "$OUT"
sleep 5
if ping -c 1 -W 1 "$HOST" >/dev/null 2>&1; then
  echo "OK PC is up" >> "$OUT"
else
  echo "WARN PC still down after 5s" >> "$OUT"
fi
touch "$BASE/conf/wake.done"
