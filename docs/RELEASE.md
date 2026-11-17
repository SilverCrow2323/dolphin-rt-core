# Release checklist

## Before packaging

- [ ] Confirm the target platform and firmware version.
- [ ] Update the platform changelog and version source(s).
- [ ] Run the relevant unit, syntax, smoke and packaging checks.
- [ ] Inspect generated package contents; exclude backups, logs, local settings and development-only artifacts.
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
