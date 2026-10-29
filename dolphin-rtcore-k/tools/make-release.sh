#!/bin/bash
# Crea lo zip della release dalla cartella del repo / builds the release zip from the repo folder
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
V="$(cat "$ROOT/VERSION")"
OUT="${1:-$(dirname "$ROOT")/Dolphin-RtCore-K_v$V.zip}"
cd "$(dirname "$ROOT")" || exit 1
zip -r -9 -X "$OUT" "$(basename "$ROOT")" -x "*/logs/*" "*/.installed" "*/.theme_installed" "*/.git/*" "*.bak" "*.old"
echo "creato / created: $OUT"
