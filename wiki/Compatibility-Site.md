# Compatibility Atlas — Site Operations

The **Dolphin Rt:Core Compatibility Atlas** is a static single-page application rooted at `index.html`. It runs on GitHub Pages and locally, and is installable as a PWA. Its data source is the same JSON consumed by Rt:UI.

## Local preview

From the repository root:

```sh
python3 -m http.server 8000
```

Open `http://localhost:8000`. Do not open the HTML file with `file://`: browser fetch, service-worker and storage behavior differ.

## Publish

The app needs no Node build step. `.github/workflows/deploy-compatibility.yml` builds a deliberately minimal publication directory and deploys it whenever website or data files reach `main`. One-time setup: **Settings → Pages → Build and deployment → Source → GitHub Actions**. Pull requests do not publish. The project URL is:

`https://silvercrow2323.github.io/dolphin-rt-core/`

Only `index.html`, `manifest.json`, `sw.js`, `.nojekyll` and the three local UI assets are published. The emulator source tree, package archives and ROM data are not included.

## Atlas sections

- **Browse database:** GameCube and Wii modes, title and Game ID search, filters, ratings, sorting, favourites, deep links and shareable filter URLs.
- **Devices & muOS firmware:** live counts from reports, canonical device names, exact firmware labels and explicit missing-data counts.
- **Rt:Core builds & profiles:** reported core build distribution and normalized profile names, with prereleases and legacy reports kept distinct.
- **Methodology:** rating scale, boot/playability distinction, environment comparison and a repeatable test procedure.
- **Contribute:** structured test reports, GameSettings and repository/Wiki links.
- **FAQ:** limitations, missing metadata, legacy labels, PWA behavior and submission privacy.

The game detail modal keeps each tester's report separate. GameSettings still supports browsing, filters, INI inspection/download and the contribution hand-off.

## Data endpoints

- `dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json`
- `dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json`

Raw GitHub is the primary endpoint; jsDelivr is the fallback. The website and Rt:UI must use these exact same source files.

## Submission intake

Website test reports open a prefilled GitHub issue with a JSON payload. The native GitHub issue form is accepted as well. `.github/workflows/merge-submission.yml` validates, canonicalizes and imports approved report content into the nested source JSON. GameSettings/resource issues are parsed and added to the matching nested GameSettings file.

The intake workflow serializes issue imports and records the source issue number, so the `opened`, `labeled` and `edited` events do not create duplicate entries. It must never write a second copy under root `data/`.

## Canonical naming

Use manufacturer + exact model for devices, `muOS <version> · <codename>` for firmware, `Dolphin Rt:Core <version> · <codename>` for core builds, and stable profile labels such as `Speedhacks` and `Black Screen Fix`. Leave unknown data blank. See [[Compatibility-Data-Model]] for the complete rules.

The 12.5.00 Arcade line is the planned next release candidate; do not display it as a published stable version until the release has actually been published. Rt:UI remains 3.7.0 Arcade.

## Quality checks

```sh
python3 -m unittest tests/test_compat_site.py -v
```

The suite validates JSON contracts and canonical metadata, website sections, report vocabulary, source links, the minimal Pages build and inline JavaScript syntax when Node.js is installed. Before publication, inspect desktop and mobile widths, keyboard navigation, browser console errors, report submission, GameSettings, favourites, shareable filters and offline fallback.

See [[Compatibility-Database]], [[Compatibility-Data-Model]] and [[Reporting-a-Test]].
