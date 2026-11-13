#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/dolphin-rtcore-muos/tools/verify-muos-runtime-abi.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf 'fixture GLIBC_2.17 GLIBC_2.35\n' > "$TMP/compatible"
bash "$CHECK" "$TMP/compatible"
printf 'fixture GLIBC_2.36\n' > "$TMP/newer"
if bash "$CHECK" "$TMP/newer" >"$TMP/newer.out" 2>&1; then
  echo "FAIL: GLIBC_2.36 was accepted for a 2.35 ceiling" >&2
  exit 1
fi
grep -Fq 'requires GLIBC_2.36' "$TMP/newer.out"
printf 'fixture GLIBC_2.34\n' > "$TMP/older"
MUOS_GLIBC_LIMIT=2.34 bash "$CHECK" "$TMP/older"
printf 'fixture without ABI tags\n' > "$TMP/unknown"
if bash "$CHECK" "$TMP/unknown" >"$TMP/unknown.out" 2>&1; then
  echo "FAIL: input without ABI tags was treated as compatible" >&2
  exit 1
fi
grep -Fq 'cannot prove runtime compatibility' "$TMP/unknown.out"
echo "muOS GLIBC ABI gate: all cases passed"
