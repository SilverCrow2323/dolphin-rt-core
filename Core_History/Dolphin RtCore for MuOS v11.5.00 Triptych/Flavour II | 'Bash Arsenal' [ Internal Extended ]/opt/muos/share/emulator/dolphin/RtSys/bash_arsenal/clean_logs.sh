#!/bin/bash
LOGDIR="/opt/muos/share/emulator/dolphin/RtSys/logs"
[ ! -d "$LOGDIR" ] && { echo "  [INFO] No logs folder found."; exit 0; }
BEFORE=$(du -sh "$LOGDIR" 2>/dev/null | cut -f1)
COUNT=$(find "$LOGDIR" -type f -name "*.log*" 2>/dev/null | wc -l)
rm -f "$LOGDIR"/*.log "$LOGDIR"/*.log.old 2>/dev/null
AFTER=$(du -sh "$LOGDIR" 2>/dev/null | cut -f1)
echo "  [OK] Logs cleaned."
echo ""
echo "  Files removed : $COUNT"
echo "  Size before   : $BEFORE"
echo "  Size after    : $AFTER"
