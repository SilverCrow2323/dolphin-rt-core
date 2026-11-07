#!/bin/sh
# Downloads library.tsv + covers from the PC (library server)
BASE="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE/conf/stream.conf"
URL="http://$HOST:$SYNC_PORT"
STATUS="$BASE/conf/sync.status"
status() { echo "$1" > "$STATUS"; }
finish() { touch "$BASE/conf/sync.done"; }

fetch() {
  if command -v wget >/dev/null 2>&1; then wget -q -T 10 -O "$2" "$1"
  else curl -fsS -m 10 -o "$2" "$1"; fi
}

rm -f "$BASE/conf/sync.done"
if [ -z "$HOST" ]; then
  status "ERR: host not set"
  finish; exit 1
fi
status "Connecting to $HOST:$SYNC_PORT"
mkdir -p "$BASE/covers"

if ! fetch "$URL/library.tsv" "$BASE/conf/library.tmp"; then
  rm -f "$BASE/conf/library.tmp"
  status "ERR: PC unreachable"
  finish; exit 1
fi
mv "$BASE/conf/library.tmp" "$BASE/conf/library.tsv"

total=$(grep -v '^#' "$BASE/conf/library.tsv" | grep -c .)
n=0
grep -v '^#' "$BASE/conf/library.tsv" | cut -f4 | while IFS= read -r cov; do
  n=$((n + 1))
  case "$cov" in
    *..*|"") continue ;;
    covers/*) ;;
    *) continue ;;
  esac
  [ -f "$BASE/$cov" ] || { fetch "$URL/$cov" "$BASE/$cov.tmp" && mv "$BASE/$cov.tmp" "$BASE/$cov" || rm -f "$BASE/$cov.tmp"; }
  status "Covers $n/$total"
done

sh "$BASE/tools/profiles.sh" >/dev/null 2>&1
status "OK: $total games"
finish
