#!/bin/bash
# Dolphin Rt:Core K - uninstall
# Removes the EmulationStation files and the theme logos. Does NOT delete this folder, your ROMs or your saves.
ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ES_DIR=""
[ -f "$ROOT/.installed" ] && ES_DIR="$(sed -n 's/^es_dir=//p' "$ROOT/.installed")"
[ "${1:-}" = "--es-dir" ] && ES_DIR="$2"
[ -z "$ES_DIR" ] && { echo "[rtcore-k] ERROR: EmulationStation folder unknown, pass --es-dir DIR" >&2; exit 1; }
for f in es_systems_rtcore.cfg es_features_rtcore.cfg; do
  rm -f "$ES_DIR/$f" "$ES_DIR/$f.bak" && echo "[rtcore-k] removed $ES_DIR/$f"
done
bash "$ROOT/theme/install-theme.sh" --uninstall
rm -f "$ROOT/.installed"
if [ -x /etc/init.d/S31emulationstation ]; then /etc/init.d/S31emulationstation restart >/dev/null 2>&1 & fi
echo "[rtcore-k] Done. This folder, your ROMs and your saves were left untouched."
