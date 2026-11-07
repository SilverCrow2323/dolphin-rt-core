# Changelog

Newest first. Format loosely based on Keep a Changelog.

## [Unreleased]

### Fixed (autofix2)
- launch.sh: ora applica controller, game settings, mods e logging scelti nella UI (prima venivano ignorati).
- launch.sh: ShowFPS/VPS/Speed scritti in GFX.ini [Settings] (prima Dolphin.ini [Interface], senza effetto).
- launch_screen: lista Game Settings senza rtgameset_data.ini e con le varianti .speedhack/patch.
- rtcoreprofile: valori riallineati alle descrizioni, tier lite/std/max coerenti.

### Added
- `frontend/ui/tokens.lua`: shared design token layer
  (Dual-Face Cel-Tech).
- `docs/`: full documentation set (architecture, styleguide,
  screens, paths, profiles, controller, hotkeys, Minoru,
  downloader, testing, troubleshooting, glossary).
- `dev.sh tokens`: print every design token.
- `dev.sh docs`: list documentation files.
- `dev.sh audit`: report hardcoded fonts and colors.

### Changed
- All documentation written in English only.
- `ui/button_icons.lua`: every `setLineWidth()` is now multiplied by
  the theme's `outline_boost` (GC 1.0, Wii 1.4). WiFi and GC badges
  keep their proportions but Wii gets visibly chunkier borders.

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
