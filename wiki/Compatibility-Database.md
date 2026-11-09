# Compatibility Database

The Compatibility Database is the community report browser for Nintendo GameCube and Nintendo Wii titles. It helps compare observed results on specific handheld and firmware combinations.

## Source of truth

The static web app is the root `index.html`. It reads the tracked files:

- `dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json` — test reports.
- `dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json` — community settings.

The frontend and website should read the same source data. Do not maintain an untracked duplicate.

## Search and filters

1. Select **GameCube** or **Wii**.
2. Search by title, Game ID, test notes, tester, handheld, firmware or core profile.
3. Filter by region, boot result, rating, tested device or muOS version.
4. Sort by rating, recent report, title or number of tests.
5. Open a game to inspect individual reports before applying settings.

The **Share** action preserves the console and supported filters in the URL. Favourites remain local to the browser and are not shared.

## Interpreting results

An aggregated game card summarizes multiple report entries. Open the details to compare each tester's device, muOS version, Rt:Core and Dolphin versions, profile, GameSettings, game ID, region, observed FPS, stability, audio, graphics and input notes.

A result is not portable automatically across regions, firmware revisions, devices or Dolphin builds.

## Submitting a report

Use the site's Report form. It prepares a GitHub issue; it does not write directly to the JSON database. Maintainers review the report before updating the source. Follow [[Reporting-a-Test]] and [[Rating-Guide]].

## Privacy and licensing

Do not upload ROMs, BIOS files, firmware, copyrighted game images, serial numbers, pairing tokens or private logs. Screenshots should contain only the evidence needed to reproduce or understand the report.

## Site deployment

See [[Compatibility-Site]] for local preview, GitHub Pages configuration, the PWA cache and automated checks. A committed `index.html` does not by itself mean that GitHub Pages is enabled.
