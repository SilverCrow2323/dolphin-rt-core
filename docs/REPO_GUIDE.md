# Repository engineering guide

This is the entry point for repository-wide development conventions. The frontend-specific reference index remains in [docs/README.md](README.md).

- [Project map](PROJECT_MAP.md)
- [Development setup](DEVELOPMENT.md)
- [Screenshot workflow](SCREENSHOTS.md)
- [Visual asset inventory](ASSETS.md)
- [Compatibility Database website](COMPATIBILITY_SITE.md)
- [Quality gates](QUALITY.md)
- [Release checklist](RELEASE.md)

## Tools

- `bash tools/capture-ui.sh`: single, batch or all-registered-screen LÖVE captures.
- `tools/asset_inventory.py`: JSON/CSV asset manifest, SHA-256 hashes and optional contact sheet.
- `bash tools/publish-wiki.sh`: publish tracked `wiki/*.md` source pages to GitHub Wiki after local authentication.

The GitHub Wiki is a separate Git repository. The publisher script requires an authenticated local Git/GitHub CLI session and does not store tokens in this repository.

The public compatibility web app is maintained in the root `index.html`; its source data remains in the current muOS frontend's tracked `data/games_data.json` and `data/gamesettings.json`. See [COMPATIBILITY_SITE.md](COMPATIBILITY_SITE.md) before changing data endpoints or publishing setup.
