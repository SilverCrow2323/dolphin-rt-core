#!/bin/sh
# discover.sh — find Sunshine hosts on the active /24 LAN and Tailscale peers.
. "$(dirname "$0")/paths.sh"
out="$DATA/discovery.tsv"
tmp="$DATA/discovery.tsv.tmp.$$"
hostfile="$DATA/discovered_host.txt"
rm -f "$hostfile"
: > "$tmp"

# Sunshine exposes serverinfo over HTTPS with a self-signed certificate.
probe() {
    host="$1"; source="$2"
    case "$host" in
        ""|*[!0-9.]* ) return 1 ;;
    esac
    if curl -k -fsS --connect-timeout 1 -m 2 "https://$host:47989/serverinfo" -o /dev/null 2>/dev/null; then
        printf '%s\t%s\n' "$source" "$host" >> "$tmp"
        return 0
    fi
    return 1
}

# Tailscale peers are checked first. Do not install or start Tailscale:
# discovery is read-only and uses it only when already present and connected.
if command -v tailscale >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    tailscale status --json 2>/dev/null |
        jq -r '.Peer[]? | .TailscaleIPs[]? | select(test("^[0-9.]+$"))' 2>/dev/null |
        while IFS= read -r host; do probe "$host" TAILSCALE; done
fi

# Scan the active Wi-Fi / Ethernet / USB-Ethernet /24. Parallel probes keep
# the scan bounded; non-/24 networks fall back to the neighbour table below.
if command -v ip >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
    for iface in wlan0 eth0 usb0; do
        subnet="$(ip -4 route show dev "$iface" scope link 2>/dev/null | awk '$1 ~ /\/24$/ {print $1; exit}')"
        [ -n "$subnet" ] || continue
        prefix="${subnet%.*}"
        n=1
        batch=0
        while [ "$n" -le 254 ]; do
            host="$prefix.$n"
            (
                if curl -k -fsS --connect-timeout 1 -m 1 "https://$host:47989/serverinfo" -o /dev/null 2>/dev/null; then
                    printf 'LAN\\t%s\\n' "$host" >> "$tmp"
                fi
            ) &
            n=$((n + 1))
            batch=$((batch + 1))
            if [ "$batch" -ge 24 ]; then wait; batch=0; fi
        done
        wait
    done
fi

# Also test already-known neighbours (useful on non-/24 and unusual links).
if command -v ip >/dev/null 2>&1; then
    ip neigh show 2>/dev/null | awk '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print $1}' |
        while IFS= read -r host; do probe "$host" LAN; done
fi

awk -F '\t' 'NF == 2 && !seen[$2]++ {print $0}' "$tmp" > "$out"
rm -f "$tmp"
count="$(wc -l < "$out" | tr -d ' ')"
{
    echo "Rt:Stream — Sunshine discovery"
    echo "LAN + Tailscale (only already-installed Tailscale is used)"
    echo
    if [ "$count" -eq 0 ]; then
        echo "No Sunshine server found."
        echo "Check that the PC and handheld are on the same network."
    else
        while IFS="$(printf '\t')" read -r source host; do
            printf '%s  %s\n' "$source" "$host"
        done < "$out"
    fi
} > "$DATA/discovery.txt"
if [ "$count" -eq 1 ]; then
    awk -F '\t' 'NR == 1 {print $2}' "$out" > "$hostfile"
fi
cat "$DATA/discovery.txt"
