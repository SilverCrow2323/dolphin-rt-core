#!/bin/bash
# backup.sh — create ZIP backup of Config/GameSettings/Load
EMU="/opt/muos/share/emulator/dolphin"
BACKUPS="$EMU/RtSys/backups"
mkdir -p "$BACKUPS"
TS=$(date +%Y%m%d_%H%M%S)
OUT="$BACKUPS/dolphinrt_backup_$TS.zip"
cd "$EMU" || exit 1
zip -qr "$OUT" Config GameSettings Load 2>/dev/null
clear
echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   BACKUP CONFIG                                  ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
if [ -f "$OUT" ]; then
    SIZE=$(du -h "$OUT" | cut -f1)
    echo "  ✓ Backup created"
    echo "    File: $(basename "$OUT")"
    echo "    Size: $SIZE"
    echo "    Path: $OUT"
else
    echo "  ✗ Backup FAILED"
fi
echo ""
echo "  Closing in 5 seconds..."
sleep 5
