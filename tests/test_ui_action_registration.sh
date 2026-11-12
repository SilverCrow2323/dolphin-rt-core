#!/usr/bin/env bash
# Ensure each screen publishes its NEXUS actions exactly once during UI startup.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI/ui/init.lua"

[[ -f "$REGISTRY" ]] || { echo "Missing UI registry: $REGISTRY" >&2; exit 1; }
mapfile -t screens < <(
  sed -nE 's/^[[:space:]]*local [[:alnum:]_]+_screen = Nexus\.get_screen\("([^"]+)"\)$/\1/p' "$REGISTRY"
)
(("${#screens[@]}" > 0)) || { echo "No NEXUS action screen registrations found." >&2; exit 1; }

duplicates="$(printf '%s\n' "${screens[@]}" | sort | uniq -d)"
if [[ -n "$duplicates" ]]; then
  printf 'Duplicate NEXUS action registration(s):\n%s\n' "$duplicates" >&2
  exit 1
fi

printf 'Verified %s unique NEXUS action screen registration(s).\n' "${#screens[@]}"
