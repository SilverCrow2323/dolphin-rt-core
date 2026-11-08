#!/bin/bash
# Switch between the standard and tiered Rt:Core GameCube/Wii profile sets.
# Registration is delegated to manifest_tool.sh, which detects the installed
# muOS generation (Andromeda, Jacaranda, split-manifest builds, etc.).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL="$SCRIPT_DIR/../manifest_tool.sh"
TARGET="${1:-}"

case "$TARGET" in
    1|2) ;;
    *) echo "Usage: $0 <1|2>" >&2; exit 2 ;;
esac

[ -x "$TOOL" ] || { echo "[ERR] Rt:Core platform registration tool is missing: $TOOL" >&2; exit 1; }
sh "$TOOL" apply "$TARGET"

echo
if [ "$TARGET" = "1" ]; then
    echo "Mode 1 — Standard Only"
else
    echo "Mode 2 — All Tiers Exposed"
fi
echo "Reopen Content Explorer to inspect Nintendo > GameCube / Wii."
