#!/bin/sh
# HELP: Dolphin Rt:Stream
# ICON: moonlight
# GRID: Dolphin Rt:Stream

. /opt/muos/script/var/func.sh

APP_BIN="love"
SETUP_APP "$APP_BIN" ""

# -----------------------------------------------------------------------------

LOVEDIR="$1"
export LOVEDIR
. "$LOVEDIR/tools/paths.sh"

cd "$LOVEDIR" || exit

SET_VAR "system" "foreground_process" "love"

cleanup_all() {
    [ -n "$GPTK_PID" ] && kill -9 "$GPTK_PID" 2>/dev/null && wait "$GPTK_PID" 2>/dev/null
    [ -n "$STREAM_GPTK_PID" ] && kill -9 "$STREAM_GPTK_PID" 2>/dev/null && wait "$STREAM_GPTK_PID" 2>/dev/null
    exit 0
}
trap cleanup_all INT TERM

while true; do
    rm -f "$LOVEDIR/launch.txt" "$LOVEDIR/launch.env"

    if [ -n "$GPTK_BIN" ]; then
        "$GPTK_BIN" "$APP_BIN" &
        GPTK_PID=$!
    fi
    "$LOVE_BIN" gui
    [ -n "$GPTK_PID" ] && kill -9 "$GPTK_PID" 2>/dev/null
    [ -n "$GPTK_PID" ] && wait "$GPTK_PID" 2>/dev/null
    [ -n "$GPTK_BIN" ] && pkill -f "gptokeyb2.*$APP_BIN" 2>/dev/null
    GPTK_PID=""

    [ -f "$LOVEDIR/launch.txt" ] || break
    APP="$(cat "$LOVEDIR/launch.txt")"
    rm -f "$LOVEDIR/launch.txt"

    case "$APP" in ""|*[!A-Za-z0-9\ ._-]*) echo "invalid app: $APP" >&2; continue;; esac

    . "$LOVEDIR/conf/stream.conf"
    [ -f "$LOVEDIR/launch.env" ] && { . "$LOVEDIR/launch.env"; rm -f "$LOVEDIR/launch.env"; }

    set -- stream -app "$APP" -keydir "$KEYDIR" \
        -bitrate "$BITRATE" -width "$WIDTH" -height "$HEIGHT" \
        -fps "$FPS" -codec "$CODEC" -remote "$REMOTE"
    [ "$SOPS" = "no" ] && set -- "$@" -nosops
    [ -n "$PLATFORM" ] && set -- "$@" -platform "$PLATFORM"
    # shellcheck disable=SC2086
    [ -n "$EXTRA_ARGS" ] && set -- "$@" $EXTRA_ARGS
    set -- "$@" -quitappafter "$HOST"

    T0=$(date +%s)
    cd "$MOONDIR" || exit
    ./moonlight "$@" >"$LOVEDIR/conf/last_stream.log" 2>&1
    RC=$?
    cd "$LOVEDIR" || exit
    T1=$(date +%s)

    if [ "$RC" -ne 0 ] || [ $((T1 - T0)) -lt 6 ]; then
        echo "rc=$RC dur=$((T1 - T0))" >"$LOVEDIR/conf/last_result.txt"
    fi
done
