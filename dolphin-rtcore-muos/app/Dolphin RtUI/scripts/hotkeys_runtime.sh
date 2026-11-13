#!/usr/bin/env bash
# Dolphin 2606 uses [Hotkeys] / SDL/0/Keyboard Mouse. Older installations
# may still use [Hotkeys1] / Keyboard; support that as a fallback.
hotkeys_device() {
    local file="${1:-}"
    [ -r "$file" ] || return 1
    awk '
        /^[[:space:]]*\[/ {
            section = $0
            gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", section)
            next
        }
        section == "Hotkeys" && !current_found {
            line = $0
            sub(/[;#].*$/, "", line)
            if (line ~ /^[[:space:]]*Device[[:space:]]*=/) {
                sub(/^[[:space:]]*Device[[:space:]]*=/, "", line)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                current = line
                current_found = 1
            }
        }
        section == "Hotkeys1" && !legacy_found {
            line = $0
            sub(/[;#].*$/, "", line)
            if (line ~ /^[[:space:]]*Device[[:space:]]*=/) {
                sub(/^[[:space:]]*Device[[:space:]]*=/, "", line)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                legacy = line
                legacy_found = 1
            }
        }
        END {
            if (current_found) print current
            else if (legacy_found) print legacy
        }
    ' "$file"
}

hotkeys_uses_keyboard() {
    local device
    device="$(hotkeys_device "$1")" || return 1
    case "$(printf '%s' "$device" | tr '[:upper:]' '[:lower:]')" in
        keyboard|"sdl/0/keyboard mouse"|"sdl/0/keyboard") return 0 ;;
        *) return 1 ;;
    esac
}
