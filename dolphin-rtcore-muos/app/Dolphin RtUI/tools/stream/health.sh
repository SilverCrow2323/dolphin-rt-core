#!/bin/sh
# health.sh <url> <result-file>  — writes "OK" or "FAIL" (atomically) into <result-file>
. "$(dirname "$0")/paths.sh"
url="$1"; out="$2"
case "$out" in "$DATA"/*) ;; *) exit 1 ;; esac
tmp="$out.$$"
case "$url" in
    https://*)
        if command -v curl >/dev/null 2>&1; then
            curl -k -fsS --connect-timeout 2 -m 4 -o "$tmp.body" "$url" 2>/dev/null
        else
            wget --no-check-certificate -q -T 4 -O "$tmp.body" "$url" 2>/dev/null
        fi
        ;;
    *) fetch "$url" "$tmp.body" 4 2>/dev/null ;;
esac
if [ -s "$tmp.body" ]; then echo "OK" > "$tmp"; else echo "FAIL" > "$tmp"; fi
rm -f "$tmp.body"; mv -f "$tmp" "$out"
