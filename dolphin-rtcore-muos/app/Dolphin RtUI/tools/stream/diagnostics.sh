#!/bin/sh
# diagnostics.sh — support report. TOKEN and MAC are never written.
. "$(dirname "$0")/paths.sh"
{
echo "Dolphin Rt:Stream diagnostics  $(date '+%F %T')"
echo "host=$HOST port=$SYNC_PORT ${WIDTH}x${HEIGHT}@${FPS} ${BITRATE}kbps codec=$CODEC remote=$REMOTE sops=$SOPS"
echo "token=$([ -n "$TOKEN" ] && echo set || echo empty) mac=$([ -n "$MAC" ] && echo set || echo empty)"
echo "moonlight: $([ -x "$MOONLIGHT" ] && echo present || echo MISSING)  keys: $(ls "$KEYDIR" 2>/dev/null | wc -l) files"
echo "moonlight libs missing: $(missing_libs)"
echo "library: $(grep -c -E '^(gc|wii)	' "$DATA/library.tsv" 2>/dev/null || echo 0) games"
echo "sync: $(cat "$DATA/sync.status" 2>/dev/null)"
echo "--- last stream log (tail) ---"
tail -n 25 "$DATA/last_stream.log" 2>/dev/null
} | atomic_write "$DATA/diagnostics.txt"
