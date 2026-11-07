#!/bin/sh
# Switches the streaming display to a 4:3 mode so the stream fills the handheld screen
# (no black bars top/bottom) and restores the original mode afterwards.
#   display-mode.sh set WxH | restore | status        (X11 / xrandr)
command -v xrandr >/dev/null 2>&1 || exit 0
STATE="${XDG_CACHE_HOME:-$HOME/.cache}/spdw-display.state"
mkdir -p "$(dirname "$STATE")"

OUT=$(xrandr --query | awk '/ connected primary/{print $1; exit}')
[ -n "$OUT" ] || OUT=$(xrandr --query | awk '/ connected/{print $1; exit}')
[ -n "$OUT" ] || exit 0

cur_mode() { xrandr --query | awk -v o="$1" '$1==o{f=1;next} /^[^ \t]/{f=0} f && /\*/{print $1; exit}'; }
cur_rate() { xrandr --query | awk -v o="$1" '$1==o{f=1;next} /^[^ \t]/{f=0} f && /\*/{for(i=2;i<=NF;i++) if($i ~ /\*/){r=$i; gsub(/[*+]/,"",r); print r; exit}}'; }

case "$1" in
  set)
    W=${2%x*}; H=${2#*x}
    [ -f "$STATE" ] || echo "$OUT $(cur_mode "$OUT") $(cur_rate "$OUT")" > "$STATE"
    xrandr --output "$OUT" --mode "$2" 2>/dev/null && exit 0
    if command -v cvt >/dev/null 2>&1; then
      LINE=$(cvt "$W" "$H" 60 2>/dev/null | sed -n 's/^Modeline //p')
      NAME=$(echo "$LINE" | awk '{gsub(/"/,"",$1); print $1}')
      PARAMS=$(echo "$LINE" | cut -d' ' -f2-)
      if [ -n "$NAME" ]; then
        xrandr --newmode "$NAME" $PARAMS 2>/dev/null
        xrandr --addmode "$OUT" "$NAME" 2>/dev/null
        xrandr --output "$OUT" --mode "$NAME" 2>/dev/null && exit 0
      fi
    fi
    for m in 1024x768 800x600 640x480; do
      xrandr --output "$OUT" --mode "$m" 2>/dev/null && exit 0
    done
    ;;
  restore)
    [ -f "$STATE" ] || exit 0
    read -r o m r < "$STATE"
    if [ -n "$m" ]; then
      if [ -n "$r" ]; then xrandr --output "$o" --mode "$m" --rate "$r" 2>/dev/null || xrandr --output "$o" --mode "$m" 2>/dev/null || xrandr --output "$o" --auto
      else xrandr --output "$o" --mode "$m" 2>/dev/null || xrandr --output "$o" --auto; fi
    else
      xrandr --output "$o" --auto
    fi
    rm -f "$STATE"
    ;;
  status)
    echo "$OUT $(cur_mode "$OUT")"
    ;;
esac
exit 0
