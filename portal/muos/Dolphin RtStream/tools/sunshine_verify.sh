#!/bin/sh
# sunshine_verify.sh - compare Sunshine app list with local library.tsv
# POSIX sh: no process substitution, works on dash/busybox
BASE="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE/conf/stream.conf"
OUT="$BASE/conf/sunshine_verify.txt"
DONE="$BASE/conf/sunshine_verify.done"
rm -f "$DONE"
: > "$OUT"

[ -z "$HOST" ] && { echo "ERR host not set" >> "$OUT"; touch "$DONE"; exit 1; }

TMP_JSON="$BASE/conf/.applist.json"
TMP_SUN="$BASE/conf/.sunshine_apps.txt"
TMP_LIB="$BASE/conf/.library_apps.txt"
TMP_ONLY_SUN="$BASE/conf/.only_sun.txt"
TMP_ONLY_LIB="$BASE/conf/.only_lib.txt"
TMP_BOTH="$BASE/conf/.both.txt"

URL="http://$HOST:47989/applist"
if command -v wget >/dev/null 2>&1; then
    wget -q -T 8 -O "$TMP_JSON" "$URL" 2>/dev/null
else
    curl -fsS -m 8 -o "$TMP_JSON" "$URL" 2>/dev/null
fi

if [ ! -s "$TMP_JSON" ]; then
    echo "ERR Sunshine not reachable on 47989" >> "$OUT"
    rm -f "$TMP_JSON"; touch "$DONE"; exit 1
fi

grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' "$TMP_JSON" \
    | sed 's/.*"\([^"]*\)"$/\1/' | sort -u > "$TMP_SUN"
rm -f "$TMP_JSON"

if [ -f "$BASE/conf/library.tsv" ]; then
    grep -v '^#' "$BASE/conf/library.tsv" | cut -f3 | sort -u > "$TMP_LIB"
else
    : > "$TMP_LIB"
fi

comm -23 "$TMP_SUN" "$TMP_LIB" > "$TMP_ONLY_SUN" 2>/dev/null || true
comm -13 "$TMP_SUN" "$TMP_LIB" > "$TMP_ONLY_LIB" 2>/dev/null || true
comm -12 "$TMP_SUN" "$TMP_LIB" > "$TMP_BOTH" 2>/dev/null || true

echo "# App in Sunshine but NOT in library (available to play)" >> "$OUT"
[ -s "$TMP_ONLY_SUN" ] && sed 's/^/  + /' "$TMP_ONLY_SUN" >> "$OUT" || echo "  (none)" >> "$OUT"
echo "" >> "$OUT"
echo "# App in library but NOT in Sunshine (play will FAIL)" >> "$OUT"
[ -s "$TMP_ONLY_LIB" ] && sed 's/^/  - /' "$TMP_ONLY_LIB" >> "$OUT" || echo "  (none)" >> "$OUT"
echo "" >> "$OUT"
echo "# Matching (OK)" >> "$OUT"
[ -s "$TMP_BOTH" ] && sed 's/^/  = /' "$TMP_BOTH" >> "$OUT" || echo "  (none)" >> "$OUT"

rm -f "$TMP_SUN" "$TMP_LIB" "$TMP_ONLY_SUN" "$TMP_ONLY_LIB" "$TMP_BOTH"
touch "$DONE"
