#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/dolphin-build/validate-aarch64-elf.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin"
cat >"$TMP/bin/readelf" <<'MOCK_READELF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$#" -eq 2 && "$1" == "-h" ]] || exit 2

case "${MOCK_READELF_MODE:-aarch64}" in
  aarch64)
    printf 'ELF Header:\n  Class: ELF64\n  Machine: AArch64\n'
    ;;
  elf32)
    printf 'ELF Header:\n  Class: ELF32\n  Machine: AArch64\n'
    ;;
  x86_64)
    printf 'ELF Header:\n  Class: ELF64\n  Machine: Advanced Micro Devices X86-64\n'
    ;;
  malformed)
    printf 'not an ELF header\n'
    ;;
  readelf-fail)
    printf 'readelf: Error: Not an ELF file\n' >&2
    exit 1
    ;;
  *)
    exit 2
    ;;
esac
MOCK_READELF
chmod +x "$TMP/bin/readelf"

printf 'fixture\n' >"$TMP/candidate"

expect_success() {
  local mode="$1"
  if ! env PATH="$TMP/bin:$PATH" MOCK_READELF_MODE="$mode" bash "$VALIDATOR" "$TMP/candidate"; then
    printf 'Expected validator success for mode: %s\n' "$mode" >&2
    exit 1
  fi
}

expect_failure() {
  local mode="$1"
  if env PATH="$TMP/bin:$PATH" MOCK_READELF_MODE="$mode" bash "$VALIDATOR" "$TMP/candidate" >/dev/null 2>&1; then
    printf 'Expected validator failure for mode: %s\n' "$mode" >&2
    exit 1
  fi
}

expect_success aarch64
expect_failure elf32
expect_failure x86_64
expect_failure malformed
expect_failure readelf-fail

: >"$TMP/empty"
if env PATH="$TMP/bin:$PATH" MOCK_READELF_MODE=aarch64 bash "$VALIDATOR" "$TMP/empty" >/dev/null 2>&1; then
  printf 'Expected validator failure for an empty file\n' >&2
  exit 1
fi

if env PATH="$TMP/bin:$PATH" MOCK_READELF_MODE=aarch64 bash "$VALIDATOR" "$TMP/missing" >/dev/null 2>&1; then
  printf 'Expected validator failure for a missing file\n' >&2
  exit 1
fi

if env PATH="$TMP/bin:$PATH" MOCK_READELF_MODE=aarch64 bash "$VALIDATOR" >/dev/null 2>&1; then
  printf 'Expected validator failure when no file is supplied\n' >&2
  exit 1
fi

mkdir -p "$TMP/no-readelf"
if env PATH="$TMP/no-readelf" /bin/bash "$VALIDATOR" "$TMP/candidate" >/dev/null 2>&1; then
  printf 'Expected validator failure when readelf is unavailable\n' >&2
  exit 1
fi

printf 'AArch64 ELF validator contract: all cases passed.\n'
