# Troubleshooting

Start with the least destructive check. Keep the exact firmware, package and device details with every diagnostic report.

> [!IMPORTANT]
> **MUST KNOW!!** Do not delete Dolphin configuration, save data or emulator directories as a first troubleshooting step. Back up user data before reinstalling or restoring profiles.

## In breve

- Confirm the package matches the firmware and platform.
- Check the relevant frontend, launcher and Dolphin logs.
- Try the Default core profile before applying custom settings.
- Preserve the previous INI files before changing profiles manually.

## Frontend does not start

- Confirm the package matches the firmware and platform.
- Confirm LÖVE and the bundled runtime libraries are present.
- Check the frontend log under `data/logs/`.
- Open Diagnostics when the frontend can still be launched.
- Reinstall only after backing up user data.

## Dolphin does not launch a game

- Confirm the Dolphin executable exists at the platform-specific path and is executable.
- Confirm the ROM path exists and is readable.
- Check the launch and Dolphin logs under the frontend's `data/logs/`.
- Check that the expected Dolphin Config files exist and are writable.
- Try the Default profile before layering custom controller, cheat or mod settings.

## Wrong profile or settings

- Check whether the profile is locked or inherits a base profile.
- Verify the selected controller family matches GameCube or Wii.
- Apply one profile at a time.
- Preserve a backup of the previous INI files.
- Do not edit global Dolphin.ini to fix one title when a game-specific override is appropriate.

## Compatibility site does not load data

- Confirm internet access to raw GitHub and jsDelivr.
- Refresh once; the service worker may be serving its last cached JSON while offline.
- Use the site's **Retry database load** control.
- Report a broken data URL with the browser's HTTP status.

## Rt:Stream cannot connect

- Confirm the PC portal and Sunshine are running.
- Confirm the handheld and PC can reach each other on the configured network.
- Check the configured host and library sync port.
- Confirm pairing is complete and the edit token is configured locally.
- Use the portal and handheld diagnostic tools before changing router/firewall rules.

## When asking for help

Include exact device, firmware, package version, steps to reproduce, expected vs. actual result and relevant redacted logs. Use [[Reporting-a-Test]] for compatibility reports.

> [!WARNING]
> Never publish ROMs, BIOS files, pairing tokens, private edit tokens, serial numbers or unredacted network details.
