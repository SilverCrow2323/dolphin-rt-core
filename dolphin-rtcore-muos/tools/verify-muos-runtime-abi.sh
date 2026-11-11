#!/usr/bin/env bash
# Reject muOS runtime binaries that need a newer glibc than the firmware baseline.
set -euo pipefail
LIMIT="\${MUOS_GLIBC_LIMIT:-2.35}"
if [ "$#" -lt 1 ]; then
  echo "usage: $0 ELF_FILE [ELF_FILE ...]" >&2
  exit 2
fi
limit_major="\${LIMIT%%.*}"
limit_minor="\${LIMIT#*.}"
case "$limit_major:$limit_minor" in
  *[!0-9:]*|:*|*:) echo "invalid MUOS_GLIBC_LIMIT: $LIMIT" >&2; exit 2 ;;
esac
for file in "$@"; do
  [ -s "$file" ] || { echo "missing or empty ABI input: $file" >&2; exit 1; }
  command -v strings >/dev/null 2>&1 || { echo "strings is required" >&2; exit 1; }
  max_symbol="$(strings -n 6 "$file" | grep -Eo 'GLIBC_[0-9]+\.[0-9]+' | LC_ALL=C sort -V | tail -n 1 || true)"
  if [ -z "$max_symbol" ]; then
    echo "ERROR: no versioned GLIBC symbols found in $file; cannot prove runtime compatibility" >&2
    exit 1
  fi
  required="\${max_symbol#GLIBC_}"
  required_major="\${required%%.*}"
  required_minor="\${required#*.}"
  if [ "$required_major" -gt "$limit_major" ] || {
    [ "$required_major" -eq "$limit_major" ] && [ "$required_minor" -gt "$limit_minor" ];
  }; then
    echo "ERROR: $file requires $max_symbol, but muOS compatibility ceiling is GLIBC_$LIMIT" >&2
    exit 1
  fi
  echo "OK: $file requires at most $max_symbol (muOS ceiling GLIBC_$LIMIT)"
done
