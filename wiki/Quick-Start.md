# Quick Start

This page is a route into the current muOS package. Read the platform release notes before installing: package names, firmware requirements and external emulator dependencies can change.

## Before installing

1. Confirm that the device is running a muOS release supported by the package. The current Andromeda instructions live in [the frontend's ANDROMEDA guide](https://github.com/SilverCrow2323/dolphin-rt-core/blob/main/dolphin-rtcore-muos/app/Dolphin%20RtUI/docs/ANDROMEDA.md).
2. Back up the SD card and the existing Dolphin configuration.
3. Confirm that you have a compatible aarch64 Dolphin binary. The project does not assume permission to redistribute that binary; follow the repository's license and source-notice requirements.
4. Download the package from the release linked by the root README. Do not install an experimental Knulli/ROCKNIX package on muOS.

## Install

For the currently documented muOS Andromeda flow:

1. Copy the `.muxupd` package into the SD card's `ARCHIVE` folder.
2. Install it through muOS Archive Manager.
3. Place the compatible Dolphin binary at the path specified by the platform guide.
4. Reboot or launch the frontend as instructed by the release notes.
5. Confirm that GameCube and Wii are registered in the frontend / content explorer.

## First checks

- Open Diagnostics and resolve missing dependencies before launching a game.
- Open the Compatibility screen and compare your Game ID, region, device and firmware against the community database.
- Keep the Default profile for the first test unless the game report specifically recommends another profile.
- Make one change at a time and record the result.

## Rollback

Keep a backup of the original SD card and Dolphin configuration. Use the release-specific uninstall/restore instructions. Do not delete the emulator configuration or user saves as a troubleshooting shortcut.
