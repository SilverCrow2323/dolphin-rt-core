#!/usr/bin/env bash
# Helpers for deciding whether Hotkeys.ini is keyboard-driven or native SDL.
# Only [Hotkeys1] is authoritative; other sections may have unrelated Device keys.

hotkeys_device() {
    local file="${1:-}"
    [ -r "$file" ] || return 1
    awk '
        /^[[:space:]]*\[/ {
            in_hotkeys = ($0 ~ /^[[:space:]]*\[Hotkeys1\][[:space:]]*$/)
            next
        }
        in_hotkeys {
            line = $0
            sub(/[;#].*$/, "", line)
            if (line ~ /^[[:space:]]*Device[[:space:]]*=/) {
                sub(/^[[:space:]]*Device[[:space:]]*=/, "", line)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                print line
                exit
            }
        }
    ' "$file"
}

hotkeys_uses_keyboard() {
    local device
    device="$(hotkeys_device "$1")" || return 1
    [ "$(printf '%s' "$device" | tr '[:upper:]' '[:lower:]')" = "keyboard" ]
}
