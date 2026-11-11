#!/bin/sh
# HELP: Checks SD1/SD2 ROMS paths, GameCube/Wii folder casing, legacy core assignments and controller devices. Saves a report without listing game filenames.
# ICON: junk
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/ui.sh
TASK_BEGIN "rtcore_rom_visibility" "Dolphin Rt-Core ROM Check"

LOG_ROOT=""
for base in /mnt/mmc /mnt/sdcard; do
    if [ -d "$base/MUOS" ]; then LOG_ROOT="$base/MUOS/log"; break; fi
done
if [ -z "$LOG_ROOT" ]; then
    [ -d /mnt/sdcard ] && LOG_ROOT=/mnt/sdcard || LOG_ROOT=/tmp
fi
mkdir -p "$LOG_ROOT" 2>/dev/null
STAMP="$(date +%Y%m%d_%H%M%S)"
REPORT="$LOG_ROOT/dolphin-rtcore-rom-check-$STAMP.txt"

TASK_STATUS "Inspect storage and ROM folders"
{
    echo "Dolphin Rt:Core — ROM visibility diagnostic"
    echo "Date: $(date)"
    echo "Architecture: $(uname -m 2>/dev/null)"
    echo
    echo "[MUOS version]"
    for f in /opt/muos/config/system/version /opt/muos/device/config/system/version /opt/muos/share/version; do
        if [ -r "$f" ]; then echo "$f: $(head -n 1 "$f")"; fi
    done
    echo
    echo "[Storage mounts]"
    awk '$2=="/mnt/mmc" || $2=="/mnt/sdcard" || $2=="/mnt/usb" || $2=="/mnt/roms" {print $2, $3}' /proc/mounts 2>/dev/null
    echo
    inspect_tree() {
        tree="$1"
        [ -d "$tree" ] || return 0
        echo "TREE: $tree"
        echo "  top-level directories:"
        find "$tree" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r dir; do echo "    $(basename "$dir")"; done
        for system in "Nintendo GameCube" "Nintendo Gamecube" "GameCube" "GC" "Nintendo Wii" "Wii"; do
            dir="$tree/$system"
            [ -d "$dir" ] || continue
            count="$(find "$dir" -maxdepth 6 -type f \( -iname "*.iso" -o -iname "*.gcm" -o -iname "*.rvz" -o -iname "*.gcz" -o -iname "*.wbfs" -o -iname "*.wia" -o -iname "*.ciso" \) 2>/dev/null | wc -l | tr -d " ")"
            echo "  SYSTEM_FOLDER: $dir"
            echo "    game image count: ${count:-0}"
        done
    }
    for root in /mnt/mmc /mnt/sdcard /mnt; do
        for name in ROMS roms; do
            tree="$root/$name"
            if [ -d "$tree" ]; then inspect_tree "$tree"; else echo "MISSING: $tree"; fi
        done
    done
    echo
    echo "[Legacy info/assign]"
    for system in "Nintendo GameCube" "Nintendo Gamecube" "Nintendo Wii"; do
        dir="/opt/muos/share/info/assign/$system"
        if [ -d "$dir" ]; then
            count="$(find "$dir" -maxdepth 1 -type f -name "*.ini" 2>/dev/null | wc -l | tr -d " ")"
            echo "PRESENT: $dir (INI files: ${count:-0})"
            if [ -r "$dir/global.ini" ]; then
                grep -E "^(name|default|catalogue)=" "$dir/global.ini" 2>/dev/null
            else
                echo "  global.ini: MISSING"
            fi
        else
            echo "MISSING: $dir"
        fi
    done
    echo
    echo "[Modern manifest]"
    for f in /opt/muos/share/info/manifest/core.json /opt/muos/share/info/manifest/Nintendo/core.json /opt/muos/share/info/manifest/Nintendo Gamecube/core.json /opt/muos/share/info/manifest/Nintendo Wii/core.json; do
        [ -s "$f" ] && echo "PRESENT: $f"
    done
    echo
    echo "[Dolphin hotkey components]"
    [ -x /opt/muos/script/launch/ext-dolphinrt.sh ] && echo "PRESENT: /opt/muos/script/launch/ext-dolphinrt.sh" || echo "MISSING: external launcher"
    [ -x "/run/muos/storage/application/Dolphin RtUI/lib/gptokeyb2" ] && echo "PRESENT: gptokeyb2" || echo "MISSING: gptokeyb2"
    [ -f "/run/muos/storage/application/Dolphin RtUI/workshop/hotkeys/Default/ext-dolphin.gptk" ] && echo "PRESENT: Default ext-dolphin.gptk" || echo "MISSING: Default ext-dolphin.gptk"
    echo
    echo "[Input devices]"
    for f in /dev/input/js*; do [ -e "$f" ] && echo "PRESENT: $f"; done
    for f in /dev/input/event*; do [ -e "$f" ] && echo "PRESENT: $f"; done
    echo
    echo "No game filenames or ROM contents are included in this report."
} > "$REPORT" 2>&1

[ -s "$REPORT" ] || TASK_ERROR "report_failed" "Could not create ROM visibility report"
TASK_COMPLETE "Report saved: $REPORT"
sleep 4
exit 0
