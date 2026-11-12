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

rt_safe_game_id() {
    case "$1" in
        ""|*[!A-Za-z0-9_-]*) return 1 ;;
        *) ;;
    esac
    [ "${#1}" -ge 4 ] && [ "${#1}" -le 16 ]
}

# ActiveConfig in rtgameset_data.ini is the canonical GameSettings selector.
# RTID [LAUNCH] GameSettings is read only as a migration fallback for old cards.
rt_read_active_gameset() {
    local game_id="$1" root="$2" meta active
    [ -n "$game_id" ] || return 1
    meta="$root/$game_id/rtgameset_data.ini"
    [ -r "$meta" ] || return 1
    active="$(awk -F= '
        /^[[:space:]]*\[/ {
            section = ($0 ~ /^[[:space:]]*\[GameSettings\][[:space:]]*$/)
            next
        }
        section {
            key = $1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            if (key == "ActiveConfig") {
                sub(/^[^=]*=/, "")
                gsub(/^[[:space:]]+|[[:space:]]+$/, "")
                print
                exit
            }
        }
    ' "$meta")"
    rt_safe_leaf_name "$active" || return 1
    case "$active" in *.ini) ;; *) return 1 ;; esac
    [ -f "$root/$game_id/$active" ] || return 1
    printf '%s\n' "$active"
}

# Persist a legacy per-game selection into the same ActiveConfig metadata used
# by GamesetPicker, Rt:UI and the Python merge helper.
rt_write_active_gameset() {
    local game_id="$1" root="$2" active="$3" meta
    [ -n "$game_id" ] || return 1
    rt_safe_leaf_name "$active" || return 1
    case "$active" in *.ini) ;; *) return 1 ;; esac
    [ -f "$root/$game_id/$active" ] || return 1
    meta="$root/$game_id/rtgameset_data.ini"
    command -v python3 >/dev/null 2>&1 || return 1
    python3 - "$meta" "$active" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
active = sys.argv[2]
lines = path.read_text(encoding="utf-8", errors="replace").splitlines() if path.is_file() else []
output = []
in_section = False
found_section = False
written = False
for line in lines:
    section = re.match(r"^\s*\[([^\]]+)\]\s*$", line)
    if section:
        if in_section and not written:
            output.append(f"ActiveConfig = {active}")
            written = True
        in_section = section.group(1).strip() == "GameSettings"
        found_section = found_section or in_section
        output.append(line)
        continue
    if in_section and re.match(r"^\s*ActiveConfig\s*=", line):
        if not written:
            output.append(f"ActiveConfig = {active}")
            written = True
        continue
    output.append(line)

if not found_section:
    if output and output[-1].strip():
        output.append("")
    output.extend(["[GameSettings]", f"ActiveConfig = {active}"])
elif in_section and not written:
    output.append(f"ActiveConfig = {active}")

path.parent.mkdir(parents=True, exist_ok=True)
temporary = path.with_name(path.name + ".rt-tmp")
temporary.write_text("\n".join(output) + "\n", encoding="utf-8")
temporary.replace(path)
PY
}


# Project one selected workshop preset into Dolphin's native per-game file.
# Config/GameSettings is a runtime output only; Workshop remains authoritative.
rt_project_active_gameset() {
    local game_id="$1" root="$2" config_dir="$3" requested="$4"
    local chosen="" source target temporary

    rt_safe_game_id "$game_id" || return 1
    target="$config_dir/$game_id.ini"

    if [ "$requested" = "Disabled" ]; then
        rm -f "$target" "$target.rt-tmp"
        RT_ACTIVE_GAMESET=""
        return 0
    fi

    if [ -n "$requested" ]; then
        if rt_safe_leaf_name "$requested" \
           && [[ "$requested" == *.ini ]] \
           && [ -f "$root/$game_id/$requested" ]; then
            chosen="$requested"
        else
            printf '[Rt:Core] rejected invalid GameSettings selection for %s\n' "$game_id" >&2
        fi
    fi

    if [ -z "$chosen" ]; then
        chosen="$(rt_read_active_gameset "$game_id" "$root" 2>/dev/null || true)"
    fi

    if [ -z "$chosen" ]; then
        rm -f "$target" "$target.rt-tmp"
        RT_ACTIVE_GAMESET=""
        return 0
    fi

    source="$root/$game_id/$chosen"
    if [ ! -f "$source" ]; then
        rm -f "$target" "$target.rt-tmp"
        RT_ACTIVE_GAMESET=""
        return 1
    fi

    # A legacy RTID choice is imported once into the canonical metadata.
    rt_write_active_gameset "$game_id" "$root" "$chosen" || return 1

    mkdir -p "$config_dir"
    temporary="$target.rt-tmp.$"
    if ! cp -f "$source" "$temporary"; then
        rm -f "$temporary"
        return 1
    fi
    if ! mv -f "$temporary" "$target"; then
        rm -f "$temporary"
        return 1
    fi

    RT_ACTIVE_GAMESET="$chosen"
    return 0
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
    id="$(printf '%s\n' "$base" | grep -oE '(\[[A-Z0-9]{6}\]|\([A-Z0-9]{6}\)|\{[A-Z0-9]{6}\})' | head -n 1 | tr -cd 'A-Z0-9')"
    case "$id" in
        [A-Z][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])
            case "$id" in ISO|GCM|RVZ|WBFS|WIA|GCZ) return 1 ;; esac
            printf '%s\n' "$id"
            return 0
            ;;
    esac
    return 1
}
