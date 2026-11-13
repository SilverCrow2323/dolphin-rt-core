#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/dolphin-rtcore-muos/app/Dolphin RtUI"
luajit "$ROOT/tests/test_rom_paths.lua"
