# Website interaction contract

This is the implementation reference for the public portal's Compatibility, GameSettings and Profile Lab interactions.

## Compatibility detail sheets

- A game detail sheet closes through its close controls, backdrop or Escape.
- Nested GameSettings and report dialogs close independently. Escape closes only the topmost open dialog.
- Scroll locking must remain active while any underlying dialog remains open.
- Reopening a dialog during its exit animation cancels the stale close timer.

## GameSettings source boundary

- Compatibility reports and GameSettings are separate data sources.
- The public INI archive shows actual Dolphin INIs and user-facing workshop presets only.
- `rtgameset_data.ini` is internal Rt:UI metadata, not a GameSettings preset. It must never appear as a downloadable, inspectable or selectable INI entry in the public archive.
- Preserve canonical workshop metadata internally; filter it from the public index and presentation. Do not rename it or treat it as a Dolphin configuration.
- Respect Dolphin's `[Video_Hacks]` GameSettings section naming.

## Profile Lab

- `data/site-profiles.json` is the catalogue source. Every tracked record must be discoverable under **All categories**.
- Category colors: Performance (amber), Balanced (cyan), Compatibility (yellow), Accuracy (green), Experimental (pink), Baseline (violet).
- Every profile card opens a dossier with description, type, focus, family, lock state, source folder and source-file links.
- Dossiers describe tracked source; they do not claim universal optimal settings.

## Settings inspector

- Every public GameSettings row has an in-page, read-only inspector.
- Show exact raw INI text from the tracked raw source. Never rewrite or upload the file.
- Keep View and Raw source links as fallbacks.

## Documentation organization

Use `docs/README.md` as the engineering index, `wiki/_Sidebar.md` as practical wiki navigation and `docs.html` as the searchable reading interface. Keep user procedures in the wiki and implementation contracts in `docs/`.
