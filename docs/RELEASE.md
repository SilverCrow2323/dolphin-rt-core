# Release checklist — Rt:Core 12.1.0 Arcade

## Current release candidate

- **Rt:Core:** 12.1.0
- **Rt:UI:** 3.7.0 “Arcade”
- **Source:** [PR #81](https://github.com/SilverCrow2323/dolphin-rt-core/pull/81)
- **Release state:** draft candidate only; the final release is not published.
- **Hardware gate:** RG35XX H install, boot animation, controller input, game launch, frame pacing and Safe Exit must be checked on the exact target firmware before publication.

## Package types

| Package | Purpose | Install expectation |
|---|---|---|
| CI UI-only artefact | Validates Rt:UI / RtSys packaging and archive structure | Not a standalone emulator update; built only with explicit DOLPHIN_UI_ONLY=1 |
| Andromeda full update | Native AArch64 Dolphin, matching Sys tree, required private runtime libraries, Rt:UI / RtSys and manifest.sha256 | This is the installable release candidate |

The dedicated `.github/workflows/build-muos-andromeda.yml` workflow builds the full Andromeda update from a matching AArch64 Dolphin executable, Sys resource tree and private libraries. It refuses to publish a full update when the Dolphin binary is missing or not AArch64, and checks any bundled HIDAPI runtime against the same architecture.

After a successful push build on main, the workflow creates a **draft** release candidate tagged `v12.1.0-rc-<commit>`. It remains a draft until physical-device testing is recorded.

## Official resources and Mod Vault

The full update retains the official Dolphin content that users can manage:

- `GameSettings/` per-game INI profiles.
- `Sys/Load/` official load resources and graphics mods.
- `Load/Textures/` stock and official texture packs.
- `Load/GraphicMods/` installed graphics mods.
- `workshop/gamesettings/` Rt:UI per-game presets.

Rt:UI Mod Vault manages activation/deactivation without deleting the source payload from the package. The update excludes only developer-local `data/settings.json`, generated app-local GameSettings cache and timestamped backup/temp files.

When a fresh `DOLPHIN_SYS_DIR` is supplied, its files are merged over the curated Sys payload. The packager does not wipe the official Sys/Load resources that may not be present in a minimal build output.

## Before publication

- [ ] Confirm the target model and firmware version.
- [ ] Verify the full Andromeda package contains the native Dolphin executable.
- [ ] Verify ELF64/AArch64 and GLIBC compatibility.
- [ ] Verify private HIDAPI libraries when the executable needs them.
- [ ] Check `manifest.sha256` and archive integrity.
- [ ] Confirm official GameSettings, Sys/Load, textures and graphic mods are present.
- [ ] Install and boot on RG35XX H with the exact supported firmware.
- [ ] Test Content Explorer launch, controls, audio, gameplay, Mod Vault toggles and Safe Exit.
- [ ] Keep the GitHub release in draft until the hardware report passes.

## Release notes

State clearly:

- Supported platform and firmware.
- Whether the asset is a UI-only CI archive or a full engine update.
- Required external dependencies, if any.
- Known limitations and unverified hardware combinations.
- Tests performed and tests not performed.

Never describe a dry-run, emulator or Xvfb result as a physical-device test.
