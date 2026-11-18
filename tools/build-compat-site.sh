#!/usr/bin/env bash
# Assemble the complete public Dolphin Rt:Core product hub and standalone Compatibility Database.
# Publish only the web application, local catalogues and referenced artwork.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/artifacts/compatibility-site}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
[[ "$OUT" != "$ROOT" ]] || { echo "Refusing to build the website into the repository root" >&2; exit 2; }
case "$ROOT/" in "$OUT/"*) echo "Refusing to build into a parent directory of the repository" >&2; exit 2 ;; esac
FILES=(index.html compatibility.html quick-start.html profiles.html gamesettings.html docs.html manifest.json sw.js assets/site.css assets/site.js assets/editorial.css data/site-gamesettings-index.json data/site-profiles.json data/site-docs-index.json)
for file in "${FILES[@]}"; do [[ -f "$ROOT/$file" ]] || { echo "Required website file is missing: $file" >&2; exit 1; }; done
ASSETS=(spdw_symbol.png dolphinrt_icon.png dolphin_rtcore_title.png gamecube.svg wii.svg)
for asset in "${ASSETS[@]}"; do [[ -f "$ROOT/assets/$asset" ]] || { echo "Required website asset is missing: assets/$asset" >&2; exit 1; }; done
rm -rf "$OUT"
mkdir -p "$OUT/assets" "$OUT/data"
for file in "${FILES[@]}"; do mkdir -p "$OUT/$(dirname "$file")"; cp "$ROOT/$file" "$OUT/$file"; done
for asset in "${ASSETS[@]}"; do cp "$ROOT/assets/$asset" "$OUT/assets/$asset"; done
: > "$OUT/.nojekyll"
printf 'Built Dolphin Rt:Core Product Hub in %s\n' "$OUT"
printf 'Published files: %s\n' "$(find "$OUT" -type f | wc -l | tr -d ' ')"
