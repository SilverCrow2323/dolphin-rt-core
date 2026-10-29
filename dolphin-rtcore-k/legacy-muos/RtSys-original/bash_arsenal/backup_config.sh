#!/bin/bash
EMU="/opt/muos/share/emulator/dolphin"
BACKUPS="$EMU/RtSys/backups"
TS=$(date +%Y%m%d_%H%M%S)
OUT="$BACKUPS/dolphinrt_backup_$TS.zip"
mkdir -p "$BACKUPS"
cd "$EMU" || exit 1
zip -qr "$OUT" Config GameSettings Load 2>/dev/null
if [ -f "$OUT" ]; then
    SIZE=$(du -h "$OUT" | cut -f1)
    echo "  [OK] Backup created."
    echo ""
    echo "  File : $(basename "$OUT")"
    echo "  Size : $SIZE"
    echo "  Path : $OUT"
else
    echo "  [ERR] Backup failed."; exit 1
fi
