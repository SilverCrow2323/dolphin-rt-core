# Release checklist — Rt:Core 12.1.0 Arcade

## Current release candidate

- **Rt:Core:** 12.1.0
- **Rt:UI:** 3.7.0 “Arcade”
- **Source:** [PR #81](https://github.com/SilverCrow2323/dolphin-rt-core/pull/81)
- **Release state:** candidate only; no GitHub Release or tag has been published.
- **Hardware gate:** RG35XX H install, boot animation, controller input, game launch, frame pacing and Safe Exit must be checked on the exact target firmware before publication.

The current CI workflow invokes the packager without DOLPHIN_BIN. Its .muxupd is therefore an **Rt:UI / RtSys overlay**, not a standalone Dolphin engine bundle. A compatible Dolphin executable must already be installed.

## Package modes

`dolphin-rtcore-muos/tools/build-muxupd.sh` supports two modes:

- **Overlay update:** omit `DOLPHIN_BIN`. It packages Rt:UI, RtSys, muOS integration and Dolphin system resources. It does not install the emulator executable.
- **Full engine bundle:** provide `DOLPHIN_BIN`, `DOLPHIN_SYS_DIR` and `DOLPHIN_LIB_DIR` from the same AArch64 Dolphin build. The output filename receives the `_with-dolphin` suffix.

The Arcade 12.1.0 candidate CI artifact is overlay-only. It expects a compatible existing executable at `/opt/muos/share/emulator/dolphin/dolphin`.

## Before packaging

- [ ] Confirm the target platform and firmware version.
- [ ] Update the platform changelog and version source(s).
- [ ] Run the relevant unit, syntax, smoke and packaging checks.
- [ ] Inspect generated package contents; exclude backups, logs, local settings and development-only artifacts.
- [ ] Check for timestamped backups (`*.bak.*`), editor swap files and temporary files; verify they are absent from the `.muxupd` archive.
- [ ] Label the artifact as an Rt:UI/RtSys overlay or a full engine bundle. An overlay-only package must state the required preinstalled Dolphin executable.
- [ ] Verify checksums after the final package is built.
- [ ] Capture screenshots for UI changes and label desktop versus hardware evidence.
- [ ] Verify install, upgrade and uninstall paths on a disposable test image/device where possible.

## Release notes

State clearly:

- Supported platform and firmware.
- Package filename and version.
- Required external emulator binary or dependencies.
- Known limitations and unverified hardware combinations.
- Tests performed and tests not performed.

Never describe a dry-run, emulator or Xvfb result as a physical-device test.
