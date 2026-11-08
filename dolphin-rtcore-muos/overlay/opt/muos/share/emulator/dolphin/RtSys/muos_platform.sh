#!/bin/sh
# Detect the installed muOS generation and the core-registration API it exposes.
# Source this file; it intentionally does not mutate the device filesystem.

RT_MUOS_ROOT="${RT_MUOS_ROOT:-/opt/muos}"

# Load muOS path/version helpers when the caller has not already done so.
if [ -z "${MUOS_STORE_DIR:-}" ] && [ -r "$RT_MUOS_ROOT/script/var/func.sh" ]; then
    # shellcheck disable=SC1090
    . "$RT_MUOS_ROOT/script/var/func.sh" 2>/dev/null || true
fi

RT_MUOS_SHARE_DIR="${RT_MUOS_SHARE_DIR:-${MUOS_SHARE_DIR:-$RT_MUOS_ROOT/share}}"
RT_MUOS_STORE_DIR="${RT_MUOS_STORE_DIR:-${MUOS_STORE_DIR:-/run/muos/storage}}"
RT_MUOS_VERSION_FILE="${RT_MUOS_VERSION_FILE:-$RT_MUOS_ROOT/config/system/version}"
RT_MUOS_MANIFEST_DIR="${RT_MUOS_MANIFEST_DIR:-${RT_BUNDLED_MANIFEST:-$RT_MUOS_SHARE_DIR/info/manifest}}"
RT_MUOS_ASSIGN_DIR="${RT_MUOS_ASSIGN_DIR:-$RT_MUOS_SHARE_DIR/info/assign}"

if [ -z "${RT_MUOS_VERSION:-}" ] && command -v GET_VAR >/dev/null 2>&1; then
    RT_MUOS_VERSION="$(GET_VAR system version 2>/dev/null || true)"
fi
if [ -z "${RT_MUOS_VERSION:-}" ] && [ -r "$RT_MUOS_VERSION_FILE" ]; then
    IFS= read -r RT_MUOS_VERSION < "$RT_MUOS_VERSION_FILE" || true
fi
RT_MUOS_VERSION="$(printf '%s' "${RT_MUOS_VERSION:-unknown}" | tr '[:lower:]' '[:upper:]' | tr -d '\r')"

case "$RT_MUOS_VERSION" in
    *ANDROMEDA*) RT_MUOS_RELEASE="Andromeda" ;;
    *JACARANDA*) RT_MUOS_RELEASE="Jacaranda" ;;
    *SUPERNOVA*) RT_MUOS_RELEASE="Supernova" ;;
    *GOOSE*) RT_MUOS_RELEASE="Goose" ;;
    *PIXIE*) RT_MUOS_RELEASE="Pixie" ;;
    *BANANA*) RT_MUOS_RELEASE="Banana" ;;
    *) RT_MUOS_RELEASE="Unknown" ;;
esac

# The filesystem capability wins over the marketing version string. This also
# handles point releases and downstream builds that retain the same manifest API.
if [ -d "$RT_MUOS_MANIFEST_DIR/core" ]; then
    RT_MUOS_REGISTRATION_LAYOUT="split"
elif [ -r "$RT_MUOS_MANIFEST_DIR/core.json" ]; then
    RT_MUOS_REGISTRATION_LAYOUT="single"
else
    case "$RT_MUOS_RELEASE" in
        Jacaranda|Goose|Pixie|Banana)
            RT_MUOS_REGISTRATION_LAYOUT="legacy-assign"
            ;;
        *)
            if [ -d "$RT_MUOS_ASSIGN_DIR" ]; then
                RT_MUOS_REGISTRATION_LAYOUT="legacy-assign"
            else
                RT_MUOS_REGISTRATION_LAYOUT="unsupported"
            fi
            ;;
    esac
fi
