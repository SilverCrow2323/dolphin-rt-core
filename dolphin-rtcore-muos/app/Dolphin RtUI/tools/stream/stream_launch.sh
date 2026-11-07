#!/bin/bash
# stream_launch.sh <app> — runs Moonlight synchronously (called from mux_launch.sh's loop).
. "$(dirname "$0")/paths.sh"
APP="$1"
# The name is only ever passed as ONE quoted argument; refuse empty names and control characters.
[ -n "$APP" ] && [ "$(printf '%s' "$APP" | tr -d '[:cntrl:]')" = "$APP" ] || { echo "invalid app name" >&2; exit 2; }
[ -x "$MOONLIGHT" ] || { echo "rc=127 moonlight missing" > "$DATA/last_result.txt"; exit 127; }
[ -n "$HOST" ] || { echo "rc=2 no PC address" > "$DATA/last_result.txt"; exit 2; }

MISSING="$(missing_libs)"
if [ -n "$MISSING" ]; then
    echo "rc=127 missing libraries: $MISSING" > "$DATA/last_result.txt"; exit 127
fi

type SET_VAR >/dev/null 2>&1 && SET_VAR "system" "foreground_process" "moonlight"   # muOS quit hotkeys act on this

set -- stream -app "$APP" -keydir "$KEYDIR" -bitrate "$BITRATE" -width "$WIDTH" -height "$HEIGHT" \
    -fps "$FPS" -codec "$CODEC" -remote "$REMOTE"
[ "$SOPS" = "no" ] && set -- "$@" -nosops
[ -n "$PLATFORM" ] && set -- "$@" -platform "$PLATFORM"
set -- "$@" -quitappafter "$HOST"

export LD_LIBRARY_PATH="$MOON_LD"
T0=$(date +%s)
"$MOONLIGHT" "$@" >"$DATA/last_stream.log" 2>&1
RC=$?
T1=$(date +%s)
if [ "$RC" -ne 0 ] || [ $((T1 - T0)) -lt 6 ]; then
    echo "rc=$RC dur=$((T1 - T0))" > "$DATA/last_result.txt"
fi
exit "$RC"
