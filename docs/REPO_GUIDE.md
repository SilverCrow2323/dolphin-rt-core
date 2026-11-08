# Repository engineering guide

This page is the entry point for repository-wide development conventions. The frontend-specific reference index remains in [README.md](README.md).

- [Project map](PROJECT_MAP.md)
- [Development setup](DEVELOPMENT.md)
- [Screenshot workflow](SCREENSHOTS.md)
- [Visual asset inventory](ASSETS.md)
- [Quality gates](QUALITY.md)
- [Release checklist](RELEASE.md)

## Tools

- `bash tools/capture-ui.sh`: batch or single-screen LÖVE screenshots using the existing opt-in devshot hook.
- `tools/asset_inventory.py`: JSON/CSV asset manifest, SHA-256 hashes and optional contact sheet.
- `bash tools/publish-wiki.sh`: publish the tracked `wiki/*.md` source pages to the GitHub Wiki after explicit local authentication.

The GitHub Wiki is a separate Git repository. The script intentionally requires an authenticated local Git/GitHub CLI session and does not store tokens in this repository.
