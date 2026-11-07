#!/bin/sh
# Downloads the controller profiles from the PC into conf/profiles.tsv (conf/profiles.done marks the end).
BASE="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE/conf/stream.conf"
rm -f "$BASE/conf/profiles.done"
if [ -n "$HOST" ]; then
  URL="http://$HOST:$SYNC_PORT/profiles.tsv"
  if command -v wget >/dev/null 2>&1; then wget -q -T 8 -O "$BASE/conf/profiles.tmp" "$URL" 2>/dev/null
  else curl -fsS -m 8 -o "$BASE/conf/profiles.tmp" "$URL" 2>/dev/null; fi
  if [ -s "$BASE/conf/profiles.tmp" ] && head -n 1 "$BASE/conf/profiles.tmp" | grep -q '^# profiles.tsv'; then
    mv "$BASE/conf/profiles.tmp" "$BASE/conf/profiles.tsv"
  else
    rm -f "$BASE/conf/profiles.tmp"
  fi
fi
touch "$BASE/conf/profiles.done"
