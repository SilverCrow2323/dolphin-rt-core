# Dolphin Rt:UI 3.4 "Triage" — Flavour III of Dolphin Rt:Core

Controller-first frontend for Dolphin on muOS (RG35XX H, 640x480, 1 GB RAM).
Full description, screenshots and install guide: see the Flavour III README
shipped with the release (`README_Flavour_III_FrontendONE.md`).

## Screens
Home · Library · Game options · Cheats & Boost · Cheat DB · Mod Vault · Hotkeys ·
Controller map · Rt:Profiles / Editor · GameSettings · Compatibility list ·
Settings · Diagnostics · **Rt:Core Env Triage** · About.

## Controls
D-pad move (hold to scroll) · A select/play · B back · X options · Y favourite ·
L1/R1 filter or tab · L2/R2 letter jump · START settings · START+SELECT quit · MENU system drawer.

## Layout
- `ui/` — design system (`kit.lua`), navigation (`init.lua`), screens.
- `core/` — launcher, library, settings, cheats, covers, triage.
- `scripts/` — `launch.sh`, `rtcheats_sync.sh`, `overlay_exit.sh`.
- `workshop/` — profiles, controllers, hotkeys, game cards (your data).
- Logs: `data/logs/ui.log`, `data/logs/triage_report.txt`, launch logs.

## Environment
`DOLPHINUI_FPS=30` caps the UI · `DOLPHINUI_TRIAGE_ROOT=<dir>` fake muOS tree for the triage ·
`DOLPHINUI_SHOT=out.png:2.5` headless screenshot (dev).
