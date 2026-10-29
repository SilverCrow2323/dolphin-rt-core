#!/bin/bash
# ============================================================
#  Dolphin Rt:Core — Uninstall Script
#  SPDW Factory Lab / sirpips aka SilverCrow2323
# ============================================================
#  Removes all Dolphin Rt:Core related directories and files.
#  Generates a visual report with success/failure status.
#
#  Usage: uninstall_dolphinrt.sh
# ============================================================

REPORT=""
SUCCESS=0
FAILED=0
WARN=0

# ── Helper: log a line to report ───────────────────────────
log_line() {
    REPORT="${REPORT}$1\n"
}

# ── Helper: remove directory with check ────────────────────
remove_dir() {
    local dir="$1"
    local label="$2"
    if [ -d "$dir" ]; then
        if rm -rf "$dir" 2>/dev/null; then
            log_line "[✓] Removed directory: $label"
            SUCCESS=$((SUCCESS + 1))
        else
            log_line "[✗] Failed to remove: $label"
            FAILED=$((FAILED + 1))
        fi
    else
        log_line "[!] Not found (skipped): $label"
        WARN=$((WARN + 1))
    fi
}

# ── Helper: remove file with check ─────────────────────────
remove_file() {
    local file="$1"
    local label="$2"
    if [ -f "$file" ]; then
        if rm -f "$file" 2>/dev/null; then
            log_line "[✓] Removed file: $label"
            SUCCESS=$((SUCCESS + 1))
        else
            log_line "[✗] Failed to remove: $label"
            FAILED=$((FAILED + 1))
        fi
    else
        log_line "[!] Not found (skipped): $label"
        WARN=$((WARN + 1))
    fi
}

# ── Helper: remove pattern directories ─────────────────────
remove_pattern() {
    local base="$1"
    local pattern="$2"
    local label="$3"
    local found=0
    for dir in "$base"/$pattern; do
        [ -d "$dir" ] || continue
        found=1
        remove_dir "$dir" "$(basename "$dir")"
    done
    [ "$found" = "0" ] && log_line "[!] No match for pattern: $pattern" && WARN=$((WARN + 1))
}

# ═══════════════════════════════════════════════════════════
#  MAIN REMOVAL TASKS
# ═══════════════════════════════════════════════════════════

log_line "════════════════════════════════════════════════════════"
log_line "  Dolphin Rt:Core — Uninstall Report"
log_line "════════════════════════════════════════════════════════"
log_line ""

# ── Directories ────────────────────────────────────────────
remove_dir "/opt/muos/share/emulator/dolphin" "Dolphin emulator root"
remove_dir "/opt/muos/share/info/assign/Nintendo Gamecube" "GameCube assign"
remove_dir "/opt/muos/share/info/assign/Nintendo Wii" "Wii assign"

# ── Task folders (pattern: "Dolphin Rt*Core") ──────────────
remove_pattern "/opt/muos/share/task" "Dolphin Rt*" "Task folders"

# ── Launch scripts ─────────────────────────────────────────
remove_file "/opt/muos/script/launch/ext-dolphin.sh" "ext-dolphin.sh"
remove_file "/opt/muos/script/launch/ext-dolphinrt.sh" "ext-dolphinrt.sh"

# ── gptokeyb ───────────────────────────────────────────────
remove_file "/opt/muos/share/emulator/gptokeyb/ext-dolphin-gptk" "gptokeyb profile"

# ── Final status ───────────────────────────────────────────
log_line ""
log_line "────────────────────────────────────────────────────────"
if [ "$FAILED" -eq 0 ]; then
    log_line "  Result: SUCCESS ($SUCCESS items removed, $WARN skipped)"
    EXIT_CODE=0
else
    log_line "  Result: FAILED ($SUCCESS removed, $FAILED errors, $WARN skipped)"
    EXIT_CODE=1
fi
log_line "════════════════════════════════════════════════════════"

# ── Print report ───────────────────────────────────────────
echo -e "$REPORT"

# ── Save report to log ─────────────────────────────────────
LOGDIR="/opt/muos/share/emulator/dolphin/RtSys/logs"
mkdir -p "$LOGDIR" 2>/dev/null
echo -e "$REPORT" > "$LOGDIR/uninstall_report.log" 2>/dev/null

exit $EXIT_CODE
