# Compatibility Site Operations

The Compatibility Database is a static single-page application rooted at `index.html`. The repository also tracks its service worker (`sw.js`) and web app manifest (`manifest.json`).

## Local preview

From the repository root:

```sh
python3 -m http.server 8000
```

Open `http://localhost:8000`. Do not use `file://`: fetch, service workers and browser storage behave differently.

## Publish

The app needs no Node build step. The repository includes `.github/workflows/deploy-compatibility.yml`, which builds a minimal publication folder and deploys it whenever site files reach `main`. One-time setup is required: **Settings → Pages → Build and deployment → Source → GitHub Actions**. Pull requests never publish. The expected URL after the first successful deployment is `https://silvercrow2323.github.io/dolphin-rt-core/`. The build publishes only `index.html`, `manifest.json`, `sw.js`, `.nojekyll` and the three local UI assets; it does not upload the project source tree.

## Data sources

The app loads:

- `dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json`
- `dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json`

Raw GitHub is the primary endpoint; jsDelivr is the fallback. Same-origin artwork is used for site icons so the PWA shell can cache it locally.

## Features

- GameCube and Wii views and themes.
- Text search over title, Game ID, notes, tester, device, firmware and profile.
- Filters for region, boot result, exact rating, device and muOS version.
- Sort by rating, recency, title or report count.
- Favourites stored locally in the browser.
- Shareable URLs for console and active filters.
- Test-report hand-off to a pre-filled GitHub issue.
- Service-worker shell caching and last-known JSON fallback.

## Quality checks

```sh
python3 -m unittest tests/test_compat_site.py -v
```

The check validates source JSON contracts, local manifest icons, repository URLs, shareable filter parameters, data-driven device/firmware filters, Wiki references and inline JavaScript syntax when Node.js is installed.

Before a release, inspect wide desktop and narrow mobile layouts, verify keyboard focus, check browser console errors, and test the offline fallback after one successful online load.

See [[Compatibility-Database]] and [[Compatibility-Data-Model]].
