# Contributing

Thanks for helping! The project is small on purpose: Python (PC), Lua/LÖVE (handheld), a little POSIX shell.

## Workflow
1. Fork, create a branch, make your change.
2. `make lint test` must pass (see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for the one-time setup).
3. UI changes: attach a screenshot (the recipe is in the development guide). For handheld UI changes, please include a
   screenshot in both windowed (desktop LÖVE) and fullscreen (RG35XX H if you have one) modes — the two layouts are
   tuned for the 3.5" screen and things that look fine on a monitor can feel cramped on the real device.
4. Open a pull request. Describe what you verified on real hardware and what you could only test headless.

## Ground rules
- English UI and English docs. Menu labels, guide text, tool descriptions and diagnostics output are all in English.
  Handheld menu labels are UPPERCASE for section titles (`STREAMING`, `INTERFACE`, `TOOLS`) and Title Case for items.
- No ROMs, BIOS files, firmware, or game cover art in the repository (demo covers are generated).
- Anything that writes Dolphin config goes through `pc/portal/profiles.py` and its validation. New remote operations
  need a unit test in `tests/test_server.py` that proves bad input is rejected.
- Keep shell scripts POSIX (`sh`), the handheld ships busybox.
- Profiles: new `muos-*` profiles must pass `tests/test_profiles.py` (no duplicate keys, hotkeys on the MODE layer).

## Handheld app conventions
- Every menu item that can be selected must define `icon = "..."` (see `gui/ui.lua` for the icon set) and `desc = "..."`.
  Items that expose selectable values (`t = "ch"`) should also define `guide = { intro = "...", values = { ... } }` so
  the **M** guide panel has something useful to show.
- Colors are declared once in `UI_COLORS` inside `gui/main.lua` and looked up by item type (`quick`, `act`, `ch`, `tg`,
  `txt`, `sub`). Do not hardcode colors per item unless the item needs a visual identity (e.g. Search is cyan, Sync is
  yellow).
- Overlays (`openXxxOverlay`) receive a `color` and an `intro` string; the layout fits up to 6 items per overlay without
  scrolling. If you add a 7th, split it into two overlays.
- Every bugfix to the menu/overlay/guide system must be verified with `luac -p gui/main.lua` before the PR. The CI job
  checks this, but the handheld build also runs `luac -p` on the packaged tree.