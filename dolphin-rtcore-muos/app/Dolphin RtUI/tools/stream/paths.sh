#!/bin/sh
# Rt:Stream — shared paths + safe config load. Sourced by every tool.
STREAM_TOOLS="$(cd "$(dirname "$0")" && pwd)"
APPDIR="$(cd "$STREAM_TOOLS/../.." && pwd)"
DATA="$APPDIR/data/stream"
# Moonlight: prefer a system-wide muOS Moonlight app when one exists (it brings its own libs and
# its paired keys, so no re-pairing); otherwise use the copy bundled in lib/.
MUOS_MOON="${MUOS_MOON_DIR:-/opt/muos/share/application/Moonlight}"
if [ -x "$MUOS_MOON/moonlight/moonlight" ]; then
    MOONLIGHT="$MUOS_MOON/moonlight/moonlight"
    KEYDIR="$MUOS_MOON/keys"
    SYSLIBS="$MUOS_MOON/libs"
else
    MOONLIGHT="$APPDIR/lib/moonlight"
    KEYDIR="$DATA/keys"
    SYSLIBS=""
fi
# one place for the library path (used by pair, list, launch and the library check)
MOON_LD="$APPDIR/lib:${SYSLIBS:+$SYSLIBS:}/usr/lib/compat${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p "$DATA/covers" "$DATA/keys" 2>/dev/null

HOST=""; SYNC_PORT="8765"; WIDTH="640"; HEIGHT="480"; FPS="60"; BITRATE="10000"
CODEC="auto"; REMOTE="auto"; SOPS="yes"; PLATFORM=""; MAC=""; TOKEN=""
# stream.conf only ever holds KEY="value" lines with [A-Za-z0-9.:_- ] values
# (the UI enforces it), so a defensive re-check before sourcing is enough.
if [ -f "$DATA/stream.conf" ] && ! grep -v -E '^(#.*|[A-Z_]+="[A-Za-z0-9.:_ -]*"|)$' "$DATA/stream.conf" | grep -q .; then
    # shellcheck disable=SC1091
    . "$DATA/stream.conf"
fi

# Portal endpoints (override in the environment if your PC portal differs)
SYNC_LIBRARY_PATH="${SYNC_LIBRARY_PATH:-/library.tsv}"
SYNC_COVER_PATH="${SYNC_COVER_PATH:-/covers/}"

fetch() {  # fetch <url> <outfile> [max-seconds]
    if command -v curl >/dev/null 2>&1; then
        curl -fsS -m "${3:-15}" -o "$2" "$1"
    else
        wget -q -T "${3:-15}" -O "$2" "$1"
    fi
}
atomic_write() { # atomic_write <file>  (stdin -> file)
    cat > "$1.tmp" && mv -f "$1.tmp" "$1"
}
need_host() {
    [ -n "$HOST" ] || { echo "ERR no PC address set (Stream settings > PC address)"; return 1; }
}

# missing_libs: prints the shared libraries moonlight cannot find (empty = all present).
# Uses the dynamic loader's trace mode, so it needs neither ldd nor readelf.
missing_libs() {
    [ -x "$MOONLIGHT" ] || return 0
    LD_LIBRARY_PATH="$MOON_LD" LD_TRACE_LOADED_OBJECTS=1 "$MOONLIGHT" 2>&1 \
        | sed -n 's/^[[:space:]]*\(lib[^ ]*\) => not found.*/\1/p' | tr '\n' ' '
}
