#!/bin/bash
# Dolphin Rt:Core K — installa i loghi nel tema attivo di ES / installs logos into the active ES theme
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
LOGOS="$ROOT/theme/logos"
MANIFEST="$ROOT/.theme_installed"
THEMES=""; ES_DIR=""; UNINSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --themes) THEMES="$2"; shift 2;;
    --es-dir) ES_DIR="$2"; shift 2;;
    --uninstall) UNINSTALL=1; shift;;
    *) shift;;
  esac
done

if [ "$UNINSTALL" = 1 ]; then
  [ -f "$MANIFEST" ] || { echo "[theme] niente da rimuovere / nothing to remove"; exit 0; }
  while IFS= read -r dest; do
    [ -z "$dest" ] && continue
    rm -f "$dest"; [ -f "$dest.rtcore.bak" ] && mv -f "$dest.rtcore.bak" "$dest"
    echo "[theme] rimosso/removed $dest"
  done < "$MANIFEST"
  rm -f "$MANIFEST"; exit 0
fi

[ -n "$THEMES" ] && [ -n "$ES_DIR" ] || { echo "uso: install-theme.sh --themes DIR --es-dir DIR"; exit 1; }
THEME="$(grep -o 'name="ThemeSet" value="[^"]*"' "$ES_DIR/es_settings.cfg" 2>/dev/null | sed 's/.*value="//; s/"$//')"
[ -z "$THEME" ] && { echo "[theme] tema attivo non trovato / active theme not found"; exit 0; }
TD="$THEMES/$THEME"
echo "[theme] tema attivo / active theme: $THEME"

if [ -d "$TD/_art/Colorlogos" ]; then
  DEST="$TD/_art/Colorlogos"
  : > "$MANIFEST"
  for pair in "logo_wii.png:wii.png" "logo_gamecube.png:gamecube.png" "logo_rtcore.png:rtcore.png"; do
    src="${pair%%:*}"; dst="$DEST/${pair##*:}"
    [ -f "$dst" ] && [ ! -f "$dst.rtcore.bak" ] && cp -f "$dst" "$dst.rtcore.bak"
    cp -f "$LOGOS/$src" "$dst" && echo "$dst" >> "$MANIFEST" && echo "[theme] copiato/copied $dst"
  done
else
  echo "[theme] layout del tema '$THEME' non riconosciuto (manca _art/Colorlogos)."
  echo "[theme] layout of theme '$THEME' not recognised. Logos are in: $LOGOS"
  echo "[theme] copia/copy: logo_wii.png -> wii, logo_gamecube.png -> gamecube (formato/path: vedi il tema / see the theme docs)"
fi
exit 0
