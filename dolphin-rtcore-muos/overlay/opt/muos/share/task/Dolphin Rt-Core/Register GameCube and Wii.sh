#!/bin/sh
# HELP: Adds the GameCube and Wii systems and every Dolphin Rt:Core profile to the muOS core list. Run this once after installing or updating muOS.
# ICON: junk
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/ui.sh

TASK_BEGIN "register_rtcore" "Register Rt:Core"

TOOL="/opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh"
[ -x "$TOOL" ] || TASK_ERROR "no_tool" "Dolphin Rt:Core is not installed (manifest_tool.sh missing)"

TASK_STATUS "Register Rt:Core"
sh "$TOOL" apply || TASK_ERROR "apply_failed" "Could not update the core manifest - see MUOS/log"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "GameCube/Wii registered"
sleep 4

exit 0
