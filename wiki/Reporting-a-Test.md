# Reporting a Test

A useful report lets another person reproduce the conditions. Record one exact game release on one exact device / firmware / emulator setup. A test report is evidence from one session, not a promise that the game behaves the same everywhere.

## Before testing

- Identify the exact Game ID, system and region.
- Record the handheld model and board revision where known.
- Record the complete muOS release, not just a nickname when a version number is available.
- Record the Rt:Core package release and Dolphin build / commit when known.
- Record the core profile, graphics backend and any GameSettings or per-game changes.
- Choose a repeatable gameplay scene and test for a meaningful duration.

## Use the Compatibility Database form

1. Open the Compatibility Database website.
2. Select Report / Submit a Compatibility Test.
3. Search by title or Game ID and select the exact match.
4. Select the exact device, firmware, Rt:Core release and core profile from the shared catalogues. Use Other / not listed only for a real value that is not yet present.
5. Add the Dolphin build, backend, device revision, test duration and scene when known.
6. Select the rating. Boot and Playability are derived from the rating so contradictory combinations cannot be submitted.
7. Enter both minimum and maximum FPS measured during gameplay, or leave both empty when FPS was not measured. Do not use menu or boot-animation peaks.
8. Mark audio, graphics, input and stability only as far as you tested them.
9. Explain the reproducible behaviour, glitches, slowdowns, crashes and workarounds. Add optional GameSettings or public evidence links.
10. Submit to GitHub. Review the prefilled issue and create it; the site does not directly modify games_data.json.

The generated issue contains a readable summary plus a JSON report payload that follows schema v2. Maintainers review the issue, preserve it as an independent session and import it into the canonical source only after validation.

## Rating guide

| Rating | Meaning |
|---:|---|
| 0 | Does not boot / no usable start |
| 1 | Starts or reaches a stage, then crashes or becomes unusable |
| 2 | Boots, but performance or defects make it unplayable |
| 3 | Playable with meaningful issues, slowdowns or workarounds |
| 4 | Playable with minor issues that do not usually block progress |
| 5 | Excellent result for the stated device and settings |

## Evidence and privacy

Screenshots and short clips are useful when they demonstrate a visible issue or actual gameplay. Link only to evidence that you are allowed to share. Redact usernames, device serials, MAC addresses, Wi-Fi details, pairing tokens, passwords and private logs.

Never upload ROMs, BIOS files, firmware images, copyrighted game files or private device data. The GitHub issue is public unless repository permissions say otherwise; do not include personal information.

## One report, one setup

Do not merge results from different regions, devices, muOS releases, Rt:Core versions or profiles. If you tested three configurations, submit three reports. Use Not tested or Not recorded instead of guessing.
