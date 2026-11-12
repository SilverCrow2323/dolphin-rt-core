#!/bin/sh
# Discover Sunshine hosts on the local LAN and on Tailscale.
. "$(dirname "$0")/paths.sh"
OUT="$DATA/discover.txt"
HOSTFILE="$DATA/discover.host"
CAND="$DATA/discover.candidates"
TMP="$DATA/discover.probe"
: > "$OUT"; : > "$CAND"; rm -f "$HOSTFILE"

add_candidate() {
    ip="$1"
    case "$ip" in [0-9]*.[0-9]*.[0-9]*.[0-9]*) ;; *) return ;; esac
    [ "$ip" = "0.0.0.0" ] && return
    grep -Fxq "$ip" "$CAND" 2>/dev/null || echo "$ip" >> "$CAND"
}

echo "Scanning local network neighbours..." >> "$OUT"
if command -v ip >/dev/null 2>&1; then
    ip neigh show 2>/dev/null | awk '$1 ~ /^[0-9]+\./ {print $1}' | while read -r ip; do add_candidate "$ip"; done
fi
if command -v arp >/dev/null 2>&1; then
    arp -n 2>/dev/null | awk '$1 ~ /^[0-9]+\./ {print $1}' | while read -r ip; do add_candidate "$ip"; done
fi
if command -v avahi-browse >/dev/null 2>&1; then
    avahi-browse -rt _nvstream._tcp 2>/dev/null | awk -F';' '$1 ~ /^=/ && $8 ~ /^[0-9]+\./ {print $8}' | while read -r ip; do add_candidate "$ip"; done
fi

echo "Checking Tailscale peers..." >> "$OUT"
if command -v tailscale >/dev/null 2>&1; then
    tailscale status 2>/dev/null | awk '$1 ~ /^[0-9]+\./ {print $1}' | while read -r ip; do add_candidate "$ip"; done
else
    echo "Tailscale not installed on this device." >> "$OUT"
fi

if command -v nmap >/dev/null 2>&1; then
    route="$(ip route show scope link 2>/dev/null | awk '$1 ~ /\/24$/ {print $1; exit}')"
    if [ -n "$route" ]; then
        echo "Scanning $route for Sunshine..." >> "$OUT"
        nmap -n -p 47989 --open -T3 --host-timeout 3s "$route" 2>/dev/null |
            awk '/Nmap scan report for/ {print $NF}' | tr -d '()' | while read -r ip; do add_candidate "$ip"; done
    fi
fi

if [ ! -s "$CAND" ]; then
    echo "No reachable LAN/Tailscale neighbours were listed." >> "$OUT"
    echo "Connect the PC once or enable Tailscale, then scan again." >> "$OUT"
    exit 0
fi

echo "Probing $(wc -l < "$CAND" | tr -d ' ') candidate(s) for Sunshine..." >> "$OUT"
while IFS= read -r ip; do
    [ -n "$ip" ] || continue
    if fetch "http://$ip:47989/serverinfo" "$TMP" 3 2>/dev/null; then
        if grep -Eqi 'root|hostname|appversion|Sunshine' "$TMP"; then
            echo "FOUND Sunshine: $ip" >> "$OUT"
            [ -s "$HOSTFILE" ] || printf '%s\n' "$ip" > "$HOSTFILE"
        else echo "Reachable service (not identified): $ip" >> "$OUT"; fi
    fi
    rm -f "$TMP"
done < "$CAND"

if [ -s "$HOSTFILE" ]; then
    echo "Selected host: $(cat "$HOSTFILE")" >> "$OUT"
    echo "Open Pair with PC to complete the PIN handshake." >> "$OUT"
else
    echo "No Sunshine server responded on port 47989." >> "$OUT"
    echo "Check Sunshine and the PC firewall for LAN/Tailscale traffic." >> "$OUT"
fi
rm -f "$CAND" "$TMP"
