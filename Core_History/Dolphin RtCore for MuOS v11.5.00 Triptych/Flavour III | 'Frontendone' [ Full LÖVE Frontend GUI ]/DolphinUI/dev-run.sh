#!/usr/bin/env bash
# dev-run.sh — Quick LÖVE launcher for DolphinUI.
# Double-click friendly: auto-spawns a terminal if needed.

set -u

_ensure_terminal() {
  [ -t 0 ] && [ -t 1 ] && return 0

  local self
  self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  local inner="\"$self\"; echo; echo 'Press Enter to close...'; read -r _"

  local term
  for term in x-terminal-emulator gnome-terminal konsole xfce4-terminal \
              mate-terminal lxterminal alacritty kitty foot wezterm \
              terminator tilix xterm urxvt rxvt st; do
    command -v "$term" >/dev/null 2>&1 || continue
    case "$term" in
      gnome-terminal|xfce4-terminal|mate-terminal|terminator|tilix)
        exec "$term" -- bash -c "$inner" ;;
      konsole)
        exec "$term" -e bash -c "$inner" ;;
      wezterm)
        exec "$term" start -- bash -c "$inner" ;;
      *)
        exec "$term" -e bash -c "$inner" ;;
    esac
  done

  echo "No terminal emulator found."
  exit 1
}
_ensure_terminal

cd "$(dirname "$0")/frontend" || { echo "frontend/ not found"; exit 1; }

if ! command -v love >/dev/null 2>&1; then
  echo "love not found in PATH."
  echo "Press Enter to close."
  read -r _
  exit 1
fi

echo "── DolphinUI: launching LÖVE (640x480) ──"
echo
love . "${@:-640x480}"
RC=$?
echo
echo "── LÖVE exited with code $RC ──"
echo "Press Enter to close."
read -r _ || true
exit "$RC"