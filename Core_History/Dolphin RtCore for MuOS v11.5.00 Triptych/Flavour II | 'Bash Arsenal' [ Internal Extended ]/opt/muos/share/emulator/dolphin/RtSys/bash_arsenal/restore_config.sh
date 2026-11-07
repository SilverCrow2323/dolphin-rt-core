#!/bin/bash
EMU="/opt/muos/share/emulator/dolphin"
BACKUPS="$EMU/RtSys/backups"
[ ! -d "$BACKUPS" ] && { echo "  [ERR] No backups folder."; exit 1; }
SELECTED=$(ls -1t "$BACKUPS"/*.zip 2>/dev/null | head -1)
[ -z "$SELECTED" ] && { echo "  [ERR] No backup found in $BACKUPS"; exit 1; }
echo "  Restoring: $(basename "$SELECTED")"
echo ""
cd "$EMU" || exit 1
unzip -oq "$SELECTED" -d "$EMU"
echo "  [OK] Restored successfully."
echo ""
echo "  Source : $(basename "$SELECTED")"
echo "  Target : $EMU"
