# Compatibility Database

The Compatibility Database is a static web app in the repository root (`index.html`). It presents community-submitted GameCube and Wii test reports from the tracked frontend data files.

## What it shows

- Game title, Game ID and region variants.
- Boot result, playability, rating and reported FPS range.
- Test device, firmware, Rt:Core version, profile and written considerations.
- Links to GameSettings and shared community resources when available.
- Individual report history in the game detail view.

The source JSON files are:

- `dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json`
- `dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json`

Do not fork the data into a second manually-maintained copy. The website fetches the tracked JSON from the current repository's `main` branch.

## Search and filters

1. Select **GameCube** or **Wii**.
2. Search by title, Game ID or words found in test notes.
3. Narrow by region or boot result.
4. Select a rating bucket or sort by recent, title or number of reports.
5. Open a game card to inspect report details and available settings.

The **Share** control copies a URL containing the current console and supported filters. Favourites are browser-local and are not included in shared links.

## Interpreting results

A card summarizes multiple test entries. Open it to inspect the underlying reports. A result can vary with device revision, firmware, game region/revision, image format, profile and Rt:Core build.

The database is not an official guarantee and should not be treated as a substitute for a backup or a careful first launch.

## Suggesting a correction

Use the site's Report action or open a GitHub issue with the `test-report` label. Include the exact game ID and the source report that needs correction. Do not overwrite or remove another tester's result without traceable evidence.
