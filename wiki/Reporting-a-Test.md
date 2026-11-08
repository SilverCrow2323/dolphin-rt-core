# Reporting a Test

A useful report must let another person reproduce the conditions. One carefully documented test is worth more than a rating with no context.

## Required details

- Game title, GameCube/Wii system, Game ID and region.
- Handheld model / board revision.
- muOS or other firmware version.
- Rt:Core package version and Dolphin build where known.
- Core profile and any game-specific GameSettings.
- Game image format and relevant patch/mod details.
- Observed boot result, playability and FPS range.
- Short description of audio, graphics, input, stability and major issues.

## Use the site form

1. Open the Compatibility Database.
2. Select **Report**.
3. Search for the exact title or Game ID and choose the matching result.
4. Enter device, firmware, Rt:Core version and profile.
5. Choose the rating that best matches the observed behavior.
6. Enter the minimum and maximum FPS observed during actual gameplay, not a menu or boot animation.
7. Describe test duration, area/scene, stutters, glitches, crashes and workarounds.
8. Submit. The site opens a pre-filled GitHub issue; review it and then create the issue.

The site does not directly write to the JSON database. A maintainer reviews the issue before integrating data.

## Evidence

Screenshots or short clips are useful when they demonstrate a visible bug or stable gameplay. Remove usernames, device serials, Wi-Fi details, pairing tokens and other personal information.

Never attach ROM, BIOS, firmware or copyrighted game files. A report should contain observations and permitted metadata only.
