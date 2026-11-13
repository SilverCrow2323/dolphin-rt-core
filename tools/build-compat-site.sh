#!/usr/bin/env bash
# Assemble the public Dolphin Rt:Core portal and its standalone Compatibility Database.
# Only the two web applications, PWA files and referenced artwork are copied.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/artifacts/compatibility-site}"

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
[[ "$OUT" != "$ROOT" ]] || { echo "Refusing to build the website into the repository root" >&2; exit 2; }
case "$ROOT/" in
    "$OUT/"*) echo "Refusing to build into a parent directory of the repository" >&2; exit 2 ;;
esac

for file in index.html compatibility.html manifest.json sw.js; do
    [[ -f "$ROOT/$file" ]] || { echo "Required website file is missing: $file" >&2; exit 1; }
done
for asset in spdw_symbol.png gamecube.svg wii.svg; do
    [[ -f "$ROOT/assets/$asset" ]] || { echo "Required website asset is missing: assets/$asset" >&2; exit 1; }
done

mkdir -p "$OUT/assets"
rm -f "$OUT/index.html" "$OUT/compatibility.html" "$OUT/manifest.json" "$OUT/sw.js" "$OUT/.nojekyll"
find "$OUT/assets" -maxdepth 1 -type f -delete

cp "$ROOT/index.html" "$OUT/index.html"
cp "$ROOT/compatibility.html" "$OUT/compatibility.html"
cp "$ROOT/manifest.json" "$OUT/manifest.json"
cp "$ROOT/sw.js" "$OUT/sw.js"
cp "$ROOT/assets/spdw_symbol.png" "$ROOT/assets/gamecube.svg" "$ROOT/assets/wii.svg" "$OUT/assets/"
: > "$OUT/.nojekyll"

printf 'Built Dolphin Rt:Core Project Portal in %s\n' "$OUT"
printf 'Published files: %s\n' "$(find "$OUT" -type f | wc -l | tr -d ' ')"
