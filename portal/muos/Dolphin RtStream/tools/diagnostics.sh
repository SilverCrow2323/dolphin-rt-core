#!/bin/sh
# diagnostics.sh - dump everything useful for a bug report to conf/diagnostics.txt
BASE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$BASE/conf/diagnostics.txt"
{
  echo "=== Dolphin Stream diagnostics ==="
  echo "Generated: $(date)"
  echo ""
  echo "--- system ---"
  uname -a
  cat /etc/os-release 2>/dev/null | head -5
  echo ""
  echo "--- versions ---"
  echo "love: $(love --version 2>&1 | head -1)"
  echo "lua: $(lua -v 2>&1 | head -1)"
  echo "git: $(git --version 2>&1 | head -1)"
  echo ""
  echo "--- disk ---"
  df -h "$BASE" 2>/dev/null
  echo ""
  echo "--- stream.conf ---"
  cat "$BASE/conf/stream.conf" 2>/dev/null
  echo ""
  echo "--- ui.cfg ---"
  cat "$BASE/conf/ui.cfg" 2>/dev/null
  echo ""
  echo "--- input.cfg (learned mapping) ---"
  cat "$BASE/conf/input.cfg" 2>/dev/null || echo "(none)"
  echo ""
  echo "--- library.tsv (count) ---"
  grep -vc '^#' "$BASE/conf/library.tsv" 2>/dev/null || echo "0"
  echo ""
  echo "--- last_stream.log (last 50 lines) ---"
  tail -50 "$BASE/conf/last_stream.log" 2>/dev/null || echo "(none)"
  echo ""
  echo "--- covers ---"
  ls -la "$BASE/covers" 2>/dev/null | head -20
  echo "total: $(ls "$BASE/covers" 2>/dev/null | wc -l) files"
} > "$OUT" 2>&1
echo "OK diagnostics saved to $OUT"
touch "$BASE/conf/diagnostics.done"
