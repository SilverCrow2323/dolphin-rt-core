#!/bin/sh
# wake.sh — Wake-on-LAN magic packet (needs MAC in Stream settings)
. "$(dirname "$0")/paths.sh"
out="$DATA/wake.txt"
{
mac=$(echo "$MAC" | tr 'A-F' 'a-f' | tr -d ':- ')
case "$mac" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) echo "ERR set a valid MAC (12 hex digits) in Stream settings"; exit 0 ;;
esac
if command -v python3 >/dev/null 2>&1; then PY=python3; elif command -v python >/dev/null 2>&1; then PY=python; else echo "ERR no python on this device"; exit 0; fi
"$PY" - "$mac" <<'PYEOF' && echo "OK magic packet sent" || echo "ERR could not send"
import socket, sys
m = bytes.fromhex(sys.argv[1]); pkt = b"\xff" * 6 + m * 16
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
for a in ("255.255.255.255",): s.sendto(pkt, (a, 9))
PYEOF
} | atomic_write "$out"
