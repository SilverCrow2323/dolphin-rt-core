#!/bin/sh
# health.sh <url> <result-file>  — writes "OK" or "FAIL" (atomically) into <result-file>
. "$(dirname "$0")/paths.sh"
url="$1"; out="$2"
case "$out" in "$DATA"/*) ;; *) exit 1 ;; esac
tmp="$out.$$"
if fetch "$url" "$tmp.body" 4 2>/dev/null; then echo "OK" > "$tmp"; else echo "FAIL" > "$tmp"; fi
rm -f "$tmp.body"; mv -f "$tmp" "$out"
