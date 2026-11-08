#!/bin/sh
# ============================================================
# Dolphin Rt:Core — platform-aware GameCube/Wii registration
#
# apply [1|2]  register the current or selected profile set
# ensure       repair registration only when the manifest/assign map is stale
# remove       remove only Rt:Core's GameCube/Wii entries
# status       report detected muOS release, layout and registration state
#
# Andromeda 2606: single core.json + generated assign.json
# New manifest layouts: core/<Namespace>/<System>.json + generated assign.json
# Jacaranda/older releases: info/assign/<System>/*.ini
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/muos_platform.sh"

SW="${RT_SWITCH_WEAPON_DIR:-$SCRIPT_DIR/switch_weapon}"
STORE="$RT_MUOS_STORE_DIR"
USERM="$STORE/info/manifest"
BUNDLED="$RT_MUOS_MANIFEST_DIR"
NS="Nintendo"
STATE="$SW/mode.conf"
OLD_GC_NAME="Nintendo Gamecube"
OLD_WII_NAME="Nintendo Wii"

say() { printf '  %s\n' "$*"; }
die() { printf '  [ERR] %s\n' "$*" >&2; exit 1; }
need_jq() { command -v jq >/dev/null 2>&1 || die "jq is required for manifest-based muOS builds"; }

cur_mode() {
    m="$(sed -n 's/^MODE=\([12]\)[[:space:]]*$/\1/p' "$STATE" 2>/dev/null | head -n 1)"
    echo "${m:-1}"
}

sys_name() {
    sed -n 's/^name=//p' "$1/global.ini" | head -n 1 | tr -d '\r'
}

