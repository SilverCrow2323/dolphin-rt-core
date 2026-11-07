#!/bin/sh
# sunshine_verify.sh — list the apps Sunshine offers (needs a paired client)
. "$(dirname "$0")/paths.sh"
out="$DATA/sunshine_verify.txt"
{
need_host || exit 0
[ -x "$MOONLIGHT" ] || { echo "ERR moonlight binary missing (lib/moonlight)"; exit 0; }
LD_LIBRARY_PATH="$MOON_LD" "$MOONLIGHT" list "$HOST" -keydir "$KEYDIR" 2>&1 | head -n 60
} | atomic_write "$out"
