#!/bin/sh
# HELP: Shows every Rt:Core profile with its lite, standard and max tier (mode 2) when you choose a core for GameCube/Wii content.
# ICON: junk
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/ui.sh

TASK_BEGIN "rtcore_mode_2" "Rt:Core Mode 2"

TOOL="/opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh"
[ -x "$TOOL" ] || TASK_ERROR "no_tool" "Dolphin Rt:Core is not installed (manifest_tool.sh missing)"

TASK_STATUS "Rt:Core Mode 2"
sh "$TOOL" apply 2 || TASK_ERROR "apply_failed" "Could not update the core manifest - see MUOS/log"

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Mode 2 active"
sleep 4

exit 0
