#!/bin/bash
# scripts/livemenu/test_livemenu.sh — self-test for the Live Menu stack.
#
# Checks:
#   1. Python syntax of every module
#   2. Import of common.py / injector.py / main.py
#   3. Required external binaries (curl, wget, etc.)
#   4. /dev/uinput availability
#   5. Config file parseability
#   6. Joystick device presence
#
# Usage:
#   ./test_livemenu.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

PASS=0
FAIL=0
SKIP=0

pass() { printf "  ✓ %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  ✗ %s\n" "$1"; FAIL=$((FAIL + 1)); }
skip() { printf "  - %s (skipped)\n" "$1"; SKIP=$((SKIP + 1)); }

echo ":: Live Menu self-test"
echo ":: Script dir: $SCRIPT_DIR"
echo ":: App dir:    $APP_DIR"
echo

# ── 1. Python syntax ────────────────────────────────────────
echo "[1/6] Python syntax"
for f in "$SCRIPT_DIR"/*.py; do
    [ -f "$f" ] || continue
    if python3 -m py_compile "$f" 2>/dev/null; then
        pass "$(basename "$f")"
    else
        fail "$(basename "$f") — syntax error"
        python3 -m py_compile "$f" 2>&1 | head -3 | sed 's/^/      /'
    fi
done

# Cleanup pyc
find "$SCRIPT_DIR" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true

# ── 2. Imports ──────────────────────────────────────────────
echo
echo "[2/6] Module imports"
export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"

if python3 -c "import common" 2>/dev/null; then
    pass "common.py imports"
else
    fail "common.py cannot be imported"
fi

if python3 -c "import injector" 2>/dev/null; then
    pass "injector.py imports"
else
    fail "injector.py cannot be imported (missing dependency?)"
fi

if python3 -c "import main" 2>/dev/null; then
    pass "main.py imports"
else
    fail "main.py cannot be imported"
fi

# ── 3. Required binaries ────────────────────────────────────
echo
echo "[3/6] External binaries"
for bin in python3; do
    if command -v "$bin" >/dev/null 2>&1; then
        pass "$bin"
    else
        fail "$bin not found"
    fi
done
for bin in curl wget; do
    if command -v "$bin" >/dev/null 2>&1; then
        pass "$bin"
    else
        skip "$bin not found (fallback will be used)"
    fi
done

# ── 4. uinput ───────────────────────────────────────────────
echo
echo "[4/6] /dev/uinput"
if [ -e /dev/uinput ]; then
    if [ -r /dev/uinput ] && [ -w /dev/uinput ]; then
        pass "/dev/uinput present and RW"
    else
        fail "/dev/uinput present but not RW (permissions?)"
    fi
else
    skip "/dev/uinput not present (save state / reset toggles will not work)"
fi

# ── 5. Config files ─────────────────────────────────────────
echo
echo "[5/6] Config files"
CONFIG="$APP_DIR/frontend/data/livemenu_config.json"
if [ -f "$CONFIG" ]; then
    if python3 -c "import json; json.load(open('$CONFIG'))" 2>/dev/null; then
        pass "livemenu_config.json is valid JSON"
    else
        fail "livemenu_config.json is malformed"
    fi
else
    skip "livemenu_config.json not found (defaults will be used)"
fi

# ── 6. Joystick device ──────────────────────────────────────
echo
echo "[6/6] Joystick device"
JS=$(ls /dev/input/js* 2>/dev/null | head -1 || true)
if [ -n "$JS" ]; then
    if [ -r "$JS" ]; then
        pass "$JS present and readable"
    else
        fail "$JS present but not readable"
    fi
else
    fail "no /dev/input/js* device found"
fi

# ── Summary ─────────────────────────────────────────────────
echo
echo "================================"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  SKIP: %d\n" "$SKIP"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
    echo
    echo "Some checks failed. See output above."
    exit 1
else
    echo
    echo "All critical checks passed."
    exit 0
fi