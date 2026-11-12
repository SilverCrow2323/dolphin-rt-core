#!/usr/bin/env bash
set -euo pipefail
APP="$(cd "$(dirname "$0")/.." && pwd)/dolphin-rtcore-muos/app/Dolphin RtUI"
check() {
  local file="$1" expected="$2"
  grep -Fqx "$expected" "$file" || {
    echo "[FAIL] $file: expected $expected" >&2
    exit 1
  }
}
gc_count=0
while IFS= read -r -d '' file; do
  gc_count=$((gc_count + 1))
  check "$file" 'Buttons/A = `Button 1`'
  check "$file" 'Buttons/B = `Button 0`'
  check "$file" 'Buttons/X = `Button 2`'
  check "$file" 'Buttons/Y = `Button 3`'
  check "$file" 'Buttons/Z = `Button 11`'
  check "$file" 'Buttons/Start = `Button 7`'
  check "$file" 'Triggers/L = `Button 4`'
  check "$file" 'Triggers/L-Analog = `Button 9`'
  check "$file" 'Triggers/R = `Button 5`'
  check "$file" 'Triggers/R-Analog = `Button 12`'
done < <(find "$APP/workshop/controller/GameCube" -type f -name GCPadNew.ini -print0)
wii_count=0
while IFS= read -r -d '' file; do
  wii_count=$((wii_count + 1))
  check "$file" 'Buttons/A = `Button 1`'
  check "$file" 'Buttons/B = `Button 0`'
  check "$file" 'Buttons/1 = `Button 2`'
  check "$file" 'Buttons/2 = `Button 3`'
  check "$file" 'Buttons/+ = `Button 7`'
  check "$file" 'Buttons/- = `Button 6`'
  check "$file" 'Buttons/Home = `Button 8`'
  check "$file" 'Nunchuk/Buttons/C = `Button 4`'
  check "$file" 'Nunchuk/Buttons/Z = `Button 5`'
done < <(find "$APP/workshop/controller/Wii" -type f -name WiimoteNew.ini -print0)
[ "$gc_count" -gt 0 ] && [ "$wii_count" -gt 0 ]
echo "[OK] current SDL button numbering verified in $gc_count GameCube and $wii_count Wii profiles"
