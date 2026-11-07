#!/bin/sh
# HELP: Shows only the standard Rt:Core profiles (mode 1) when you choose a core for GameCube/Wii content.
# ICON: junk
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/ui.sh

TASK_BEGIN "rtcore_mode_1" "Rt:Core Mode 1"

TOOL="/opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh"
[ -x "$TOOL" ] || TASK_ERROR "no_tool" "Dolphin Rt:Core is not installed (manifest_tool.sh missing)"

TASK_STATUS "Rt:Core Mode 1"
sh "$TOOL" apply 1 || TASK_ERROR "apply_failed" "Could not update the core manifest - see MUOS/log"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Mode 1 active"
sleep 4

exit 0
