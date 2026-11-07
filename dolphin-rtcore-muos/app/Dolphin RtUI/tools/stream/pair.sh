#!/bin/sh
# pair.sh — pairs with Sunshine; the PIN is shown by the UI from pair.log.
. "$(dirname "$0")/paths.sh"
log="$DATA/pair.log"
need_host >"$log" || exit 1
[ -x "$MOONLIGHT" ] || { echo "ERR moonlight binary missing (lib/moonlight)" > "$log"; exit 1; }
echo $$ > "$DATA/pair.pid"
LD_LIBRARY_PATH="$MOON_LD" "$MOONLIGHT" pair "$HOST" -keydir "$KEYDIR" >"$log" 2>&1
rm -f "$DATA/pair.pid"
