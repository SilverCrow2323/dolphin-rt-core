# Quick Start

This guide is intentionally conservative. Use the package named for your exact firmware and platform; a compatible registration script does not make every package compatible with every muOS generation.

## Before installing

1. Read the platform support table in the root README.
2. Back up the SD card, user saves and Dolphin configuration.
3. Confirm the package version and muOS firmware version.
4. Confirm that a compatible aarch64 Dolphin binary is available. The project does not include or claim permission to redistribute it.
5. Read [[muOS-Registration]] if you are moving between Andromeda and Jacaranda.

## Install the current Andromeda package

1. Download the release linked by the root README.
2. Copy the `.muxupd` file into the SD card's `ARCHIVE` folder.
3. Install it through muOS Archive Manager.
4. Place the Dolphin executable at `/opt/muos/share/emulator/dolphin/dolphin`.
5. Launch Dolphin Rt:Core. The package and launcher check the detected muOS registration API and repair missing GameCube/Wii entries.
6. In Content Explorer, select a GameCube or Wii ROM folder, choose **Core Assignment**, then choose a profile.

## First launch checks

- Open Diagnostics and resolve missing dependencies.
- Check that **Nintendo > GameCube** and **Nintendo > Wii** are available in Content Explorer.
- Open the Compatibility Database and compare Game ID, region, handheld and muOS version.
- Start with the Default profile unless a reproducible report recommends otherwise.
- Change one setting at a time and record the result.

## Rollback

Keep the SD card backup. Use the uninstall/restore steps for the exact release line. Do not delete Dolphin configuration or save data as a generic troubleshooting step.
