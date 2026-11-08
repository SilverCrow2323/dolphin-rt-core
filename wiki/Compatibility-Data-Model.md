# Compatibility Data Model

The JSON schema is intentionally small and shared between the LÖVE frontend and the root compatibility website.

## Source files

- `games_data.json`: one record per submitted test report.
- `gamesettings.json`: community GameSettings entries and content metadata.

Both live in `dolphin-rtcore-muos/app/Dolphin RtUI/data/`. The public site fetches these tracked files; update the source once rather than editing a second database copy.

## Report shape

| Object | Fields | Meaning |
|---|---|---|
| `game_info` | `game_id`, `system`, `game`, `region` | Identity of the tested title and release |
| `test_review` | `rating`, `fps`, `boot`, `playable`, `fps_min`, `fps_max` | Observed result |
| `test_details` | `rtcore_version`, `core_profile`, `considerations` | Runtime and profile context |
| `test_environment` | `tester`, `device`, `muos_version` | Hardware and firmware context |
| `custom_settings` | list | Optional settings submitted with the test |
| `attachments` | list | Evidence URLs and media labels |

The website's **Device** and **muOS version** filters are built from actual `test_environment.device` and `test_environment.muos_version` values. Empty or missing values are not guessed; reports without recorded firmware remain visible under **All muOS versions**.

## Data integrity rules

- Keep one independent test as one report entry.
- Do not merge reports from different regions or devices into one fictional result.
- Preserve original tester attribution and dates.
- Validate `system` as `GC` or `Wii`.
- Ratings range from 0 to 5; zero is the distinct no-boot category.
- Do not treat a missing FPS, firmware or device as a positive result.
- Never add ROMs, BIOS, firmware, private logs or copyrighted game files.

## Update workflow

1. Review the submitted GitHub issue.
2. Verify the JSON shape and report completeness.
3. Add the entry to the tracked source file.
4. Run `python3 -m unittest tests/test_compat_site.py -v`.
5. Confirm the frontend and compatibility site still load the source JSON.

See [[Reporting-a-Test]], [[Rating-Guide]] and [[Compatibility-Site]].
