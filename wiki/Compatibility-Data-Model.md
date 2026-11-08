# Compatibility Data Model

The Compatibility Database and the LÖVE frontend read the same tracked JSON. The data is grouped by title, with one or more independently submitted test reports beneath each game.

## Source files

- `games_data.json`: grouped game records and their individual test reports.
- `gamesettings.json`: community GameSettings entries and the configurations associated with each game.

Both live in `dolphin-rtcore-muos/app/Dolphin RtUI/data/`. The public site fetches these tracked files; update the source once rather than editing a second database copy.

## `games_data.json` structure

The document root contains `version`, `last_update` and a `games` array. Each element of `games` has:

| Field | Meaning |
|---|---|
| `game_info` | Canonical title identity used to group reports (`game_id`, `system`, `game`, `region`) |
| `entries` | Array of independent test reports for that game |

Each report in `entries` contains:

| Object | Fields | Meaning |
|---|---|---|
| `game_info` | `game_id`, `system`, `game`, `region` | Exact tested title / release variant |
| `test_review` | `rating`, `fps`, `boot`, `playable`, `fps_min`, `fps_max` | Observed performance and compatibility outcome |
| `test_details` | `rtcore_version`, `core_profile`, `considerations` | Runtime build, selected profile and tester notes |
| `test_environment` | `tester`, `device`, `muos_version` | Who tested it, which handheld and which firmware |
| `cover_art` | URL or empty string | Optional artwork reference |
| `custom_settings` | list | Optional per-game settings attached to the report |
| `attachments` | list | Optional evidence references |

The website's **Device** and **muOS version** filters are populated from actual `test_environment.device` and `test_environment.muos_version` values, scoped to the selected console. Empty values are not guessed; reports without recorded firmware remain visible under **All muOS versions**.

## `gamesettings.json` structure

The document root contains `version`, `last_update` and a `settings` array. Each game settings group contains `game`, `game_ids`, `system` and `configs`. A config may contain `id`, `filename`, `universal_filename`, `title`, `author`, `description`, `tags`, `raw_content` and `content_url`. The `raw_content` field is Dolphin INI text; review it as untrusted community input before distributing or applying it.

## Data integrity rules

- Keep each independent test as its own report entry.
- Do not merge reports from different regions or devices into one fictional result.
- Preserve original tester attribution and dates.
- Validate `system` as `GC` or `Wii`.
- Ratings range from 0 to 5; zero is the distinct no-boot category.
- Do not treat missing FPS, firmware or device metadata as a positive result.
- Never add ROMs, BIOS, firmware, private logs or copyrighted game files.

## Update workflow

1. Review the submitted GitHub issue.
2. Verify the JSON shape and report completeness.
3. Add the entry to the tracked source file.
4. Run `python3 -m unittest tests/test_compat_site.py -v`.
5. Confirm the frontend and compatibility site still load the source JSON.

See [[Reporting-a-Test]], [[Rating-Guide]] and [[Compatibility-Site]].
