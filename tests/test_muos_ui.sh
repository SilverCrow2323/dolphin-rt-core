#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

RTSYS="$TMP/opt/muos/share/emulator/dolphin/RtSys"
mkdir -p "$RTSYS/switch_weapon" "$RTSYS/logs"
cat > "$RTSYS/switch_weapon/mode.conf" <<'MODE'
# fixture
MODE=2
MODE
cat > "$RTSYS/manifest_tool.sh" <<'TOOL'
#!/bin/sh
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in
    ensure)
        echo registration-ensured
        ;;
    apply)
        case "${2:-}" in 1|2) ;; *) exit 2 ;; esac
        printf '# fixture\nMODE=%s\n' "$2" > "$SCRIPT_DIR/switch_weapon/mode.conf"
        echo "mode-$2-applied"
        ;;
    *)
        echo "unexpected command" >&2
        exit 2
        ;;
esac
TOOL
chmod 755 "$RTSYS/manifest_tool.sh"

cd "$ROOT"
DOLPHINUI_MUOS_ROOT="$TMP" luajit tests/test_muos_ui.lua