validate_sources() {
    n="$1"
    for kind in gc wii; do
        dir="$SW/$kind/mode $n"
        [ -s "$dir/global.ini" ] || die "missing source global.ini: $dir"
        name="$(sys_name "$dir")"
        default="$(sed -n 's/^default=//p' "$dir/global.ini" | head -n 1 | tr -d '\r')"
        case "$name" in ""|*/*|*..*) die "invalid system name in $dir/global.ini" ;; esac
        [ -n "$default" ] && [ -s "$dir/$default.ini" ] || die "default profile '$default' is missing in $dir"
        count=0
        for f in "$dir"/*.ini; do
            [ -f "$f" ] || continue
            [ "$(basename "$f")" = "global.ini" ] || count=$((count + 1))
        done
        [ "$count" -gt 0 ] || die "no profile INI files found in $dir"
    done
}

count_profiles() {
    count=0
    for f in "$1"/*.ini; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" = "global.ini" ] || count=$((count + 1))
    done
    echo "$count"
}

build_system() {
    dir="$1"
    {
        awk -F= '
          /^\[/ { sec=$0; gsub(/[\[\]\r]/,"",sec); next }
          { sub(/\r$/,"") }
          sec=="global" && $1 ~ /^(name|default|catalogue|lookup|governor)$/ { print "G\t" $1 "\t" substr($0,index($0,"=")+1) }
          sec=="friendly" && NF>0 && $0!="" { print "F\t" $0 }
        ' "$dir/global.ini"
        for f in "$dir"/*.ini; do
            [ -f "$f" ] || continue
            [ "$(basename "$f")" = "global.ini" ] && continue
            awk -F= '
              /^\[/ { sec=$0; gsub(/[\[\]\r]/,"",sec); next }
              { sub(/\r$/,"") }
              $1=="name" && !n { n=substr($0,6) }
              $1=="core" && !c { c=substr($0,6) }
              $1=="exec" && !e { e=substr($0,6) }
              END {
                if (n!="" && c!="" && e!="") {
                  k=FILENAME; sub(/.*\//,"",k); sub(/\.ini$/,"",k)
                  sub(/.*\//,"",e); sub(/^ext-/,"",e)
                  print "E\t" k "\t" n "\t" c "\t" e
                }
              }
            ' "$f"
        done
    } | jq -Rn --arg ns "$NS" '
        [inputs | split("\t")] as $r
        | ($r | map(select(.[0]=="G")) | map({(.[1]): .[2]}) | add) as $g
        | {
            name: $g.name, namespace: $ns,
            catalogue: ($g.catalogue // $g.name),
            lookup: (($g.lookup // "0") | tonumber),
            default: $g.default,
            runtime: "external",
            friendly: ($r | map(select(.[0]=="F") | .[1])),
            bios: [],
            external: ($r | map(select(.[0]=="E") | {(.[1]): {name: .[2], core: .[3], launcher: .[4]}}) | add)
          }
        + (if ($g.governor // "") != "" then {governor: $g.governor} else {} end)'
}

build_both() {
    n="$1"
    validate_sources "$n"
    GC_KEY="$(sys_name "$SW/gc/mode $n")"
    WII_KEY="$(sys_name "$SW/wii/mode $n")"
    GC_JSON="$(build_system "$SW/gc/mode $n")" || die "cannot build GameCube manifest entry"
    WII_JSON="$(build_system "$SW/wii/mode $n")" || die "cannot build Wii manifest entry"
    for item in "$GC_JSON" "$WII_JSON"; do
        printf '%s' "$item" | jq -e '(.namespace=="Nintendo") and ((.external|length)>0) and (.default as $d | .external | has($d))' >/dev/null \
            || { system_name="$(printf '%s' "$item" | jq -r '.name // "unknown"')"; die "invalid profile manifest entry for $system_name"; }
    done
}

write_atomic() {
    path="$1"
    tmp="$path.rt.$$"
    mkdir -p "$(dirname "$path")" || return 1
    if ! cat > "$tmp"; then rm -f "$tmp"; return 1; fi
    if ! mv -f "$tmp" "$path"; then rm -f "$tmp"; return 1; fi
}

refresh_assign() {
    tool="${RT_MUOS_ASSIGN_REFRESH:-$RT_MUOS_ROOT/script/system/assign.sh}"
    [ -x "$tool" ] || die "manifest is updated, but muOS automatic assignment tool is missing: $tool"
    "$tool" -p -v || die "muOS assign.sh failed; check MUOS/log/assign_gen.txt"
    sync
    # Content Explorer consumes this generated alias map as well as the core manifest.
    jq -e --arg gc "$GC_KEY" --arg wii "$WII_KEY" \
        '.["nintendogamecube"]==$gc and .["nintendowii"]==$wii' "$USERM/assign.json" >/dev/null 2>&1 \
        || die "muOS assign.sh completed but assign.json does not map Nintendo GameCube/Wii; check MUOS/log/assign_gen.txt"
}

legacy_replace_system() {
    source_dir="$1"
    target="$2"
    parent="$(dirname "$target")"
    stage="$parent/.$(basename "$target").rtcore-stage.$$"
    backup="$parent/.$(basename "$target").rtcore-backup.$$"
    rm -rf "$stage" "$backup"
    mkdir -p "$stage" || return 1
    if [ -d "$target" ]; then
        cp -a "$target/." "$stage/" || { rm -rf "$stage"; return 1; }
    fi
    rm -f "$stage/global.ini"
    for stale in "$stage"/dolphin\ -\ *.ini; do
        [ -f "$stale" ] && rm -f "$stale"
    done
    cp -f "$source_dir"/*.ini "$stage/" || { rm -rf "$stage"; return 1; }
    [ -s "$stage/global.ini" ] || { rm -rf "$stage"; return 1; }

    if [ -e "$target" ]; then
        mv "$target" "$backup" || { rm -rf "$stage"; return 1; }
    fi
    if mv "$stage" "$target"; then
        rm -rf "$backup"
        return 0
    fi
    [ -e "$backup" ] && mv "$backup" "$target"
    rm -rf "$stage"
    return 1
}

legacy_apply() {
    n="$1"
    gc_source="$SW/gc/mode $n"
    wii_source="$SW/wii/mode $n"
    mkdir -p "$RT_MUOS_ASSIGN_DIR" || die "cannot create legacy assign directory: $RT_MUOS_ASSIGN_DIR"
    legacy_replace_system "$gc_source" "$RT_MUOS_ASSIGN_DIR/$GC_KEY" || die "cannot stage GameCube legacy core assignments"
    legacy_replace_system "$wii_source" "$RT_MUOS_ASSIGN_DIR/$WII_KEY" || die "cannot stage Wii legacy core assignments"

    # Remove the spelling used by older Rt:Core builds without touching unrelated systems.
    for old in "$RT_MUOS_ASSIGN_DIR/$OLD_GC_NAME" "$RT_MUOS_ASSIGN_DIR/$OLD_WII_NAME"; do
        [ "$old" = "$RT_MUOS_ASSIGN_DIR/$GC_KEY" ] && continue
        [ "$old" = "$RT_MUOS_ASSIGN_DIR/$WII_KEY" ] && continue
        if [ -d "$old" ]; then
            for stale in "$old"/dolphin\ -\ *.ini; do [ -f "$stale" ] && rm -f "$stale"; done
            rm -f "$old/global.ini"
            rmdir "$old" 2>/dev/null || true
        fi
    done
    printf '# Dolphin Rt:Core - switch_weapon state\nMODE=%s\n' "$n" > "$STATE.tmp" && mv -f "$STATE.tmp" "$STATE"
    sync
}

legacy_system_current() {
    source_dir="$1"
    target="$2"
    [ -s "$target/global.ini" ] && cmp -s "$source_dir/global.ini" "$target/global.ini" || return 1
    for f in "$source_dir"/*.ini; do
        [ -f "$f" ] || continue
        cmp -s "$f" "$target/$(basename "$f")" || return 1
    done
    for f in "$target"/dolphin\ -\ *.ini; do
        [ -f "$f" ] || continue
        [ -f "$source_dir/$(basename "$f")" ] || return 1
    done
    return 0
}

legacy_current() {
    n="$1"
    legacy_system_current "$SW/gc/mode $n" "$RT_MUOS_ASSIGN_DIR/$GC_KEY" &&
    legacy_system_current "$SW/wii/mode $n" "$RT_MUOS_ASSIGN_DIR/$WII_KEY"
}

legacy_remove() {
    for key in "$GC_KEY" "$WII_KEY" "$OLD_GC_NAME" "$OLD_WII_NAME"; do
        dir="$RT_MUOS_ASSIGN_DIR/$key"
        [ -d "$dir" ] || continue
        rm -f "$dir/global.ini"
        for f in "$dir"/dolphin\ -\ *.ini; do [ -f "$f" ] && rm -f "$f"; done
        rmdir "$dir" 2>/dev/null || true
    done
}

manifest_apply() {
    n="$1"
    need_jq
    build_both "$n"

    if [ "$RT_MUOS_REGISTRATION_LAYOUT" = "single" ]; then
        file="$USERM/core.json"
        bundled="$BUNDLED/core.json"
        if [ -e "$file" ]; then
            jq -e 'type=="object"' "$file" >/dev/null 2>&1 || die "user core.json is invalid JSON; refusing to overwrite it"
            base="$file"
        elif [ -s "$bundled" ]; then
            jq -e 'type=="object"' "$bundled" >/dev/null 2>&1 || die "bundled core.json is invalid JSON"
            base="$bundled"
        else
            die "single-file manifest detected, but no core.json is readable"
        fi
        if [ "$base" = "$file" ] && [ ! -e "$file.rtcore.bak" ]; then
            cp -p "$file" "$file.rtcore.bak" || die "could not preserve the original core.json"
        fi
        out="$(jq --arg gk "$GC_KEY" --arg wk "$WII_KEY" \
                  --arg oldgc "$OLD_GC_NAME" --arg oldwii "$OLD_WII_NAME" \
                  --argjson gc "$GC_JSON" --argjson wii "$WII_JSON" \
                  'del(.[$oldgc]) | del(.[$oldwii]) | .[$gk]=$gc | .[$wk]=$wii' "$base")" || die "core.json merge failed"
        printf '%s' "$out" | jq -e --slurpfile before "$base" \
            '($before[0] | keys) as $old | (keys) as $new | all($old[]; . as $k | $new | index($k) != null)' >/dev/null \
            || die "merge would remove unrelated systems; aborted"
        printf '%s\n' "$out" | write_atomic "$file" || die "cannot write $file"
    else
        [ "$RT_MUOS_REGISTRATION_LAYOUT" = "split" ] || die "unsupported manifest layout: $RT_MUOS_REGISTRATION_LAYOUT"
        for spec in "$GC_KEY|$GC_JSON" "$WII_KEY|$WII_JSON"; do
            key="${spec%%|*}"
            json="${spec#*|}"
            file="$USERM/core/$NS/$key.json"
            printf '%s' "$json" | jq '{catalogue, lookup, default, friendly, bios, external, runtime} + (if .governor then {governor} else {} end)' \
                | write_atomic "$file" || die "cannot write split manifest: $file"
        done
        [ "$OLD_GC_NAME" = "$GC_KEY" ] || rm -f "$USERM/core/$NS/$OLD_GC_NAME.json"
        [ "$OLD_WII_NAME" = "$WII_KEY" ] || rm -f "$USERM/core/$NS/$OLD_WII_NAME.json"
    fi

    printf '# Dolphin Rt:Core - switch_weapon state\nMODE=%s\n' "$n" > "$STATE.tmp" && mv -f "$STATE.tmp" "$STATE"
    refresh_assign
    say "[OK] Nintendo GameCube: $(count_profiles "$SW/gc/mode $n") profiles; Nintendo Wii: $(count_profiles "$SW/wii/mode $n") profiles"
    say "[OK] muOS $RT_MUOS_VERSION ($RT_MUOS_RELEASE), manifest layout: $RT_MUOS_REGISTRATION_LAYOUT; Content Explorer assign map refreshed"
}

manifest_current() {
    need_jq
    build_both "$1" 2>/dev/null || return 1
    if [ "$RT_MUOS_REGISTRATION_LAYOUT" = "single" ]; then
        file="$USERM/core.json"
        [ -s "$file" ] || return 1
        jq -e --arg gk "$GC_KEY" --arg wk "$WII_KEY" \
            --arg oldgc "$OLD_GC_NAME" --arg oldwii "$OLD_WII_NAME" \
            --argjson gc "$GC_JSON" --argjson wii "$WII_JSON" \
            '(.[$gk]==$gc) and (.[$wk]==$wii) and (($oldgc==$gk) or (has($oldgc)|not)) and (($oldwii==$wk) or (has($oldwii)|not))' "$file" >/dev/null 2>&1 || return 1
    else
        for spec in "$GC_KEY|$GC_JSON" "$WII_KEY|$WII_JSON"; do
            key="${spec%%|*}"
            json="${spec#*|}"
            file="$USERM/core/$NS/$key.json"
            [ -s "$file" ] || return 1
            jq -e --argjson expected "$json" \
                '.catalogue==$expected.catalogue and .default==$expected.default and .friendly==$expected.friendly and .external==$expected.external' \
                "$file" >/dev/null 2>&1 || return 1
        done
        [ "$OLD_GC_NAME" = "$GC_KEY" ] || [ ! -e "$USERM/core/$NS/$OLD_GC_NAME.json" ] || return 1
        [ "$OLD_WII_NAME" = "$WII_KEY" ] || [ ! -e "$USERM/core/$NS/$OLD_WII_NAME.json" ] || return 1
    fi
    jq -e --arg gc "$GC_KEY" --arg wii "$WII_KEY" \
        '.["nintendogamecube"]==$gc and .["nintendowii"]==$wii' "$USERM/assign.json" >/dev/null 2>&1
}

do_remove() {
    n="$(cur_mode)"
    validate_sources "$n"
    GC_KEY="$(sys_name "$SW/gc/mode $n")"
    WII_KEY="$(sys_name "$SW/wii/mode $n")"
    case "$RT_MUOS_REGISTRATION_LAYOUT" in
        legacy-assign)
            legacy_remove
            say "[OK] Removed Rt:Core legacy assignments for GameCube and Wii"
            ;;
        single)
            need_jq
            file="$USERM/core.json"
            [ -s "$file" ] || { say "no user core.json to clean"; return 0; }
            out="$(jq --arg gk "$GC_KEY" --arg wk "$WII_KEY" \
                      --arg oldgc "$OLD_GC_NAME" --arg oldwii "$OLD_WII_NAME" \
                      'del(.[$gk]) | del(.[$wk]) | del(.[$oldgc]) | del(.[$oldwii])' "$file")" || die "could not remove Rt:Core entries"
            printf '%s\n' "$out" | write_atomic "$file" || die "could not write $file"
            refresh_assign
            say "[OK] Removed Rt:Core entries from the single-file manifest"
            ;;
        split)
            need_jq
            rm -f "$USERM/core/$NS/$GC_KEY.json" "$USERM/core/$NS/$WII_KEY.json" \
                  "$USERM/core/$NS/$OLD_GC_NAME.json" "$USERM/core/$NS/$OLD_WII_NAME.json"
            refresh_assign
            say "[OK] Removed Rt:Core entries from the split manifest"
            ;;
        *) die "unsupported muOS registration layout: $RT_MUOS_REGISTRATION_LAYOUT" ;;
    esac
    sync
}

do_status() {
    n="$(cur_mode)"
    say "muOS release     : $RT_MUOS_RELEASE"
    say "muOS version     : $RT_MUOS_VERSION"
    say "registration API : $RT_MUOS_REGISTRATION_LAYOUT"
    say "profile mode     : $n ($([ "$n" = "1" ] && echo 'standard only' || echo 'all tiers'))"
    validate_sources "$n"
    GC_KEY="$(sys_name "$SW/gc/mode $n")"
    WII_KEY="$(sys_name "$SW/wii/mode $n")"
    if [ "$RT_MUOS_REGISTRATION_LAYOUT" = "legacy-assign" ]; then
        if legacy_current "$n"; then say "registration     : OK"; else say "registration     : MISSING/STALE (run: manifest_tool.sh apply)"; fi
    elif manifest_current "$n"; then
        say "registration     : OK (Nintendo namespace + automatic assignment map)"
    else
        say "registration     : MISSING/STALE (run: manifest_tool.sh apply)"
    fi
}

case "${1:-status}" in
    apply)  manifest_apply "${2:-$(cur_mode)}" ;;
    ensure)
        n="$(cur_mode)"
        validate_sources "$n"
        GC_KEY="$(sys_name "$SW/gc/mode $n")"
        WII_KEY="$(sys_name "$SW/wii/mode $n")"
        if [ "$RT_MUOS_REGISTRATION_LAYOUT" = "legacy-assign" ]; then
            legacy_current "$n" && exit 0
            legacy_apply "$n"
            say "[OK] Legacy GameCube/Wii assignments repaired for muOS $RT_MUOS_VERSION"
        else
            manifest_current "$n" && exit 0
            manifest_apply "$n"
        fi
        ;;
    remove) do_remove ;;
    status) do_status ;;
    *) echo "usage: $0 apply [1|2] | ensure | remove | status"; exit 1 ;;
esac
