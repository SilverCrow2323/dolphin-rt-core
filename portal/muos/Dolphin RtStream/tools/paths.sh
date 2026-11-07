#!/bin/sh
# paths.sh - resolve love/moonlight/keys. Sourced by mux_launch.sh, pair.sh, test.sh.
# Requires $LOVEDIR exported. Prefers the muOS-bundled Moonlight app, falls back
# to bundled copies under $LOVEDIR.
#
# gptokeyb2 stays bundled: it is NOT in the muOS Moonlight folder.

: "${LOVEDIR:?LOVEDIR not set}"

MUOS_MOON="${MUOS_MOON_DIR:-/opt/muos/share/application/Moonlight}"

# Default = bundled (legacy / portable)
LOVE_BIN="$LOVEDIR/love"
MOONDIR="$LOVEDIR/moonlight"
KEYDIR="$LOVEDIR/keys"
SYSLIBS=""

# Prefer muOS Moonlight if both binaries are present
if [ -x "$MUOS_MOON/love" ] && [ -x "$MUOS_MOON/moonlight/moonlight" ]; then
    LOVE_BIN="$MUOS_MOON/love"
    MOONDIR="$MUOS_MOON/moonlight"
    KEYDIR="$MUOS_MOON/keys"
    [ -d "$MUOS_MOON/libs" ] && SYSLIBS="$MUOS_MOON/libs"
fi

# gptokeyb2: bundled first, then PortMaster (legacy)
GPTK_BIN=""
if [ -x "$LOVEDIR/libs/gptokeyb2" ]; then
    GPTK_BIN="$LOVEDIR/libs/gptokeyb2"
else
    PM_DIR="$(GET_VAR "device" "storage/rom/mount" 2>/dev/null)/MUOS/PortMaster"
    [ -x "$PM_DIR/gptokeyb2" ] && GPTK_BIN="$PM_DIR/gptokeyb2"
fi

# LD_LIBRARY_PATH in ordine: system moonlight libs, portable overrides, love compat
case ":${LD_LIBRARY_PATH:-}:" in
    *":$LOVEDIR/libs:"*) : ;;   # already set
    *)
        LD_LIBRARY_PATH="$SYSLIBS:$LOVEDIR/libs:/usr/lib/compat:${LD_LIBRARY_PATH:-}"
        export LD_LIBRARY_PATH
        ;;
esac
