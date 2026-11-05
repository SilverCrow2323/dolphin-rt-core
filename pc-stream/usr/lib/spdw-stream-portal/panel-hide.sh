#!/bin/sh
# Nasconde il pannello XFCE durante lo stream e lo ripristina dopo.
#   panel-hide.sh hide | show
STATE="${XDG_CACHE_HOME:-$HOME/.cache}/spdw-panel.state"
command -v xfconf-query >/dev/null 2>&1 || exit 0
mkdir -p "$(dirname "$STATE")"
case "$1" in
  hide)
    : > "$STATE"
    PROPS=$(xfconf-query -c xfce4-panel -l 2>/dev/null | grep '/autohide-behavior$')
    [ -n "$PROPS" ] || PROPS=$(xfconf-query -c xfce4-panel -l 2>/dev/null | sed -n 's#^\(/panels/panel-[0-9]*\)/.*#\1/autohide-behavior#p' | sort -u)
    for p in $PROPS; do
      old=$(xfconf-query -c xfce4-panel -p "$p" 2>/dev/null || echo 0)
      echo "$p $old" >> "$STATE"
      xfconf-query -c xfce4-panel -p "$p" -n -t int -s 2 2>/dev/null
    done
    ;;
  show)
    [ -f "$STATE" ] || exit 0
    while read -r p v; do
      xfconf-query -c xfce4-panel -p "$p" -n -t int -s "${v:-0}" 2>/dev/null
    done < "$STATE"
    rm -f "$STATE"
    ;;
esac
exit 0
