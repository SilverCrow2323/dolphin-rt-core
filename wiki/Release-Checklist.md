# Release Checklist

## Before packaging

- [ ] Confirm target platform, firmware and version.
- [ ] Update the platform changelog and version source.
- [ ] Run syntax, unit, smoke, dry-run and package checks relevant to the target.
- [ ] Inspect package contents; exclude backups, logs, local settings and development artifacts.
- [ ] Verify checksums after the final package is built.
- [ ] Capture affected UI screens and label desktop vs. hardware evidence.
- [ ] Verify install, upgrade and rollback on a disposable target where possible.
- [ ] Confirm no ROMs, BIOS, firmware, private data or credentials entered the release.

## Release notes

State clearly:

- Supported platform and firmware.
- Package filename and version.
- External emulator binary / dependencies and source obligations.
- Known limitations and unverified device combinations.
- Tests performed and tests not performed.

Never describe a dry-run, emulator, syntax check or screenshot as a physical-device test.
