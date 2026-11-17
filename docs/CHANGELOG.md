# Changelog

Newest first. Format loosely based on Keep a Changelog.

## [Unreleased]

### Added
- Official Dolphin Rt:Core product portal at the site root, with the Compatibility Database retained as a separate application at `compatibility.html`.
- Evidence-based release and quality documentation, including the current repository map, active Rt:UI location, contributor checks and hardware-verification procedure.

### Changed
- Rt:UI is documented at `dolphin-rtcore-muos/app/Dolphin RtUI/`; retired `frontend/` and `dev.sh` instructions are no longer presented as the active workflow.
- The muOS Task Toolkit diagnostic payload is retired from new MUXUPD packages. Upgrade cleanup targets only legacy Dolphin Rt*Core task directories and leaves unrelated muOS tasks untouched.
- Rt:Stream SFTP operations are confined to canonical configured ROM roots, with canonical-path and symlink checks for device roots and local receive paths.

### Fixed
- MUXUPD publication now builds a fresh temporary archive beside the destination, validates ZIP integrity and `manifest.sha256`, then atomically replaces the previous package. Failed or corrupt ZIP output leaves the existing package intact.
- Added regression coverage for failed ZIP writes, corrupt archives that return exit status zero, retired Task Toolkit exclusion and upgrade cleanup.
- Added a CI contract test that rejects duplicate NEXUS screen-action registration declarations.

### Release status
- Latest published stable release: **v12.0.0** (muOS Andromeda).
- Draft v12.0.1 candidate artifacts are not published releases.
- **Dolphin Rt:Core 12.5.00 / Rt:UI 3.7.0 Arcade is still under integration.** Do not treat CI, a cross-build or a draft asset as device certification.

---

> Entries below preserve the legacy FrontendONE changelog. Paths and developer commands in those historical entries describe that older implementation, not the current active Rt:UI repository layout.

## [0.5.3] — 2026-10-03

### Added
- `wii_title_db.lua`: official title lookup from GameTDB.
- `screens/minoru_room.lua`: chat screen for Minoru.
- Async ROM scan enrichment via wiitdb.
- Download pipeline now atomic (`.tmp` + validate + promote).

### Fixed
- Data downloads no longer clobber the previous file on failure.
- ROM titles use official names when available.

## [0.5.2] — 2026-10-03

### Changed
- `external.lua`: "CONFIG FILES" band is now a vertical list.
- All strings translated to English.

### Fixed
- Long filenames no longer overlap in the config-files grid.

## [0.5.1] — 2026-10-03

### Added
- Icon footers on download overlay sub-panels.
- Homebrew Hub visual redesign (3D ENTER button, colored rails).

### Fixed
- Homebrew boot file path is now absolute.

## [0.5.0] — 2026-10-03

### Added
- `input_debug.lua` rewrite: guided button + stick analysis.
- `workshop_editor.lua`: universal INI editor.
- Tier overlay in the editor.

## [0.4.x] — 2026-09

- First public builds.
- Boot animation with random variants.
- Nexus main menu with GC / Wii dual theme.
- Workshop, Flashback, Enhancer Dock, Homebrew Hub.
- Minoru character engine.
