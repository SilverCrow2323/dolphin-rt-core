# Dolphin Rt:Core — Unified Magazine Portal

The public website is one editorial portal, branded as **SPDW Factory · The Handheld Emulation Files**. The visual direction is a rough, colorful underground cyberpunk manga magazine: bold cover typography, issue labels, halftone texture, hard-edged panels, bright warning colors and restrained motion.

## One portal, one navigation

The repository-root `index.html` is the magazine cover and project dashboard. The field guide, profile lab, knowledge base and Rt:Stream editorial section use the same navigation, typography, palette, transitions and footer.

`compatibility.html` is the Compatibility Workshop inside the same portal experience. It is not a separate product or visual identity. It retains the existing GameCube/Wii switch, report submission, filters, game details and the **GameSettings** panel. GameSettings is deliberately grouped with Compatibility: it is not a peer item in the global navigation.

The `gamesettings.html` route remains available for direct links and the searchable INI archive, but the main navigation and portal entry points direct users to Compatibility + GameSettings as one workspace.

## Editorial sections

1. **The Project** — current overview, stable release, platform targets and project activity.
2. **Field Guide** — muOS Andromeda installation, first boot, recovery and known device-specific traps.
3. **Profile Lab** — Rt:Boost, Rt:Prime, Rt:Pure, canonical profiles and safe tuning practices.
4. **Compatibility Workshop** — game reports, filters, test evidence and GameSettings.
5. **Knowledge Base** — practical docs, engineering references and troubleshooting.
6. **Rt:Stream** — presented as an internal Dolphin Rt:Core subsystem, not a separate project portal.

## Compatibility data and GameSettings

The canonical editable database lives in `dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json`. The Compatibility Workshop reads this bundled Rt:UI source.

The handheld boot updater also downloads `data/games_data.json` from the repository root and stores it in the frontend runtime data directory. These two copies are intentional and byte-identical. `tools/normalize_games_data.py --check` validates parity.

GameSettings are integrated into the Compatibility application and retain their own existing JSON source, `dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json`. The site must not create a second canonical GameSettings database.

The website is read-only with respect to tracked data. Submitting a test prepares a GitHub issue; it never writes directly to the compatibility database. A maintainer reviews identity, evidence, privacy and schema before importing a report.

## Reporting contract

A report records the exact Game ID, system, region, device, board revision, muOS firmware, Rt:Core build, Dolphin build, profile, graphics backend, duration, repeatable scene, rating, boot/playability result, FPS measurements and observations.

Ratings run from 0 to 5. A score is tied to the tested configuration and is not a universal guarantee. CI success is not hardware certification. Do not publish ROMs, BIOS, firmware images, copyrighted game files, credentials or private device identifiers.

## Build and validation

Run:

```sh
python3 tools/normalize_games_data.py --check
python3 -m unittest tests/test_compat_site.py -v
```

The Pages builder publishes only the website, local catalogues and referenced artwork. The service-worker cache version must be bumped when the portal shell or editorial assets change.

Visual review must cover desktop and narrow mobile layouts, Compatibility filters, GameSettings modal, report submission, game-detail modal and offline shell behaviour. Respect `prefers-reduced-motion`.

## GitHub Pages

The deployment workflow publishes the unified portal from `main`. The expected project URL is https://silvercrow2323.github.io/dolphin-rt-core/.
