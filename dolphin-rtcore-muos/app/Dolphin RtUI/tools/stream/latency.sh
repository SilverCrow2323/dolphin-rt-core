#!/bin/sh
# latency.sh — ping the PC
. "$(dirname "$0")/paths.sh"
out="$DATA/latency.txt"
{ need_host || exit 0; ping -c 4 -W 2 "$HOST" 2>&1 | tail -n 3; } | atomic_write "$out"
