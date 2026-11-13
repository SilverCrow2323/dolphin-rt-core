# Compatibility Site Operations

The Compatibility Database is a static single-page application rooted at index.html. The repository also tracks its service worker (sw.js) and web app manifest (manifest.json).

## Local preview

From the repository root:

~~~sh
python3 -m http.server 8000
~~~

Open http://localhost:8000. Do not use file://: fetch, service workers and browser storage behave differently.

## Publish

The app needs no Node build step. The repository includes .github/workflows/deploy-compatibility.yml, which builds a minimal publication folder and deploys it whenever site files reach main. One-time setup is required: Settings → Pages → Build and deployment → Source → GitHub Actions. Pull requests never publish. The expected URL after the first successful deployment is https://silvercrow2323.github.io/dolphin-rt-core/. The build publishes only index.html, manifest.json, sw.js, .nojekyll and the three local UI assets; it does not upload the project source tree.

## Data sources

- dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json — bundled Rt:UI source and website input.
- data/games_data.json — root download endpoint used by the handheld boot initializer to refresh runtime data.
- dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json — GameSettings and resources.

The two games_data.json copies must remain byte-identical. tools/normalize_games_data.py checks parity and updates both together. The LÖVE compatibility loader can consume the bundled copy or the downloaded runtime copy depending on launch context. The website reads the bundled Rt:UI source.

Raw GitHub is the primary endpoint for the website; jsDelivr is the fallback. Same-origin artwork is used for site icons so the PWA shell can cache it locally.

## Project Portal

The homepage introduces Dolphin Engine, RtSys, Rt:UI and Rt:Stream, shows the platform matrix, links to practical Wiki pages and displays the latest stable GitHub release with its attached MUXUPD / AppImage / RPM assets. It ignores draft and prerelease releases and has a last-known stable fallback for API outages. Compatibility game and test counts are refreshed from the canonical database with fallback values.

## Features

- GameCube and Wii views and themes.
- Text search over title, Game ID, notes, tester, device, firmware and profile.
- Filters for region, boot result, exact rating, device and muOS version; device/firmware options follow the currently selected console.
- Sort by rating, recency, title or report count.
- Favourites stored locally in the browser.
- Shareable URLs for console and active filters.
- Structured test-report hand-off to a prefilled GitHub issue using the shared catalogue.
- Individual test detail cards include Dolphin build, graphics backend, gameplay duration, scene and subsystem notes when supplied.
- Service-worker shell caching and last-known JSON fallback.

## Report intake and issue templates

The report form uses the schema v2 catalogs from games_data.json for device, firmware, Rt:Core and profile selectors. It checks the setup, custom values, FPS pair/range, duration and HTTP(S) evidence URLs. It creates a readable summary and a JSON report payload but does not write to the database.

GitHub provides separate compatibility-test-report, bug-report and feature-request templates. Blank issues are disabled; contact links direct users to the site, Wiki and discussions. Maintainers review reports before importing them.

## PWA and offline behaviour

The web app manifest describes the Project Portal. The service worker precaches both public pages and caches successful navigation responses by their actual request URL, preserving separate offline copies of the portal and database. External Wiki, GitHub issue creation and download links still require a connection.

## Quality checks

~~~sh
python3 tools/normalize_games_data.py --check
python3 -m unittest tests/test_compat_site.py -v
~~~

The checks validate schema and catalogue structure, both data copies, issue templates, local manifest icons, repository URLs, shareable filter parameters, data-driven filters, Wiki references and inline JavaScript syntax when Node.js is installed.

Before a release, inspect wide desktop and narrow mobile layouts, verify keyboard focus, check browser console errors, and test the offline fallback after one successful online load.

See [[Compatibility-Database]] and [[Compatibility-Data-Model]].
