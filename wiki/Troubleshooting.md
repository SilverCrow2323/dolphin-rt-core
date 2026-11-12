# Troubleshooting

Start with the least destructive check. Do not delete configuration, saves or emulator directories as a first response.

## Frontend does not start

- Confirm the package matches the firmware and platform.
- Confirm LÖVE and bundled runtime libraries are present.
- Check the frontend log under `data/logs/`.
- Open Diagnostics where the frontend can still be launched.
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
- Apply one profile at a time and preserve a backup of the previous INI files.
- Do not hand-edit global Dolphin.ini to fix one title if a game-specific override is appropriate.

## Rt:System Status Center shows an unexpected state

- Press **M** and let the panel refresh its local status.
- Distinguish Wi-Fi carrier state from the separate Rt:Stream portal and Sunshine checks.
- **CACHED** means a local database is present; **UPDATED** means it downloaded during this boot.
- **PREVIOUS COPY** means an update failed but an older local file was kept.
- Check the frontend log and redact hostnames, IP addresses, SSIDs and tokens before sharing.

See [[Rt-System-Status-Center]].

## Graphics Mods are not visible or do not activate

- Keep official resources under Sys/Load/GraphicMods and user mods under Load/GraphicMods.
- Confirm each mod has a valid metadata.json and a matching Game ID / prefix / all.txt marker.
- Enable the mod for that game in **Mod Vault → Graphics Mods**, then relaunch.
- Check the per-game JSON under Config/GraphicMods and GFX.ini → [Settings] EnableMods.
- Do not delete Sys/GameSettings or Sys/Load/GraphicMods to troubleshoot a per-game issue.

See [[Graphics-Mods]].

## Compatibility site does not load data

- Confirm internet access to raw GitHub and jsDelivr.
- Refresh once; the service worker may be serving its last cached JSON while offline.
- Use the site's Retry database load control.
- Report a broken data URL with the browser's HTTP status, but do not paste private browser storage.

## Rt:Stream cannot connect

- Confirm the PC portal and Sunshine are running.
- Confirm the handheld and PC can reach each other on the configured network.
- Check the configured host and library sync port.
- Confirm pairing was completed and the edit token is configured locally; never publish the token in an issue.
- Use the portal and handheld diagnostic tools before changing router/firewall rules.

## When asking for help

Include exact device, firmware, package version, steps to reproduce, expected vs. actual result and relevant redacted logs. See [[Reporting-a-Test]] for compatibility reports.
