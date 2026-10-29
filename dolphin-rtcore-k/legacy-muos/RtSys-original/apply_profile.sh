#!/bin/bash
# ============================================================
#  apply_profile.sh <PROFILE> <ORIENT> <NUMSTICKS>
#  Copies the correct INI files into Config/ active slots.
# ============================================================
PROFILE="$1"
ORIENT="$2"
NUMSTICKS="${3:-0}"

CFG="/opt/muos/share/emulator/dolphin/Config"
cd "$CFG" || exit 1

# ── Dolphin.ini + GFX.ini (base) ───────────────────────────
for f in Dolphin.ini GFX.ini; do
    if [ -f "$f.$PROFILE" ]; then
        cp -f "$f.$PROFILE" "$f"
    elif [ -f "$f.default" ]; then
        cp -f "$f.default" "$f"
    fi
done

# ── Logger.ini: verbose only for rtverbose ─────────────────
if echo "$PROFILE" | grep -q rtverbose; then
    [ -f Logger.ini.verbose ] && cp -f Logger.ini.verbose Logger.ini
else
    [ -f Logger.ini.default ] && cp -f Logger.ini.default Logger.ini
fi

# ── GCPadNew.ini ───────────────────────────────────────────
if [ -f "GCPadNew.ini.${NUMSTICKS}joy" ]; then
    cp -f "GCPadNew.ini.${NUMSTICKS}joy" GCPadNew.ini
elif [ -f "GCPadNew.ini.default" ]; then
    cp -f "GCPadNew.ini.default" GCPadNew.ini
fi

# ── WiimoteNew.ini (with orientation) ──────────────────────
SUFFIX=""
[ "$ORIENT" = "sideways" ] && SUFFIX=".sideways"

if [ -f "WiimoteNew.ini.${NUMSTICKS}joy${SUFFIX}" ]; then
    cp -f "WiimoteNew.ini.${NUMSTICKS}joy${SUFFIX}" WiimoteNew.ini
elif [ -f "WiimoteNew.ini.${NUMSTICKS}joy" ]; then
    cp -f "WiimoteNew.ini.${NUMSTICKS}joy" WiimoteNew.ini
elif [ -f "WiimoteNew.ini.default" ]; then
    cp -f "WiimoteNew.ini.default" WiimoteNew.ini
fi

exit 0
