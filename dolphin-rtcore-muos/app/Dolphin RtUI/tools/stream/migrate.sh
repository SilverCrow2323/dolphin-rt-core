#!/bin/sh
# migrate.sh — one-time import from a previously installed standalone "Dolphin RtStream" app:
# host/port settings, library, covers and Moonlight pairing keys (so you do not pair again).
# Only copies; never touches the old app; validates the config like the UI does.
. "$(dirname "$0")/paths.sh"
[ -e "$DATA/.migrated" ] && exit 0
STORE="${MUOS_STORE_DIR:-/run/muos/storage}"
OLD=""
for d in "$STORE/application/Dolphin RtStream" "$STORE/application/Dolphin RtStream"*; do
    [ -f "$d/conf/stream.conf" ] && { OLD="$d"; break; }
done
if [ -n "$OLD" ]; then
    if [ ! -s "$DATA/stream.conf" ] && ! grep -v -E '^(#.*|[A-Z_]+="[A-Za-z0-9.:_ -]*"|)$' "$OLD/conf/stream.conf" | grep -q .; then
        cp "$OLD/conf/stream.conf" "$DATA/stream.conf"
    fi
    [ -s "$DATA/library.tsv" ] || { [ -f "$OLD/conf/library.tsv" ] && cp "$OLD/conf/library.tsv" "$DATA/library.tsv"; }
    if [ -d "$OLD/covers" ]; then
        for f in "$OLD"/covers/*.png; do
            [ -f "$f" ] || continue; b="$(basename "$f")"
            case "$b" in *[!A-Za-z0-9._-]*) continue ;; esac
            [ -e "$DATA/covers/$b" ] || cp "$f" "$DATA/covers/$b"
        done
    fi
    if [ -d "$OLD/keys" ] && [ -z "$(ls -A "$DATA/keys" 2>/dev/null)" ]; then
        cp -p "$OLD"/keys/* "$DATA/keys/" 2>/dev/null
        chmod 600 "$DATA"/keys/* 2>/dev/null
    fi
    echo "imported from $OLD" > "$DATA/.migrated"
else
    echo "nothing to import" > "$DATA/.migrated"
fi
