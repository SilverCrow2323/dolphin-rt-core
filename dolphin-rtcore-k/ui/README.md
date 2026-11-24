# Dolphin Rt:UI — KNULLI handheld frontend

 > **Alpha implementation · source included in the candidate package**

Dolphin Rt:UI is a controller-first LÖVE application installed separately from the GAMECUBE and WII library entries. The installer exposes **one launcher** in the native KNULLI **Tools** category:

`/userdata/roms/tools/Dolphin RtCore GUI.sh`

The application and its support files remain in the Rt:Core installation folder. It uses the shared **PortMaster LÖVE 11.5 runtime**; the runtime itself is not copied into the Dolphin package.

## Pages

1. **HOME** — GAMECUBE, WII and SYSTEM DIAGNOSTICS.
2. **GAMECUBE** — discover the local GameCube library and choose a title.
3. **WII** — discover the local Wii library and choose a title.
4. **ADVANCED GAME SETTINGS** — the selected title's GAME, CONTROLS, GRAPHICS, PERFORMANCE and AUDIO options.
5. **SYSTEM DIAGNOSTICS** — platform, ROM root, configuration path and option-catalog summary.

The GUI reads `config/options.tsv`, the same catalog used to generate EmulationStation's Advanced Game Settings. It writes the same per-game `batocera.conf` keys as EmulationStation and the Rt:Core launcher. Changing an option in one interface is therefore visible in the other after refresh.

## Controls

- D-pad: move through pages and options.
- **A**: open a page or advance the selected setting.
- **B**: go back.
- **Left / Right**: change the selected value.
- **L1 / R1**: switch settings group.
- **X**: clear the selected per-game override and return to the system/global/profile value.
- **Y**: rescan the current library.

## Safety and configuration

- The library scanner only lists supported ROM file types: ISO, GCM, RVZ, WBFS, WIA, GCZ and CISO. It never runs ROMs or shell scripts during discovery.
- Settings are written to `/userdata/system/batocera.conf`, preserving unrelated entries.
- Before the first GUI change, the app keeps a copy at `batocera.conf.rtcore.bak`.
- Writes use a temporary file and same-filesystem rename.
- **EmulationStation remains the game launcher.** Rt:UI edits settings and browses titles; selecting a title opens its settings page rather than launching the game.

## Requirements and current limits

- KNULLI with the PortMaster shared LÖVE 11.5 runtime installed.
- Rt:Core K already installed with its matching Dolphin binary and `core/Sys`.
- ROMs in `/userdata/roms/gamecube` and `/userdata/roms/wii`.

This is an initial GUI implementation. It does not yet edit Rt:Core performance profiles, controller maps or cheats, and it does not launch games itself. CI/source checks are not a substitute for testing the GUI on a physical KNULLI handheld.
