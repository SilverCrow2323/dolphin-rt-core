#!/bin/sh
# sync.sh — downloads library.tsv + covers from the PC portal into data/stream/.
. "$(dirname "$0")/paths.sh"
st="$DATA/sync.status"
need_host >"$st" || exit 1
base="http://$HOST:$SYNC_PORT"
echo "Connecting to $HOST..." > "$st"
if ! fetch "$base$SYNC_LIBRARY_PATH" "$DATA/library.new" 20; then
    rm -f "$DATA/library.new"
    echo "ERR cannot fetch $SYNC_LIBRARY_PATH from $base (is the portal running? is the path right?)" > "$st"; exit 1
fi
games=$(grep -c -E '^(gc|wii)	' "$DATA/library.new")
if [ "$games" -eq 0 ]; then
    rm -f "$DATA/library.new"; echo "ERR portal answered but sent no gc/wii games" > "$st"; exit 1
fi
mv -f "$DATA/library.new" "$DATA/library.tsv"
# 4th tab column = cover; keep only safe bare names
awk -F'\t' '/^(gc|wii)\t/ {c=$4; sub(/^covers\//,"",c); if (c ~ /^[A-Za-z0-9._-]+$/ && c !~ /\.\./) print c}' "$DATA/library.tsv" | sort -u |
while IFS= read -r c; do
    [ -s "$DATA/covers/$c" ] && continue
    if fetch "$base$SYNC_COVER_PATH$c" "$DATA/covers/$c.part" 20; then mv -f "$DATA/covers/$c.part" "$DATA/covers/$c"; else rm -f "$DATA/covers/$c.part"; fi
done
echo "OK: $games games" > "$st"
