# Dolphin Rt:Core Compatibility Database

The repository-root index.html is the static community compatibility website. It is a read-only browser for tracked compatibility data and GameSettings. Submitting a test prepares a GitHub issue; it never writes directly to the database.

## Source of truth and runtime copies

The canonical editable database lives in dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json. The website reads this bundled Rt:UI source.

The handheld boot updater also downloads data/games_data.json from the repository root and stores it in the frontend runtime data directory. The bundled Rt:UI file and the root download file are therefore two intentional, byte-identical copies of the same database; neither is an obsolete leftover. The compatibility Lua loader can read the bundled file or the downloaded runtime copy depending on launch context.

The canonical JSON source is:
- dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json — Rt:UI bundle and website source.
- data/games_data.json — runtime update endpoint consumed by the handheld boot initializer.

The same design applies to neither gamesettings nor unrelated databases; do not infer that every root data file has a bundled mirror. For this compatibility file, keep the two copies identical. tools/normalize_games_data.py checks parity and writes both copies together. Never edit only one copy by hand.

GameSettings remain in dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json for the website and app bundle; the boot updater has its own configured root data endpoint.

## Compatibility data contract

games_data.json uses schema_version 2. The root contains the legacy version field, schema_version, last_update, catalogs and games.

Each game group is keyed by the exact tuple Game ID + system + region. Every entry is one independently recorded test session. Different devices, firmware, Rt:Core builds, profiles, Dolphin revisions or game regions remain separate observations. A report with a mismatched Game ID is never merged under the group's title.

The shared catalogs define canonical spelling for handheld models, muOS releases, Rt:Core releases and core profiles. The site uses these catalogs to populate its report form; it does not keep another hard-coded list. A custom value is allowed when a tester has a genuine build or profile not yet in the catalogue.

An empty firmware in an older entry means not recorded. The generic label muOS Jacaranda (version not specified) is not equivalent to a numbered 2601.x build. The schema migration does not update last_update, which continues to describe the latest imported test data rather than the migration date.

The normative schema is docs/schemas/games_data.schema.json. The idempotent normalizer is tools/normalize_games_data.py. Run it in check mode during CI; use --write only when intentionally migrating aliases or repairing a stale copy.

## Test report intake

The site form captures:

- Game ID, system, region and optional disc revision.
- Tester, device, board revision and exact muOS version.
- Rt:Core release, Dolphin build, profile and graphics backend.
- Gameplay duration, repeatable scene and local test date.
- Rating, boot/playability result and minimum / maximum gameplay FPS.
- Audio, graphics, input and stability observations.
- Reproduction notes, optional GameSettings and public evidence links.

The form uses data-driven catalogues. It validates required setup fields, custom entries, FPS pairs/range, duration and HTTP(S) evidence URLs. It builds a readable GitHub issue with a machine-readable JSON payload and opens the compatibility-test-report.md issue template. Oversized prefilled URLs are rejected with a request to link the resource instead of embedding a large INI block.

An issue is not a database entry. A maintainer must review the exact identity, report shape, evidence and privacy before merging the report into the canonical JSON. Keep every test session independent.

## Issue templates

The repository provides:

- compatibility-test-report.md — single-session compatibility evidence.
- bug_report.yml — component, exact build, expected / actual behaviour and reproduction steps.
- feature_request.yml — user problem, proposal, alternatives and acceptance criteria.
- config.yml — routes compatibility submissions to the site and disables unstructured blank issues.

The report and bug templates explicitly prohibit ROMs, BIOS, firmware images, copyrighted game files, credentials and private device identifiers.

## Ratings and interpretation

Ratings run from 0 to 5. Zero means no usable boot; one means the title starts but crashes or becomes unusable; two boots but is not playable; three is playable with meaningful issues; four is playable with minor issues; five is an excellent result for the stated setup. FPS must be measured during actual gameplay. Use N/A when FPS was not measured.

The rating is tied to the exact device, firmware, game region, emulator build and profile. A successful CI build is not a hardware certification and a result from one H700 handheld is not a guarantee for another board or firmware.

## Local preview

~~~sh
python3 -m http.server 8000
~~~

Open http://localhost:8000. Do not open the page through file:// because fetch, service worker and storage behaviour differ.

## Validation

~~~sh
python3 tools/normalize_games_data.py --check
python3 -m unittest tests/test_compat_site.py -v
~~~

The website test checks the schema version, catalogues, report identity invariants, parity of both database copies, normalizer idempotence, GitHub issue templates, local PWA icons, source URLs, Pages packaging and inline JavaScript syntax when Node.js is installed. Visual release review must still cover desktop / narrow mobile layouts and offline use after an online load.

## GitHub Pages deployment

The repository includes .github/workflows/deploy-compatibility.yml. It publishes a minimal website bundle from main and does not publish emulator sources, package archives, ROM data or the rest of the repository.

Open Settings → Pages → Build and deployment → Source and select GitHub Actions if this has not already been configured. Pull requests do not deploy. The expected project URL is https://silvercrow2323.github.io/dolphin-rt-core/.
