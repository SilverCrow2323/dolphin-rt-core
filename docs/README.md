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
