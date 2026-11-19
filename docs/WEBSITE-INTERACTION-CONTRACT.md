# Website interaction contract

This is the implementation reference for the public portal's Compatibility, GameSettings and Profile Lab interactions.

## Compatibility detail sheets

- A game detail sheet closes through its close controls, backdrop or Escape.
- Nested GameSettings and report dialogs close independently. Escape closes only the topmost open dialog.
- The read-only INI inspector is layered above the GameSettings modal: its first Escape closes only the inspector; a second Escape closes the parent GameSettings modal.
- Scroll locking remains active while any underlying dialog is open.
- Reopening during an exit animation cancels the stale close timer.

## GameSettings source boundary

- Compatibility reports and GameSettings are separate sources.
- The public INI archive shows actual Dolphin INIs and user-facing workshop presets only.
- `rtgameset_data.ini` is internal Rt:UI metadata, not a GameSettings preset. It must never appear as a selectable, inspectable or downloadable entry in the public archive.
- Preserve canonical workshop metadata internally; filter it from public index and presentation. Never treat it as a Dolphin configuration.
- Respect Dolphin's `[Video_Hacks]` section naming.

## Profile Lab

- `data/site-profiles.json` is the catalogue source; all tracked records remain discoverable under All categories.
- Category colors: Performance (amber), Balanced (cyan), Compatibility (yellow), Accuracy (lime), Experimental (pink), Baseline (violet).
- Every profile card opens a dossier with description, type, focus, family, lock state, source folder and source-file links.
- Dossiers describe tracked source; they do not claim universal optimal settings.

## Settings inspector

- Each public GameSettings row has a read-only in-page inspector showing exact raw INI text from its tracked source.
- Never rewrite or upload the file from the inspector. Preserve Source and Raw links as fallbacks.

## Documentation organization

Use `docs/README.md` as the engineering index, `wiki/_Sidebar.md` as practical wiki navigation and `docs.html` as the searchable public reading interface. Keep user procedures in the wiki and implementation contracts in `docs/`.
