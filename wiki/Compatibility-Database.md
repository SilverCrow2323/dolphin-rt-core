# Compatibility Database

The Compatibility Database is the community report browser for Nintendo GameCube and Nintendo Wii titles. It compares observed results on specific handheld, firmware and emulator configurations.

## Source of truth

The static website is the repository-root index.html. The LÖVE Rt:UI frontend and website read the same canonical data:

- dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json — test reports and shared catalogs.
- dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json — GameSettings and shared resources.

The data contract is schema_version 2. The canonical group identity is Game ID + system + region. Each report entry is one independent test session; reports from other devices, firmware releases, profiles or Dolphin builds must remain separate.

## Search and filters

1. Select GameCube or Wii.
2. Search by title, Game ID, test notes, tester, handheld, firmware or core profile.
3. Filter by region, boot result, rating, tested device or muOS version.
4. Sort by rating, recent report, title or number of tests.
5. Open a game to inspect each test report before applying settings.

The device and firmware filters use actual report metadata. Missing firmware is not guessed. The Share action preserves the console and supported filters in the URL; favourites remain local to the browser.

## Reading a test report

Open the game details to compare the tester, handheld, board revision, firmware, Rt:Core release, Dolphin build, profile, graphics backend, test duration, scene, observed FPS, rating, boot / playability result, audio, graphics, input, stability, GameSettings and evidence links.

A result is not portable automatically across regions, firmware revisions, devices, Dolphin builds or profiles. A successful build or CI check is not proof of physical-device compatibility.

## Submitting a report

Use the website's Submit a Compatibility Test form. It reads the device, muOS, Rt:Core and profile options from the shared JSON catalogs. It checks required setup fields, FPS range consistency, test duration and evidence URLs, then creates a prefilled GitHub issue using the compatibility-test-report template.

The website does not write directly to the database. Maintainers validate the issue and add an independent report entry to the canonical games_data.json. For the full workflow, see [[Reporting-a-Test]] and [[Rating-Guide]].

## Issue categories

The repository provides a compatibility test report template, a bug report form and a feature request form. Blank issues are disabled to keep incoming reports structured. General documentation and project discussions are linked from the issue chooser.

## Privacy and licensing

Do not upload ROMs, BIOS files, firmware images, copyrighted game files, serial numbers, MAC addresses, pairing tokens, passwords or private logs. Screenshots and clips should contain only relevant evidence and must be safe to share publicly.

## Site deployment and checks

See [[Compatibility-Site]] for local preview, GitHub Pages configuration, PWA cache behaviour and automated checks. A committed index.html does not by itself mean that GitHub Pages is enabled.
