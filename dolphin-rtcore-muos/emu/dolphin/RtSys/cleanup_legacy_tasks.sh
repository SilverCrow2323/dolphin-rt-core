#!/bin/sh
# Remove only legacy Dolphin Rt:Core Task Toolkit directories.
# Production always uses the fixed muOS task root. The explicit test mode
# accepts only a temporary directory so CI cannot target arbitrary paths.
set -eu
case "${1:-}" in
    "")
        TASK_ROOT="/opt/muos/share/task"
        ;;
    --test-root)
        [ "$#" -eq 2 ] || { echo "usage: $0 [--test-root /tmp/dir]" >&2; exit 2; }
        TASK_ROOT="$2"
        case "$TASK_ROOT" in
            /tmp/*|/private/tmp/*) ;;
            *) echo "test root must be under /tmp" >&2; exit 2 ;;
        esac
        ;;
    *)
        echo "usage: $0 [--test-root /tmp/dir]" >&2
        exit 2
        ;;
esac
[ -d "$TASK_ROOT" ] || exit 0
for TASK_DIR in "$TASK_ROOT"/Dolphin\ Rt*Core; do
    [ -d "$TASK_DIR" ] || continue
    rm -rf "$TASK_DIR"
done
