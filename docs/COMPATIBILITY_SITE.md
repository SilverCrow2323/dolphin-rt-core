# Dolphin Rt:Core Compatibility Atlas

The repository-root `index.html` is the static web application for the Dolphin Rt:Core Compatibility Atlas. It is deployed to GitHub Pages and also runs locally. Browsing the site does not upload ROMs, BIOS images, firmware, emulator binaries or account credentials.

## Source of truth

The application reads the tracked data directly from the current repository's `main` branch:

- `dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json` — grouped game identities and independent compatibility reports.
- `dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json` — community GameSettings and shared resources.

The public site uses raw GitHub with jsDelivr as a fallback. Do not maintain a second, manually edited copy of either database at the repository root.

## What the Atlas contains

### Compatibility browser
- Separate GameCube and Wii visual identities.
- Search by title, Game ID, tester, notes, device, muOS firmware, profile and Rt:Core build.
- Filters for region, boot result, exact rating, tested handheld and muOS release.
- Sorting by compatibility, recency, title or report count.
- Game cards, detailed report history and shareable filter URLs.
- Browser-local favourites; favourites are not uploaded or shared.

### Environment and build explorer
- Live report counts by canonical device, muOS release, Rt:Core build and profile.
- Explicit counts for missing environment metadata.
- Legacy and prerelease core labels remain distinguishable from released builds.
- Multiple-profile reports remain clearly marked as multi-profile tests.

### Methodology and contribution
- A detailed zero-to-five rating explanation.
- Guidance for comparing region, device, firmware, core build, profile and FPS.
- A structured test-report form that prepares a GitHub issue for the user to review.
- A GameSettings browser and contribution flow.

### Offline and installable experience
- PWA manifest and service worker cache the site shell.
- Successfully fetched JSON responses are cached for offline fallback.
- Offline use depends on which data was previously retrieved while online.

## Local preview

From the repository root:

```sh
python3 -m http.server 8000
```

Open `http://localhost:8000`. Do not open the HTML file with `file://`; browser fetch, service-worker and storage behavior differ.

## GitHub Pages deployment

The repository includes `.github/workflows/deploy-compatibility.yml`. When site changes reach `main`, the workflow builds a minimal publication directory and deploys it to Pages. It does not publish emulator sources, package archives, ROM data or the rest of the repository.

One-time repository setup: **Settings → Pages → Build and deployment → Source → GitHub Actions**. The expected project-site URL is:

`https://silvercrow2323.github.io/dolphin-rt-core/`

The workflow publishes from `main` or manual dispatch; pull requests do not publish.

## Canonical metadata policy

Canonical names are stored in each report's existing fields. The JSON schema remains backward-compatible with Rt:UI:

| Field | Canonical form | Rule |
|---|---|---|
| Device | `Anbernic RG35XX H`, `Anbernic RG34XX SP`, etc. | Manufacturer and model spelling are consistent. |
| muOS | `muOS 2601.1 · Funky Jacaranda` | Numeric version first, then codename. |
| Rt:Core | `Dolphin Rt:Core 11.5.00-II · Bash Arsenal` | Product name, normalized version, optional channel/codename. |
| Profile | `Speedhacks`, `Black Screen Fix`, `All profiles tested` | Stable title casing; multiple profiles stay explicit. |

Missing information is an empty string, not a guessed value. Historical `Legacy` reports are labelled `Dolphin Rt:Core Legacy (exact version not recorded)`. Codename-only muOS reports say that the numeric version was not recorded. The typo `Funky Jakaranda` is normalized to the canonical codename, but no numeric version is invented.

The current release candidate is **Rt:Core 12.5.00 · Arcade** with **Rt:UI 3.7.0**. The website must distinguish candidate builds from published stable releases.

## Data and rating principles

Compatibility data is community-submitted, not a universal guarantee. Interpret every report with its device, firmware, game region/revision, Rt:Core build and profile. Do not turn an untested game into a positive result by inference.

The rating filter is exact: zero is the separate no-boot category; one through five are the matching reported rating. The detail view retains individual reports even when cards aggregate multiple tests.

## Validation

Run the compatibility website tests from the repository root:

```sh
python3 -m unittest tests/test_compat_site.py -v
```

The suite checks the JSON contract and canonical naming, local PWA icons, repository URLs, website sections, report vocabulary, the minimal Pages build and inline JavaScript syntax when Node.js is available. Before publication, review desktop and narrow mobile widths, the data filters, report hand-off, GameSettings modal and offline behavior.
