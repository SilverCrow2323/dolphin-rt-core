#!/bin/bash
# Shared muOS Content Explorer -> Dolphin Rt:UI profile bridge.
# workshop/rtcoreprofile is the canonical editable profile catalogue.
# Config/ is only the active runtime projection consumed by Dolphin.

rt_profile_slug() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

rt_resolve_ce_core() {
    local core root slug dir name normalized
    core="$(printf '%s' "$1" | sed 's/^ext-dolphin-//')"
    root="$2"
    RT_ORIENT="upright"
    RT_VARIANT=""

    case "$core" in
        *-sideways) RT_ORIENT="sideways"; core="$(printf '%s' "$core" | sed 's/-sideways$//')" ;;
        *-upright)  RT_ORIENT="upright";  core="$(printf '%s' "$core" | sed 's/-upright$//')" ;;
    esac
    case "$core" in
        *-lite)     RT_VARIANT="lite"; core="$(printf '%s' "$core" | sed 's/-lite$//')" ;;
        *-std)      RT_VARIANT="std";  core="$(printf '%s' "$core" | sed 's/-std$//')" ;;
        *-standard) RT_VARIANT="std";  core="$(printf '%s' "$core" | sed 's/-standard$//')" ;;
        *-max)      RT_VARIANT="max";  core="$(printf '%s' "$core" | sed 's/-max$//')" ;;
    esac

    slug="$(rt_profile_slug "$core")"
    RT_PROFILE="Default"
    if [ -d "$root" ]; then
        for dir in "$root"/*/; do
            [ -d "$dir" ] || continue
            name="$(basename "$dir")"
            normalized="$(rt_profile_slug "$name")"
            if [ -n "$slug" ] && [ "$normalized" = "$slug" ]; then
                RT_PROFILE="$name"
                break
            fi
        done
    fi

    if [ -d "$root/$RT_PROFILE/lite" ] || [ -d "$root/$RT_PROFILE/std" ] || [ -d "$root/$RT_PROFILE/max" ]; then
        [ -n "$RT_VARIANT" ] || RT_VARIANT="std"
        [ -d "$root/$RT_PROFILE/$RT_VARIANT" ] || RT_VARIANT="std"
    else
        RT_VARIANT=""
    fi
}

rt_read_rtid_launch() {
    local file="$1" key="$2"
    [ -r "$file" ] && [ -n "$key" ] || return 0
    awk -F= -v wanted="$key" '
        /^[[:space:]]*\[/ {
            section = ($0 ~ /^[[:space:]]*\[LAUNCH\][[:space:]]*$/)
            next
        }
        section {
            k = $1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
            if (k == wanted) {
                sub(/^[^=]*=/, "")
                gsub(/^[[:space:]]+|[[:space:]\r]+$/, "")
                print
                exit
            }
        }
    ' "$file"
}

rt_safe_profile_name() {
    case "$1" in
        ""|.|..|*..*|*/*|*[!A-Za-z0-9_.\ -]*) return 1 ;;
        *) return 0 ;;
    esac
}

rt_safe_leaf_name() {
    case "$1" in
        ""|.|..|*..*|*/*|*[!A-Za-z0-9_.\ -]*) return 1 ;;
        *) return 0 ;;
    esac
}

rt_extract_game_id() {
    local rom="$1" magic offset id base
    [ -f "$rom" ] || return 1
    magic="$(dd if="$rom" bs=1 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    case "$magic" in
        57424653) offset=512 ;;
        52565a*|574941*) offset=88 ;;
        4349534f) offset=32768 ;;
        *) offset=0 ;;
    esac
    id="$(dd if="$rom" bs=1 skip="$offset" count=6 2>/dev/null | tr -cd 'A-Z0-9' | head -c 6)"
    case "$id" in
        [A-Z][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])
            case "$id" in ISO|GCM|RVZ|WBFS|WIA|GCZ) ;;
                *) printf '%s\n' "$id"; return 0 ;;
            esac
            ;;
    esac

    base="$(basename "$rom")"
    id="$(printf '%s\n' "$base" | sed -nE 's/.*[\[\(\{]([A-Z0-9]{6})[\]\)\}].*/\1/p')"
    case "$id" in
        [A-Z][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])
            case "$id" in ISO|GCM|RVZ|WBFS|WIA|GCZ) return 1 ;; esac
            printf '%s\n' "$id"
            return 0
            ;;
    esac
    return 1
}
