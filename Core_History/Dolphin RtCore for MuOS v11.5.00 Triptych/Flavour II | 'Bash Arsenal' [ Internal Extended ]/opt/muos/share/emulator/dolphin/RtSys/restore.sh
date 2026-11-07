#!/bin/bash
# restore.sh — restore from a ZIP backup
EMU="/opt/muos/share/emulator/dolphin"
BACKUPS="$EMU/RtSys/backups"
clear
echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   RESTORE CONFIG                                 ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
if [ ! -d "$BACKUPS" ] || [ -z "$(ls -1 $BACKUPS/*.zip 2>/dev/null)" ]; then
    echo "  ✗ No backups found in $BACKUPS"
    sleep 4
    exit 1
fi
echo "  Available backups:"
i=1
for f in "$BACKUPS"/*.zip; do
    SIZE=$(du -h "$f" | cut -f1)
    echo "    $i) $(basename "$f") ($SIZE)"
    i=$((i+1))
done
echo ""
read -p "  Choose backup number: " n
SELECTED=$(ls -1 "$BACKUPS"/*.zip | sed -n "${n}p")
if [ ! -f "$SELECTED" ]; then
    echo "  Invalid choice."
    sleep 3
    exit 1
fi
echo ""
echo "  Selected: $(basename "$SELECTED")"
read -p "  Confirm restore? [y/N]: " c
case "$c" in y|Y|yes|YES) ;; *) echo "  Cancelled."; sleep 2; exit 0 ;; esac
cd "$EMU" || exit 1
unzip -oq "$SELECTED" -d "$EMU"
echo ""
echo "  ✓ Restored from $(basename "$SELECTED")"
echo ""
echo "  Closing in 5 seconds..."
sleep 5
