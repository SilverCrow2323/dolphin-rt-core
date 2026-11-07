#!/bin/bash
# ============================================================
#  Bash Arsenal — Common helpers
#  SPDW Factory Lab / sirpips aka SilverCrow2323
# ============================================================
EMU="/opt/muos/share/emulator/dolphin"
CFG="$EMU/Config"
RTSYS="$EMU/RtSys"
LOGDIR="$RTSYS/logs"
FACTORY="$RTSYS/factory/Config"

get_ini() {
    local f="$1" key="$2"
    [ -f "$f" ] || return 0
    grep -E "^[[:space:]]*${key}[[:space:]]*=" "$f" 2>/dev/null \
        | head -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]+$//'
}

set_ini() {
    local file="$1" section="$2" key="$3" value="$4"
    [ -f "$file" ] || return 1
    local tmp="${file}.tmp.$$"
    if grep -q "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
        sed "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file" > "$tmp"
    elif grep -q "^\[${section}\]" "$file"; then
        awk -v sec="[${section}]" -v kv="${key} = ${value}" \
            '{ print; if ($0 == sec) print kv }' "$file" > "$tmp"
    else
        cp "$file" "$tmp"
        printf "\n[%s]\n%s = %s\n" "$section" "$key" "$value" >> "$tmp"
    fi
    if [ -s "$tmp" ] && grep -q '^\[' "$tmp"; then mv "$tmp" "$file"; return 0; fi
    rm -f "$tmp"; return 1
}
