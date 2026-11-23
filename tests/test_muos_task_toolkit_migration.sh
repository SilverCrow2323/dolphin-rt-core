#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPER="$ROOT/dolphin-rtcore-muos/emu/dolphin/RtSys/cleanup_legacy_tasks.sh"
UPDATE="$ROOT/dolphin-rtcore-muos/overlay/opt/update.sh"
TASK_SOURCE="$ROOT/dolphin-rtcore-muos/overlay/opt/muos/share/task/Dolphin Rt-Core"
SCAN_LOAD="$ROOT/dolphin-rtcore-muos/emu/dolphin/RtSys/bash_arsenal/scan_load.sh"

[[ -s "$HELPER" ]]
sh -n "$HELPER"
sh -n "$UPDATE"
[[ ! -e "$TASK_SOURCE" ]] || { echo "[FAIL] legacy Task Toolkit source still exists" >&2; exit 1; }
[[ ! -e "$SCAN_LOAD" ]] || { echo "[FAIL] legacy Task Toolkit Load scanner still exists" >&2; exit 1; }
grep -Fq 'cleanup_legacy_tasks.sh' "$UPDATE"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TASK_ROOT="$TMP/tasks"
mkdir -p "$TASK_ROOT/Dolphin Rt-Core" "$TASK_ROOT/Dolphin RtCore" "$TASK_ROOT/Other Emulator" "$TASK_ROOT/Dolphin RtUI"
: > "$TASK_ROOT/Dolphin Rt-Core/legacy-task.sh"
: > "$TASK_ROOT/Dolphin RtCore/legacy-task.sh"
: > "$TASK_ROOT/Other Emulator/keep.txt"
: > "$TASK_ROOT/Dolphin RtUI/keep.txt"

sh "$HELPER" --test-root "$TASK_ROOT"
[[ ! -e "$TASK_ROOT/Dolphin Rt-Core" ]]
[[ ! -e "$TASK_ROOT/Dolphin RtCore" ]]
[[ -f "$TASK_ROOT/Other Emulator/keep.txt" ]]
[[ -f "$TASK_ROOT/Dolphin RtUI/keep.txt" ]]
echo "[OK] legacy Rt:Core Task Toolkit trees are removed without touching unrelated tasks"
