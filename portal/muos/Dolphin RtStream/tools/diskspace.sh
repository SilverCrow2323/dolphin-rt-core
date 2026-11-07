#!/bin/sh
BASE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$BASE/conf/diskspace.txt"
{
  echo "=== Disk usage ==="
  echo ""
  echo "--- filesystem ---"
  df -h / /tmp "$BASE" 2>/dev/null
  echo ""
  echo "--- app folders ---"
  du -sh "$BASE/covers" "$BASE/conf" "$BASE/keys" "$BASE/libs" 2>/dev/null
  echo ""
  echo "--- warnings ---"
  # alerts
  FREE=$(df -h / | awk 'NR==2 {print $4}')
  echo "free on /: $FREE"
  COV=$(du -sh "$BASE/covers" 2>/dev/null | awk '{print $1}')
  echo "covers: $COV"
} > "$OUT" 2>&1
echo "OK saved to $OUT"
touch "$BASE/conf/diskspace.done"
