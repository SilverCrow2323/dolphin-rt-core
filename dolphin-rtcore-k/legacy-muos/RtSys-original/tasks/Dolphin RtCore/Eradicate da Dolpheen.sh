#!/bin/bash
# HELP: Uninstall Dolphin | Removes Dolphin, assignments, task folder, launcher and gptk. | Resources: None | Downside: You lose everything. | MINORU's Quick Lesson #001: If you run this, Dolphin disappears. Forever.
# ICON: diagnostic
# ============================================================
#  SPDW Factory Lab / sirpips aka SilverCrow2323
# ============================================================
#  Task Toolkit script to uninstall Dolphin Rt:Core.
#  Runs the uninstall script, shows the report, and exits
#  after 5 seconds.
# ============================================================

UNINSTALL_SCRIPT="/opt/muos/share/emulator/dolphin/RtSys/uninstall_dolphinrt.sh"

clear

# ── Header ─────────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║        DOLPHIN Rt:CORE — ERADICATE              ║"
echo "  ║        SPDW Factory Lab                         ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""

# ── Run uninstall ──────────────────────────────────────────
if [ -x "$UNINSTALL_SCRIPT" ]; then
    echo "  Running uninstall script..."
    echo ""
    bash "$UNINSTALL_SCRIPT"
    EXIT_CODE=$?
else
    echo "  [✗] Uninstall script not found:"
    echo "      $UNINSTALL_SCRIPT"
    EXIT_CODE=1
fi

# ── Wait 5 seconds ─────────────────────────────────────────
echo ""
echo "  Closing in 5 seconds..."
sleep 5

exit $EXIT_CODE
