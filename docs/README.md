# Dolphin Rt:Core — technical documentation

This index points to the current engineering references for the multi-platform Dolphin Rt:Core repository.

## Architecture and implementation

| Document | What it covers |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Module layout, state ownership, screen registry and dispatch flow. |
| [NEXUS.md](NEXUS.md) | Stable action IDs, registration, state contracts and persistence. |
| [SCREENS.md](SCREENS.md) | Screen catalog, entry points, accepted parameters and controls. |
| [PATHS.md](PATHS.md) | Filesystem layout, live configuration, Workshop and runtime data. |
| [DATA_FILES.md](DATA_FILES.md) | JSON/text data, refresh pipeline and validation. |
| [PROFILES.md](PROFILES.md) | Rt:Core profile families, tiers, GameSettings and apply/rollback. |
| [CONTROLLER.md](CONTROLLER.md) | Controller profiles, muOS SDL numbering and button maps. |
| [HOTKEYS.md](HOTKEYS.md) | Dolphin 2606 Hotkeys.ini format, keyboard remapping and SDL pad mode. |
| [DOWNLOADER.md](DOWNLOADER.md) | Download queue, install targets and extraction pipeline. |
| [STYLEGUIDE.md](STYLEGUIDE.md) | Dual-Face Cel-Tech visual grammar, palette, typography and components. |

## Development and quality

| Document | What it covers |
|---|---|
| [DEVELOPMENT.md](DEVELOPMENT.md) | Host setup, safe development data and frontend workflow. |
| [TESTING.md](TESTING.md) | Current Lua, LÖVE, CI, packaging and hardware verification procedures. |
| [FULL_PROJECT_AUDIT.md](FULL_PROJECT_AUDIT.md) | Evidence-based audit findings, release gates and prioritized work queue. |
| [QUALITY.md](QUALITY.md) | Quality principles and validation expectations. |
| [RELEASE.md](RELEASE.md) | Release process and artifact boundaries. |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common issues and known fixes. |
| [REPO_GUIDE.md](REPO_GUIDE.md) | Repository conventions and contribution guidance. |
| [GLOSSARY.md](GLOSSARY.md) | Project terms and acronyms. |
| [ASSETS.md](ASSETS.md) | Asset inventory and usage. |
| [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) | Third-party provenance and license inventory. |
| [CREDITS.md](CREDITS.md) | Project credits. |
| [CHANGELOG.md](CHANGELOG.md) | Version history, newest first. |

## Practical Wiki

The tracked \`wiki/\` directory is the source for the GitHub Wiki. Use it for FAQs, short procedures, controller/firmware guides, troubleshooting and quick-start instructions. Keep each topic on its own page; link to the deeper engineering references above where implementation detail is needed.

Start with:
- [Quick Start](../wiki/Quick-Start.md)
- [Controls and Profiles](../wiki/Controls-and-Profiles.md)
- [Troubleshooting](../wiki/Troubleshooting.md)

## Where to start

- New contributor: [DEVELOPMENT.md](DEVELOPMENT.md) and [ARCHITECTURE.md](ARCHITECTURE.md).
- UI work: [STYLEGUIDE.md](STYLEGUIDE.md), [SCREENS.md](SCREENS.md) and [TESTING.md](TESTING.md).
- Input work: [CONTROLLER.md](CONTROLLER.md) and [HOTKEYS.md](HOTKEYS.md).
- Packaging/release work: [RELEASE.md](RELEASE.md) and [FULL_PROJECT_AUDIT.md](FULL_PROJECT_AUDIT.md).
