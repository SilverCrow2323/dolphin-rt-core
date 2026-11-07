#!/bin/sh
# HELP: Refresh Mods List | Rebuild Advanced Options from Load/ (skips empty).
# ICON: diagnostic
#
# ============================================================
#  [Bash Arsenal | Rt:CORE Sector]
# ============================================================
#
#  Ah. You again.
#
#  The old sensei returns. He scans the Load/ folder, he sees
#  the mods, he builds the toggles. He skips empty folders.
#  He cleans up orphans. He does not tolerate dead weight.
#
#  ------------------------------------------------------------
#  - Rungif
#    Still here. Still magnanimo. Still a bit tired.
#

. /opt/muos/script/var/func.sh

FRONTEND stop

CONF="/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/general_time.conf"
GENERAL_SLEEP=3
[ -f "$CONF" ] && . "$CONF" 2>/dev/null
[ -z "$GENERAL_SLEEP" ] && GENERAL_SLEEP=3

SCANNER="/opt/muos/share/emulator/dolphin/RtSys/bash_arsenal/scan_load.sh"
LOAD_DIR="/opt/muos/share/emulator/dolphin/Load"

clear

say() { echo "$1"; sleep "${2:-1.4}"; }

echo "==============================================="
say "  Dolphin Rt:Core — RUNGIF" 0.8
say "  Chapter Three: The Scanner" 2.5
echo "==============================================="
echo ""
sleep 1

# ── Count valid subfolders (non-empty, non-hidden) ────────
TOTAL=0
for sub in "$LOAD_DIR"/*/; do
    [ -d "$sub" ] || continue
    sub_name=$(basename "$sub")
    case "$sub_name" in .*) continue ;; esac

    ENTRY_COUNT=0
    for entry in "$sub"*/; do
        [ -d "$entry" ] || continue
        entry_name=$(basename "$entry")
        case "$entry_name" in .*) continue ;; esac
        ENTRY_COUNT=$((ENTRY_COUNT+1))
    done

    [ "$ENTRY_COUNT" -gt 0 ] && TOTAL=$((TOTAL+1))
done

if [ "$TOTAL" = "0" ]; then
    say "I looked. I really did." 2
    say "But the Load/ folder..." 2
    say "...has nothing for me." 2.5
    echo ""
    say "Install some mods first." 2.5
    say "Then come back." 2
    echo ""
    say "Even RUNGIF cannot toggle nothing." 2.5
    echo ""
    echo "==============================================="
    say "  Nothing to scan." 2
    echo "==============================================="
    echo ""
    echo "  Closing in ${GENERAL_SLEEP} seconds..."
    sleep "$GENERAL_SLEEP"
    FRONTEND start task
    exit 0
fi

say "Ah. Good." 1.8
say "$TOTAL folder(s) with content." 2
say "Let me build the menu." 2.5
echo ""

if [ ! -f "$SCANNER" ]; then
    say "  [ERR] Scanner not found at:" 1.5
    say "        $SCANNER" 2
    echo ""
    say "Even RUNGIF has limits." 2.5
    sleep 4
    FRONTEND start task
    exit 1
fi

sh "$SCANNER"

echo ""
echo "==============================================="
say "  ...and so the folder speaks again." 2.5
echo "==============================================="
echo ""
say "Go now, boy." 2
say "The toggles are yours." 2
echo ""
say "Empty folders — I removed them." 2.5
say "Dead weight has no place here." 2.5
echo ""
say "Until then... stay Rintromping." 3.5
echo ""
echo "  Closing in ${GENERAL_SLEEP} seconds..."
sleep "$GENERAL_SLEEP"

FRONTEND start task
exit 0
