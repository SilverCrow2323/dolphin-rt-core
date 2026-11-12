#!/usr/bin/env bash
# Verifies the native per-game profile contract without mutating the shipped Sys tree.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
luajit tests/test_graphics_mods.lua
