#!/bin/bash
# Adds / removes the Rt:Core R option menu in EmulationStation's es_features.cfg.
#   es-features.sh install <ES_DIR> [--dry]
#   es-features.sh remove  <ES_DIR>
# This ES reads ONE es_features.cfg (the user's in <ES_DIR> first, else the system one) and does not merge
# es_features_*.cfg files, so our block is inserted into the user file between marker comments:
# a copy of the system file is made if the user has none, a one-time backup is kept, and removal restores the state.
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
TSV="$ROOT/config/options.tsv"
CMD="${1:-}"; ES_DIR="${2:-}"; DRY=0; [ "${3:-}" = "--dry" ] && DRY=1
B='<!-- RTCORE-R BEGIN -->'; E='<!-- RTCORE-R END -->'
T="$ES_DIR/es_features.cfg"; CREATED="$ES_DIR/.rtcore-features-created"
say() { echo "[rtcore-r] $*"; }
die() { echo "[rtcore-r] ERROR: $*" >&2; exit 1; }
[ -n "$ES_DIR" ] || die "usage: es-features.sh install|remove <ES_DIR>"

shared_file() { for f in "${RTCORE_SHARED_FEATURES:-}" /etc/emulationstation/es_features.cfg /usr/config/emulationstation/es_features.cfg; do [ -n "$f" ] && [ -f "$f" ] && { echo "$f"; return; }; done; }
xa() { local s="$1"; s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"; s="${s//\"/&quot;}"; printf '%s' "$s"; }

gen_block() {
  echo "$B"
  echo '  <emulator name="rtcore-r">'
  local key=""
  while IFS=$'\t' read -r kind a b c d; do
    case "$kind" in
      F) [ -n "$key" ] && echo '    </feature>'
         key="$b"
         printf '    <feature name="%s" value="%s" description="%s" submenu="%s">\n' "$(xa "$c")" "$(xa "$b")" "$(xa "$d")" "$(xa "$a")";;
      C) printf '      <choice name="%s" value="%s" />\n' "$(xa "$c")" "$(xa "$b")";;
    esac
  done < <(grep -v '^#' "$TSV")
  [ -n "$key" ] && echo '    </feature>'
  echo '  </emulator>'
  echo "$E"
}

strip_block() { awk -v b="$B" -v e="$E" 'index($0,b){skip=1} !skip{print} index($0,e){skip=0}' "$1"; }

valid_xml() {
  if command -v python3 >/dev/null 2>&1; then python3 -c 'import sys,xml.dom.minidom as m; m.parse(sys.argv[1])' "$1" 2>/dev/null
  elif command -v xmllint >/dev/null 2>&1; then xmllint --noout "$1" 2>/dev/null
  else [ "$(grep -c '<features>' "$1")" = 1 ] && [ "$(grep -c '</features>' "$1")" = 1 ]; fi
}

case "$CMD" in
install)
  [ -f "$TSV" ] || die "missing $TSV"
  W="$(mktemp)"; trap 'rm -f "$W" "$W.new"' EXIT
  if   [ -f "$T" ]; then strip_block "$T" > "$W"
  elif S="$(shared_file)"; [ -n "$S" ]; then strip_block "$S" > "$W"; say "no user es_features.cfg: starting from $S"
  else printf '<?xml version="1.0"?>\n<features>\n</features>\n' > "$W"; say "no es_features.cfg found anywhere: creating a minimal one"; fi
  n="$(grep -n '</features>' "$W" | tail -n 1 | cut -d: -f1)"; [ -n "$n" ] || die "es_features.cfg has no </features> tag"
  { head -n $((n-1)) "$W"; gen_block; tail -n +"$n" "$W"; } > "$W.new"
  valid_xml "$W.new" || die "the merged es_features.cfg is not valid XML, nothing was written"
  feats="$(grep -c 'RTCORE' "$W.new")"
  if [ "$DRY" = 1 ]; then echo "[dry-run] would write $T ($(grep -c '<feature ' "$W.new") <feature> entries incl. ours)"; exit 0; fi
  mkdir -p "$ES_DIR"
  if [ -f "$T" ]; then [ -e "$T.rtcore.bak" ] || cp -f "$T" "$T.rtcore.bak"; else : > "$CREATED"; fi
  cp -f "$W.new" "$T.tmp" && mv -f "$T.tmp" "$T"
  say "EmulationStation options: $(awk -F'\t' '$1=="F"' "$TSV" | wc -l) per-game options added to $T";;
remove)
  [ -f "$T" ] || exit 0
  W="$(mktemp)"; strip_block "$T" > "$W"
  S="$(shared_file)"
  if [ -e "$CREATED" ] && { [ -z "$S" ] || diff -q <(strip_block "$S") "$W" >/dev/null 2>&1 || ! grep -q '<emulator' "$W"; }; then
    rm -f "$T" "$CREATED"; say "removed $T (it only existed for Rt:Core; EmulationStation falls back to the system file)"
  else cp -f "$W" "$T"; rm -f "$CREATED"; say "removed the Rt:Core block from $T"; fi
  rm -f "$W";;
*) die "usage: es-features.sh install|remove <ES_DIR>";;
esac
