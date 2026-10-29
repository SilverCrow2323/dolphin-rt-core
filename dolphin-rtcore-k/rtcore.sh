#!/bin/bash
# Dolphin Rt:Core K - command line helper
ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
usage() {
cat <<EOT
Dolphin Rt:Core K $(cat "$ROOT/VERSION" 2>/dev/null)
Usage: rtcore.sh <command> [args]
  install [opts]        register the systems in EmulationStation (see ./install.sh --help)
  update  [opts]        download the latest release files from the repo, then install
  uninstall             remove the EmulationStation files and the theme logos
  run <ROM> [profile]   start a game directly (same as EmulationStation does)
  status                show where things are and the last log lines
EOT
}
case "${1:-install}" in
  install)   shift; exec "$ROOT/install.sh" "$@";;
  update)    shift; exec "$ROOT/install.sh" --update "$@";;
  uninstall) shift; exec "$ROOT/uninstall.sh" "$@";;
  run)       shift; exec "$ROOT/bin/rtcore-k.sh" "$@";;
  status)
    echo "version : $(cat "$ROOT/VERSION" 2>/dev/null)"
    echo "release : $ROOT"
    echo "core    : $([ -x "$ROOT/core/dolphin" ] && echo present || echo MISSING)"
    if [ -f "$ROOT/.installed" ]; then
      echo "installed:"; sed 's/^/  /' "$ROOT/.installed"
    else echo "installed: no (run ./rtcore.sh install)"; fi
    [ -f "$ROOT/logs/launch.log" ] && { echo "--- last log lines ---"; tail -n 8 "$ROOT/logs/launch.log"; };;
  help|-h|--help) usage;;
  *) usage; exit 1;;
esac
