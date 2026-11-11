#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'AArch64 ELF validation failed: %s\n' "$*" >&2
  exit 1
}

if [[ "$#" -ne 1 ]]; then
  fail "usage: $0 <binary>"
fi

binary="$1"
[[ -s "$binary" ]] || fail "missing or empty file: $binary"
command -v readelf >/dev/null 2>&1 || fail "readelf is not installed"

if ! header="$(readelf -h "$binary" 2>&1)"; then
  printf '%s\n' "$header" >&2
  fail "readelf could not inspect: $binary"
fi

grep -Eq '^[[:space:]]*Class:[[:space:]]*ELF64([[:space:]]|$)' <<<"$header" ||
  fail "expected ELF64: $binary"
grep -Eq '^[[:space:]]*Machine:[[:space:]]*AArch64([[:space:]]|$)' <<<"$header" ||
  fail "expected AArch64: $binary"

printf 'Validated ELF64/AArch64: %s\n' "$binary"
