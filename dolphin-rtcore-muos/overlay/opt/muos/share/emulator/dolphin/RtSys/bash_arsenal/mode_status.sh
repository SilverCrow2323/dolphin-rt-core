#!/bin/bash
# Reports the active switch_weapon mode and whether the Andromeda manifest matches it.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL="$SCRIPT_DIR/../manifest_tool.sh"
[ -x "$TOOL" ] || { echo "  manifest_tool.sh not found"; exit 1; }
sh "$TOOL" status
