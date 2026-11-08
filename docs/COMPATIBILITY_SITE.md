# Compatibility Database website

The repository-root `index.html` is the static web app for the Dolphin Rt:Core community compatibility database. It is client-side: simply browsing the site does not upload ROMs, BIOS images, firmware, emulator binaries or account credentials.

## Source of truth

The app reads these tracked JSON files from the current repository's `main` branch:

- `dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json` — game test reports.
- `dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json` — community GameSettings and shared resources.

The URLs in `index.html` use raw GitHub with jsDelivr as a fallback. Keep both endpoints aligned if files move. Do not maintain a second, manually edited database copy at the repository root.

## Local preview

From the repository root:

```sh
python3 -m http.server 8000
```

Open `http://localhost:8000`. Do not open the HTML file via `file://`; browser fetch, service-worker and storage behavior differ.

## GitHub Pages

When Pages is enabled for the repository, configure it to publish from the `main` branch and repository root. The app needs no Node build step. If Pages is not enabled, the tracked HTML remains the site source but is not automatically public.

## Features

- Separate GameCube and Wii themes.
- Search by title, Game ID, test notes, tester, device, firmware and profile; filter by region, boot result, rating, tested handheld and muOS version.
- Sort by rating, recency, title or number of tests.
- Browser-local favourites.
- Detail modal, test history, GameSettings discovery and pre-filled GitHub issue hand-off.
- Shareable filter links using `system`, `q`, `region`, `boot`, `rating`, `sort`, `device` and `muos`. Favourites are not shared because they are local to each browser.
- PWA shell cache and last-known JSON fallback when offline.

Device and muOS filter options are built from the actual report metadata at load time. Empty or unknown metadata is not silently guessed; reports without a recorded firmware remain visible under **All muOS versions**.\n\nDevice and firmware filter options are built from actual `test_environment.device` and `test_environment.muos_version` values in the reports. Empty values are not guessed; reports without a recorded firmware remain visible under **All muOS versions**.

## Data and rating principles

Compatibility data is community-submitted, not a universal guarantee. Interpret every report with its device, firmware, game region/revision, Rt:Core version and profile. Do not turn an untested game into a positive result by inference.

The rating filter is exact: zero is the separate no-boot category; one through five are the matching reported rating. Aggregated cards summarize entries; the detail view retains individual reports.

## Website quality checks

```sh
python3 -m unittest tests/test_compat_site.py -v
```

The test checks JSON inputs, local PWA icons, current repository URLs and inline JavaScript syntax when Node.js is available. Before releasing visual changes, review desktop and narrow mobile widths and check offline behavior after a successful online load.
