#!/bin/sh
# ============================================================
#  manifest_tool.sh — registers GameCube/Wii + all Rt:Core profiles in the
#  muOS Andromeda core manifest (replaces the old info/assign/*.ini files).
#
#  usage: manifest_tool.sh apply [1|2]   write/refresh our two systems (mode from mode.conf if omitted)
#         manifest_tool.sh ensure        apply only if missing or out of date (cheap, safe to call at every start)
#         manifest_tool.sh remove        delete only our two systems
#         manifest_tool.sh status
#
#  Sources of truth: switch_weapon/{gc,wii}/mode <N>/*.ini  (same files as before)
#  Never touches any other system. Two manifest layouts are supported:
#    release 2606.0 : $STORE/info/manifest/core.json      (ONE file, replaces the bundled one)
#    newer builds   : $STORE/info/manifest/core/<Namespace>/<System>.json (one file per system)
#  Test overrides: MUOS_STORE_DIR, RT_BUNDLED_MANIFEST
# ============================================================
SW="$(cd "$(dirname "$0")" && pwd)/switch_weapon"
STORE="${MUOS_STORE_DIR:-/run/muos/storage}"
USERM="$STORE/info/manifest"
BUNDLED="${RT_BUNDLED_MANIFEST:-/opt/muos/share/info/manifest}"
NS="Nintendo"
STATE="$SW/mode.conf"

