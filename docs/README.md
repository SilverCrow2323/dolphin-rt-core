# DolphinUI — Documentation

Index of every reference document for the FrontendONE flavour of
Dolphin Rt:Core.

## Core references

| Document | What it covers |
|---|---|
| [STYLEGUIDE.md](STYLEGUIDE.md) | Dual-Face Cel-Tech visual grammar: palette, typography, geometry, motion, components. |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Module layout, state ownership, screen registry, dispatch flow. |
| [SCREENS.md](SCREENS.md) | Catalog of every screen, entry points, accepted params, keys. |
| [PATHS.md](PATHS.md) | Filesystem layout, live config vs workshop, runtime data. |
| [DATA_FILES.md](DATA_FILES.md) | JSON and text data files, download pipeline, validation. |
| [PROFILES.md](PROFILES.md) | Rt:Core profile families, tiers, GameSettings, apply/rollback. |
| [CONTROLLER.md](CONTROLLER.md) | Controller profiles, muOS SDL numbering, button maps. |
| [HOTKEYS.md](HOTKEYS.md) | Hotkeys.ini format, live menu bindings, keyboard remap. |
| [MINORU.md](MINORU.md) | Character engine, persona, visor, history, workspace. |
| [DOWNLOADER.md](DOWNLOADER.md) | Download queue, install targets, extract pipeline. |
| [TESTING.md](TESTING.md) | `dev.sh` usage, syntax check, live launch, log rotation. |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common issues and known fixes. |
| [GLOSSARY.md](GLOSSARY.md) | Project-specific terms and acronyms. |
| [CHANGELOG.md](CHANGELOG.md) | Version history, newest first. |

## Conventions used in these docs

- **Language:** English only. No mixed-language comments, no Italian
  strings in code, comments or logs.
- **Paths:** relative to the repository root unless explicitly
  prefixed with `/`.
- **Code blocks:** copy-paste ready. Shell blocks assume `bash`.
- **Terminology:** see `GLOSSARY.md` for Rt:Core-specific words
  (Workshop, Flashback, Triptych, Tier, Enhancer, etc.).

## Where to start

- First time on the project → **ARCHITECTURE.md**.
- Contributing UI work → **STYLEGUIDE.md**.
- Adding a screen → **SCREENS.md** + **PATHS.md**.
- Debugging a boot issue → **TROUBLESHOOTING.md**.

## Rt:Editor NEXUS actions

The editor publishes stable actions after screen initialization:

- `editor.save` — persist pending INI changes; reports write failures and retains dirty state.
- `editor.change_selected` — adjust the selected supported value by one step (`-1` or `1`).
- `editor.recommend_selected` — apply the selected option's guide recommendation.
- `editor.switch_tab` — switch by stable tab ID (`core`, `video`, `hacks`, etc.).
- `editor.state` — return mode, profile/game, tab, selected option, dirty and lock state.

Locked profiles reject edits and saves at the editor boundary. Actions reuse the screen's existing INI and guide logic.

## GameSettings NEXUS actions

The GameSettings browser exposes refresh, tab switching, open/expand and state actions. The per-game explorer exposes refresh, open/create, activate/deactivate, confirmation-based deletion requests and a state snapshot. Deletion remains behind the existing confirmation modal; the NEXUS action only requests that confirmation.

## Settings NEXUS actions

The Settings screen exposes stable actions to switch sections (`LIBRARY`, `EDITORS`, `DISPLAY`, `SYSTEM`, `ABOUT`), change the selected choice/toggle, run the selected action row, and retrieve a read-only state snapshot. Actions reuse the screen's existing setters and operation callbacks.

## Mod Vault NEXUS actions

The Mod Vault exposes category switching, selected-item toggling, category-wide enable/disable and a state snapshot. Mutating actions are rejected when the screen is opened without a selected game, preserving the installed-catalog read-only mode.

## ROM Folders NEXUS actions

The ROM Folders screen exposes refresh, browse, open, add (GC/Wii), remove, finish/rescan and state actions. Removal is restricted to the registered-folder list; adding is restricted to active browse mode and the two supported system IDs.

## Compatibility List NEXUS actions

The Compatibility browser exposes database refresh, stable filter IDs (`all`, `playable`, `issues`, `not_playable`), owned-library filtering, initial-letter navigation, open-owned-game and a read-only state snapshot. Games absent from the local library remain non-launchable.

## Rt:Core Env Triage NEXUS actions

The triage screen exposes rescan, flavour selection, checklist inspection, check selection, report saving and a state snapshot. Report saving is only allowed after the incremental scan completes; scan progress and verdict remain owned by the triage engine.
