<div align="center">

# 📦 muOS · Release Package Guide

**Know exactly what you are installing before copying it to ARCHIVE.**

</div>

## Two package types

The muOS packager supports two different outputs. They are both `.muxupd`, but they do not contain the same payload.

| Package | What it includes | What must already exist |
|---|---|---|
| **Rt:UI / RtSys overlay** | Frontend, firmware launchers, registration tools, controller/UI settings, Dolphin `Sys/` resources and integrity manifest. | A compatible Dolphin executable at `/opt/muos/share/emulator/dolphin/dolphin`. |
| **Full engine bundle** | Everything in the overlay plus the AArch64 Dolphin executable and private runtime libraries from one matching build. | No separately installed Dolphin executable is required; still back up existing saves and configuration. |

### Current Arcade 12.5.00 candidate package

**Full engine bundle · draft candidate**

The next release candidate is **Dolphin Rt:Core 12.5.00** with **Rt:UI 3.7.0 “Arcade”**. The Andromeda release workflow builds a complete AArch64 update containing Dolphin, matching system resources and required private runtime libraries. It preserves official GameSettings, Sys/Load assets, stock textures and graphics mods; Rt:UI Mod Vault controls their activation.

The separate CI UI-only archive is explicitly labelled and must not be installed as a full engine update. The candidate is tracked in [PR #81](https://github.com/SilverCrow2323/dolphin-rt-core/pull/81); it is not yet a published GitHub Release. Physical RG35XX H testing on the target firmware remains required before publication.

## Build a full engine bundle

Build Dolphin for the intended firmware first. Keep the executable, `Sys/` tree and private libraries from the **same build output**.

```bash
bash dolphin-build/build-dolphin.sh \
  --target muos --frontend nogui \
  --out ./out/muos

DOLPHIN_BIN="$PWD/out/muos/dolphin" \
DOLPHIN_SYS_DIR="$PWD/out/muos/Sys" \
DOLPHIN_LIB_DIR="$PWD/out/muos/lib" \
  bash dolphin-rtcore-muos/tools/build-muxupd.sh ./dist
```

The resulting filename receives the `_with-dolphin.muxupd` suffix. The packager validates the AArch64 ELF header, required GameCube fonts, DSP resources and OSD font, and includes `manifest.sha256`.

## Install the Andromeda overlay

1. Verify that the existing Dolphin executable is present and is an AArch64 build compatible with the bundled system resources.
2. Back up the SD card, saves, Dolphin configuration and existing installation.
3. Copy the overlay `.muxupd` to the SD card's `ARCHIVE` folder.
4. Install it with muOS Archive Manager.
5. Launch Dolphin Rt:Core from Applications and verify Content Explorer, controller input and Safe Exit.
6. Inspect the launcher and RtUI logs if startup fails.

**Do not use an Andromeda update package as a Jacaranda release.** Jacaranda keeps the initial EV_KEY mapping and requires a Jacaranda-matched install/registration path. See [[muOS-Firmware-Profiles]].

## Package hygiene

The packager excludes timestamped backups (`*.bak.*`), editor swap files and temporary files. It refuses incomplete `Sys/` trees and creates an SHA-256 manifest for the files it includes.

CI packaging checks include a synthetic timestamped backup fixture so this class of residue cannot silently return.

<details>
<summary><strong>What the CI result proves (and what it does not)</strong></summary>

CI confirms:
- Shell/Lua syntax and regression tests.
- Package assembly and required resource checks.
- Manifest checksum integrity.
- LÖVE screen loading and automated screenshots.

CI does **not** certify a physical boot, controller input, performance or clean exit on a real RG35XX H. Those checks must be completed on the exact firmware and device. The Arcade candidate is not hardware-certified yet; the RG35XX H boot, input, performance and clean-exit gate remains open.

</details>

**Technical references:** [Release checklist](https://github.com/SilverCrow2323/dolphin-rt-core/blob/main/docs/RELEASE.md) · [muOS registration](https://github.com/SilverCrow2323/dolphin-rt-core/blob/main/docs/MUOS_REGISTRATION.md) · [Controller input reference](https://github.com/SilverCrow2323/dolphin-rt-core/blob/main/docs/CONTROLLER_INPUT.md)
