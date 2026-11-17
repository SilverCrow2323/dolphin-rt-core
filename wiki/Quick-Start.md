# Quick Start

This page covers the safe first install and first launch of the current **muOS Andromeda** Rt:Core package.

## In breve

- Match the package to the exact firmware line.
- Back up saves and Dolphin configuration before replacing files.
- Install the release package with muOS Archive Manager.
- Confirm the core registration and choose a profile before launching a game.

> [!IMPORTANT]
> **MUST KNOW!!** The v12.0.0 Kanzentai package is the Andromeda line. Jacaranda has a separate legacy v11.5.1 release. A registration detector does not make one package interchangeable with another firmware.

## Before installing

1. Read the platform matrix in the [root README](https://github.com/SilverCrow2323/dolphin-rt-core#02--platform-matrix).
2. Back up the SD card, user saves and Dolphin configuration.
3. Confirm the package version and installed muOS firmware.
4. Confirm that the matching AArch64 Dolphin binary is available. The repository does not claim permission to redistribute the emulator binary.

## Install on muOS Andromeda

1. Download the matching `.muxupd` from [Releases](https://github.com/SilverCrow2323/dolphin-rt-core/releases).
2. Copy it into the SD card's `ARCHIVE/` folder.
3. Install it through **muOS → Applications → Archive Manager**.
4. Place the AArch64 executable at `/opt/muos/share/emulator/dolphin/dolphin`.
5. Launch **Dolphin Rt:Core** from Applications.
6. In Content Explorer, select a GameCube or Wii ROM folder.
7. Open **Core Assignment** and choose a profile.

## First-launch checks

- Open Diagnostics and resolve missing dependencies. Press **M** to open Rt:System Status Center and review Wi-Fi, Portal/Sunshine, database and library status.
- Confirm Nintendo → GameCube and Nintendo → Wii appear in Content Explorer.
- Keep Dolphin's official Sys/GameSettings and Sys/Load/GraphicMods resources intact.
- Use **Mod Vault → Graphics Mods** to enable official or user graphics mods separately for each game; All Games means compatible, not automatically enabled.
- Start with the Default profile.
- Compare the exact Game ID, region, firmware and device in the Compatibility Database.
- Change one setting at a time and record the result.

> **Optional** — Read [[Controls-and-Profiles]] before changing controller mappings or game-specific settings.

## Rollback

Keep the SD card backup. Follow the uninstall/restore instructions for the exact release line. Do not delete saves or the full Dolphin configuration as a generic troubleshooting step.
