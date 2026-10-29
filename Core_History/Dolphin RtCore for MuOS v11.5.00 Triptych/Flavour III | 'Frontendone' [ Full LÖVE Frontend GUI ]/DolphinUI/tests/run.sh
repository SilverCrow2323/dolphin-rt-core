#!/bin/bash
cd "$(dirname "$0")/.."
PASS=0; FAIL=0
RUN="luajit"
command -v luajit >/dev/null 2>&1 || RUN="lua5.1"
command -v "$RUN" >/dev/null 2>&1 || RUN="lua"
for t in tests/unit/test_*.lua; do
  [ -f "$t" ] || continue
  echo "--- $t"
  if "$RUN" "$t" 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
done
echo ""
echo "PASS: $PASS  FAIL: $FAIL"
exit $FAIL
