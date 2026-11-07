#!/bin/sh
# test.sh — connection test (portal + Sunshine)
. "$(dirname "$0")/paths.sh"
out="$DATA/test.txt"
{
need_host || exit 0
for t in "Portal|http://$HOST:$SYNC_PORT/library.tsv" "Sunshine|http://$HOST:47989/serverinfo"; do
    name="${t%%|*}"; url="${t#*|}"
    if fetch "$url" /dev/null 4 2>/dev/null; then echo "OK    $name  ($url)"; else echo "FAIL  $name  ($url)"; fi
done
} 2>&1 | atomic_write "$out"
