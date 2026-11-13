# Compatibility Data Model

The Compatibility Atlas and Rt:UI read the same tracked JSON file. Game records are grouped by title identity; each entry under a group remains an independent test report.

## Source files

- `dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json`: grouped games and individual test reports.
- `dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json`: community GameSettings entries and their configurations.

The public site reads these files directly. Update the source once; do not create a manually maintained mirror.

## `games_data.json` structure

The root contains `version`, `last_update` and a `games` array. Each item in `games` has:

| Field | Meaning |
|---|---|
| `game_info` | Canonical game identity: `game_id`, `system`, `game`, `region` |
| `entries` | Independent test reports for that game |

Each report contains:

| Object | Fields | Meaning |
|---|---|---|
| `game_info` | `game_id`, `system`, `game`, `region` | Tested title and release variant |
| `test_review` | `rating`, `fps`, `boot`, `playable`, `fps_min`, `fps_max` | Observed compatibility and performance |
| `test_details` | `rtcore_version`, `core_profile`, `considerations` | Runtime build, profile and tester notes |
| `test_environment` | `tester`, `device`, `muos_version` | Tester, handheld and firmware |
| `cover_art` | URL or empty string | Optional artwork |
| `custom_settings` | list | Optional per-game settings |
| `attachments` | list | Optional evidence links |

The field names and the `GC` / `Wii` system codes are compatibility contracts. The repeated per-entry `game_info` object is retained for Rt:UI consumers.

## Canonical metadata vocabulary

Canonicalize labels in the JSON source and in all report submission forms. Do not rely on presentation-only aliases.

### Devices

Use manufacturer plus exact model, for example:

- `Anbernic RG35XX H`
- `Anbernic RG34XX SP`
- `Anbernic RG40XX H`
- `Anbernic RG CubeXX`

Normalize cosmetic variants such as `RG35XXH` and `RG 35XX H` to `Anbernic RG35XX H`. Use a descriptive family label only when the source genuinely lacks the exact model. Unknown or absent device data is `""`; never convert it into a likely model.

### muOS firmware

Format precise versions as:

- `muOS 2606.0 · Andromeda`
- `muOS 2601.1 · Funky Jacaranda`
- `muOS 2601.0 · Jacaranda`

When the source contains only a codename, retain it and say that its numeric version was not recorded, for example `muOS Jacaranda · version not recorded`. The typo `Funky Jakaranda` is a spelling alias for Funky Jacaranda, but it does not provide a numeric release number. An unreported firmware is `""`.

### Dolphin Rt:Core builds

Use the `Dolphin Rt:Core` prefix and one normalized version style, then append a codename or channel where relevant:

- `Dolphin Rt:Core 11.5.00-III · FrontendONE`
- `Dolphin Rt:Core 11.5.00-II · Bash Arsenal`
- `Dolphin Rt:Core 11.5.00-I · Comfort Zone · Prerelease`
- `Dolphin Rt:Core 11.0.00 · Development`

Use `Dolphin Rt:Core Legacy (exact version not recorded)` only for records genuinely identified as legacy but lacking an exact build. Use `Dolphin Rt:Core version not recorded` for an explicitly unknown build. Never promote a historical report to a newer release.

### Profiles

Use stable capitalization and spelling: `Default`, `Speedhacks`, `Performance`, `Compatibility`, `Black Screen Fix`, `Safe`, `Lite`, `Troubleshooting`, `Ultra`, `Speedup 1`, `Speedup 2`.

A test covering multiple profiles must not be recorded as a single profile. Use `All profiles tested` when the report says all profiles were tested, or a descriptive `Multiple profiles: ...` label when the exact set is known. If the set is unknown, use `Multiple profiles (details not recorded)`. A missing profile is `""`.

## Data integrity rules

- Keep every independent test as its own report entry.
- Do not merge reports from different regions, devices, firmware versions or profiles into a fictional result.
- Preserve tester attribution, notes, dates, ratings and FPS observations.
- Validate `system` as `GC` or `Wii`.
- Ratings range from 0 to 5; zero is the distinct no-boot category.
- Missing device, firmware, build or profile metadata must not be guessed.
- Do not add ROMs, BIOS, firmware images, private logs or copyrighted game files.
- Keep the existing schema field names stable for the LÖVE frontend and public site.

## Update workflow

1. Review the submitted GitHub issue.
2. Verify game identity, report completeness and environment fields.
3. Normalize device, muOS, Rt:Core and profile labels against this page.
4. Add the new report to the tracked source file without deleting prior observations.
5. Run `python3 -m unittest tests/test_compat_site.py -v`.
6. Confirm the website, filters and Rt:UI compatibility loader still read the same source.

See [[Reporting-a-Test]], [[Rating-Guide]] and [[Compatibility-Site]].
