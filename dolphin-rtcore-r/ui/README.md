# Dolphin Rt:UI — ROCKNIX handheld frontend

 > **Alpha implementation · experimental**

Dolphin Rt:UI is a controller-first LÖVE application installed separately from the GAMECUBE and WII library entries. The installer exposes **one launcher** in ROCKNIX **Ports**:

`/storage/roms/ports/Dolphin RtCore GUI.sh`

A regular app launcher belongs in Ports; ROCKNIX Tools is for system modules. The application and support files remain in the Rt:Core installation folder. It uses the shared **PortMaster LÖVE 11.5 runtime**; the runtime is not bundled with Rt:Core.

## Pages

1. **HOME** — GAMECUBE, WII and SYSTEM DIAGNOSTICS.
2. **GAMECUBE** — discover the local GameCube library and choose a title.
3. **WII** — discover the local Wii library and choose a title.
4. **ADVANCED GAME SETTINGS** — the selected title's GAME, CONTROLS, GRAPHICS, PERFORMANCE and AUDIO options, plus ROCKNIX's SYSTEM / WINDOW PLATFORM selector.
5. **SYSTEM DIAGNOSTICS** — platform, ROM root, configuration path and option-catalog summary.

The GUI reads `config/options.tsv`, the same catalog used by the EmulationStation Advanced Game Settings generator and the Rt:Core launcher. It writes the same per-game keys in `/storage/.config/system/configs/system.cfg`.

## Controls

- D-pad: move through pages and options.
- **A**: open a page or advance the selected setting.
- **B**: go back.
- **Left / Right**: change the selected value.
- **L1 / R1**: switch settings group.
- **X**: clear the selected per-game override and return to the system/global/profile value.
- **Y**: rescan the current library.

## Safety and configuration

- Discovery only lists supported ROM file types: ISO, GCM, RVZ, WBFS, WIA, GCZ and CISO. It does not execute ROMs or shell scripts.
- Settings are written to `/storage/.config/system/configs/system.cfg`, preserving unrelated entries.
- Before the first GUI change, the app keeps a copy at `system.cfg.rtcore.bak`.
- Writes use a temporary file and same-filesystem rename.
- **EmulationStation remains the game launcher.** Rt:UI edits settings and browses titles; it does not replace the GAMECUBE/WII systems.

## Requirements and current limits

- ROCKNIX with PortMaster and its shared LÖVE 11.5 runtime installed.
- The matching Rt:Core R Wayland build and `core/Sys`.
- ROMs in `/storage/roms/gamecube` and `/storage/roms/wii`.

This is an initial experimental GUI. It does not yet edit performance profiles, controller maps or cheats, and it does not launch games itself. The new ROCKNIX Wayland binary and GUI still require physical-device qualification; source/CI checks alone cannot confirm a game launch works on every ROCKNIX device.
