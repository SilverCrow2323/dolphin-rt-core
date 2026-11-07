#!/bin/sh
. "$(dirname "$0")/paths.sh"
{ df -h "$DATA" 2>&1 | tail -n 2; echo; echo "covers: $(du -sh "$DATA/covers" 2>/dev/null | cut -f1) in $(ls "$DATA/covers" 2>/dev/null | wc -l) files"; } | atomic_write "$DATA/diskspace.txt"
