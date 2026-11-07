#!/bin/sh
# Sends one controller-profile command to the PC library server and stores the answer in conf/ctl.result.
#   ctl.sh "op=set&kind=GCPad&profile=muos&key=Buttons%2FA&value=SOUTH"      (query string already url-encoded)
BASE="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE/conf/stream.conf"
OUT="$BASE/conf/ctl.result"
if [ -z "$HOST" ]; then echo "ERR host not set (START > Streaming > PC host)" > "$OUT"; exit 1; fi
if [ -z "$TOKEN" ]; then echo "ERR token not set (START > Streaming > Edit token)" > "$OUT"; exit 1; fi
URL="http://$HOST:$SYNC_PORT/ctl?token=$TOKEN&$1"
if command -v wget >/dev/null 2>&1; then RES=$(wget -q -T 8 -O - "$URL" 2>/dev/null)
else RES=$(curl -fsS -m 8 "$URL" 2>/dev/null); fi
[ -n "$RES" ] || RES="ERR PC unreachable (is the library server running?)"
echo "$RES" | head -n 1 > "$OUT"
