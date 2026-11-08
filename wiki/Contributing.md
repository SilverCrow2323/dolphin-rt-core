# Contributing

Thanks for helping improve Dolphin Rt:Core. Contributions should be reproducible, scoped and safe for users' SD cards and data.

## Before opening a PR

1. Read the target component's README, changelog and build scripts.
2. Confirm which platform and release line the change belongs to.
3. Check whether a similar fix already exists in the current source or historical archive.
4. Keep unrelated platform, frontend, portal and data changes separate when practical.

## Code changes

- Preserve platform boundaries; do not copy muOS paths into Knulli/ROCKNIX launchers.
- Prefer shared helpers only when their behavior is truly common across platforms.
- Quote shell arguments and validate paths at trust boundaries.
- Use disposable test roots for installers, launchers and migration tests.
- Never include ROMs, BIOS, firmware, game dumps, credentials, pairing tokens or personal logs.
- Keep third-party licenses and asset attribution with the assets.

## Documentation and UI

- Update the relevant guide when commands, paths or user-facing behavior change.
- Capture affected screens and label desktop vs. real-device evidence.
- Check controller focus, small-screen layout, contrast and reduced-motion behavior.
- Do not claim hardware validation based only on CI, Xvfb or emulator output.

## Pull request checklist

- [ ] Scope and target platform are clear.
- [ ] Relevant syntax checks, tests and package verification pass.
- [ ] Generated files and local runtime data are excluded.
- [ ] User data is not deleted or migrated destructively.
- [ ] Documentation and changelog are updated where necessary.
- [ ] Unverified hardware cases are disclosed.