say() { printf '  %s\n' "$*"; }
die() { printf '  [ERR] %s\n' "$*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "jq not found (needed for the Andromeda manifest)"

layout() { if [ -d "$BUNDLED/core" ]; then echo split; else echo single; fi; }

cur_mode() { m="$(sed -n 's/^MODE=\([12]\)[[:space:]]*$/\1/p' "$STATE" 2>/dev/null | head -n 1)"; echo "${m:-1}"; }

# ini folder -> one system object (JSON on stdout) + its system key on fd 3 is avoided: key via sys_name
sys_name() { sed -n 's/^name=//p' "$1/global.ini" | head -n 1 | tr -d '\r'; }

build_system() {   # build_system <dir-with-ini>
    dir="$1"
    {
        awk -F= '
          /^\[/ { sec=$0; gsub(/[\[\]\r]/,"",sec); next }
          { sub(/\r$/,"") }
          sec=="global" && $1 ~ /^(name|default|catalogue|lookup|governor)$/ { print "G\t" $1 "\t" substr($0,index($0,"=")+1) }
          sec=="friendly" && NF>0 && $0!="" { print "F\t" $0 }
        ' "$dir/global.ini"
        for f in "$dir"/*.ini; do
            [ "$(basename "$f")" = "global.ini" ] && continue
            awk -F= '
              /^\[/ { sec=$0; gsub(/[\[\]\r]/,"",sec); next }
              { sub(/\r$/,"") }
              $1=="name" && !n { n=substr($0,6) }
              $1=="core" && !c { c=substr($0,6) }
              $1=="exec" && !e { e=substr($0,6) }
              END { if (n!="" && c!="" && e!="") { k=FILENAME; sub(/.*\//,"",k); sub(/\.ini$/,"",k); sub(/.*\//,"",e); sub(/^ext-/,"",e); print "E\t" k "\t" n "\t" c "\t" e } }
            ' "$f"
        done
    } | jq -Rn --arg ns "$NS" '
        [inputs | split("\t")] as $r
        | ($r | map(select(.[0]=="G")) | map({(.[1]): .[2]}) | add) as $g
        | {
            name: $g.name, namespace: $ns, catalogue: ($g.catalogue // $g.name),
            lookup: (($g.lookup // "0") | tonumber), default: $g.default,
            runtime: "external",
            friendly: ($r | map(select(.[0]=="F") | .[1])), bios: [],
            external: ($r | map(select(.[0]=="E") | {(.[1]): {name: .[2], core: .[3], launcher: .[4]}}) | add)
          }
        + (if ($g.governor // "") != "" then {governor: $g.governor} else {} end)'
}

build_both() {   # -> $GC_JSON, $WII_JSON
    N="$1"
    [ -f "$SW/gc/mode $N/global.ini" ] && [ -f "$SW/wii/mode $N/global.ini" ] || die "missing source: switch_weapon/{gc,wii}/mode $N"
    GC_KEY="$(sys_name "$SW/gc/mode $N")"; WII_KEY="$(sys_name "$SW/wii/mode $N")"
    [ -n "$GC_KEY" ] && [ -n "$WII_KEY" ] || die "global.ini without name="
    GC_JSON="$(build_system "$SW/gc/mode $N")" || die "cannot build GameCube system"
    WII_JSON="$(build_system "$SW/wii/mode $N")" || die "cannot build Wii system"
    for j in "$GC_JSON" "$WII_JSON"; do
        printf '%s' "$j" | jq -e '(.external|length)>0 and (.default as $d | .external | has($d))' >/dev/null \
            || die "$(printf '%s' "$j" | jq -r .name): no entries, or default profile is not one of them (mode $N)"
    done
}

write_atomic() { # write_atomic <file> (stdin)
    mkdir -p "$(dirname "$1")" || return 1
    cat > "$1.rt.$$" && mv -f "$1.rt.$$" "$1"
}

# Andromeda rebuilds its content->system index from the manifests; same call as the official
# "Refresh Automatic Core Assign" task. Skipped silently where the script does not exist.
refresh_assign() { [ -x /opt/muos/script/system/assign.sh ] && /opt/muos/script/system/assign.sh -p -v >/dev/null 2>&1; return 0; }

do_apply() {
    N="${1:-$(cur_mode)}"
    build_both "$N"
    if [ "$(layout)" = "single" ]; then
        F="$USERM/core.json"; B="$BUNDLED/core.json"
        if [ -s "$F" ] && jq -e 'type=="object"' "$F" >/dev/null 2>&1; then BASE="$F"
        elif [ -s "$B" ]; then BASE="$B"
        else die "no core.json found (neither user nor bundled)"; fi
        [ -s "$F" ] && [ ! -e "$F.rtcore.bak" ] && cp -f "$F" "$F.rtcore.bak"
        OUT="$(jq --arg gk "$GC_KEY" --arg wk "$WII_KEY" --argjson gc "$GC_JSON" --argjson wii "$WII_JSON" \
              '.[$gk]=$gc | .[$wk]=$wii' "$BASE")" || die "merge failed"
        # sanity: every system that existed must still exist
        printf '%s' "$OUT" | jq -e --slurpfile b "$BASE" '(keys) as $k | ($b[0]|keys) | all(. as $x | $k | index($x))' >/dev/null || die "merge would drop systems, aborted"
        printf '%s\n' "$OUT" | write_atomic "$F" || die "cannot write $F"
    else
        for pair in "$GC_KEY|$GC_JSON" "$WII_KEY|$WII_JSON"; do
            K="${pair%%|*}"; J="${pair#*|}"
            printf '%s' "$J" | jq '{catalogue, lookup, default, friendly, bios, external} + (if .governor then {governor} else {} end)' \
                | write_atomic "$USERM/core/$NS/$K.json" || die "cannot write $K.json"
        done
    fi
    printf '# Dolphin Rt:Core - switch_weapon state\nMODE=%s\n' "$N" > "$STATE.tmp" && mv -f "$STATE.tmp" "$STATE"
    refresh_assign
    say "[OK] GameCube: $(printf '%s' "$GC_JSON" | jq '.external|length') profiles, Wii: $(printf '%s' "$WII_JSON" | jq '.external|length') profiles (mode $N, $(layout) manifest)"
}

is_current() {   # exit 0 when the manifest already holds exactly our systems for the active mode
    N="$(cur_mode)"; build_both "$N" 2>/dev/null || return 1
    if [ "$(layout)" = "single" ]; then
        F="$USERM/core.json"; [ -s "$F" ] || return 1
        jq -e --arg gk "$GC_KEY" --arg wk "$WII_KEY" --argjson gc "$GC_JSON" --argjson wii "$WII_JSON" \
           '.[$gk]==$gc and .[$wk]==$wii' "$F" >/dev/null 2>&1
    else
        for pair in "$GC_KEY|$GC_JSON" "$WII_KEY|$WII_JSON"; do
            K="${pair%%|*}"; J="${pair#*|}"; f="$USERM/core/$NS/$K.json"; [ -s "$f" ] || return 1
            jq -e --argjson j "$J" '.external==$j.external and .default==$j.default and .friendly==$j.friendly' "$f" >/dev/null 2>&1 || return 1
        done
    fi
}

do_remove() {
    N="$(cur_mode)"; build_both "$N"
    if [ "$(layout)" = "single" ]; then
        F="$USERM/core.json"; [ -s "$F" ] || { say "nothing to remove"; return 0; }
        OUT="$(jq --arg gk "$GC_KEY" --arg wk "$WII_KEY" 'del(.[$gk]) | del(.[$wk])' "$F")" || die "remove failed"
        printf '%s\n' "$OUT" | write_atomic "$F" || die "cannot write $F"
    else
        rm -f "$USERM/core/$NS/$GC_KEY.json" "$USERM/core/$NS/$WII_KEY.json"
    fi
    refresh_assign
    say "[OK] GameCube/Wii entries removed from the manifest"
}

do_status() {
    N="$(cur_mode)"
    say "mode.conf      : MODE $N ($([ "$N" = 1 ] && echo 'standard only' || echo 'all tiers'))"
    say "manifest layout: $(layout)"
    if is_current; then say "manifest state : OK (matches mode $N)"; else say "manifest state : MISSING or OUT OF DATE (run: manifest_tool.sh apply)"; fi
    if [ "$(layout)" = "single" ] && [ -s "$USERM/core.json" ]; then
        say "user core.json : $(jq 'length' "$USERM/core.json") systems"
    fi
}

case "$1" in
    apply)  do_apply "$2" ;;
    ensure) is_current && exit 0; do_apply ;;
    remove) do_remove ;;
    status) do_status ;;
    *) echo "usage: $0 apply [1|2] | ensure | remove | status"; exit 1 ;;
esac
