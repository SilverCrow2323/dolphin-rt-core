# ui/ — frontend Dolphin Rt:Core K (in arrivo / planned)
Qui andrà il frontend LÖVE per Knulli (profili, controller, hotkeys, graphic mods, texture, cheats).
Il frontend originale per muOS è in `../legacy-muos/DolphinRtUI-muos/` come riferimento.
Per ora le opzioni per gioco sono nel menu di EmulationStation (vedi README principale).


# Dolphin Rt:Core K — GUI specification

**Status: planned; not shipped in the current port candidate.**

The GUI is a first-class application, separate from the two EmulationStation game systems.

## KNULLI placement

- Register one launcher script in `/userdata/roms/tools/`, so it appears under the native **Tools** category.
- Keep executable/UI data inside the Rt:Core installation directory; do not scatter support files through the visible Tools list.
- The GUI must be removable without deleting ROMs, memory cards, Wii NAND, save states, per-game settings or profiles.

## Page model

1. **HOME** — detected firmware/device, installed core version, build identity and quick health.
2. **GAMECUBE** — library list, selected game, profile and last-run status.
3. **WII** — library list, selected game, controller orientation and profile.
4. **GAME SETTINGS** — the selected game's options, using the same identifiers and values in `../config/options.tsv`.
5. **PROFILES** — select and inspect Rt:Core performance/compatibility profiles.
6. **CONTROLS** — pad layout, Wii Remote orientation and Safe Exit mapping.
7. **DIAGNOSTICS** — binary architecture, required Sys assets, launcher log and storage state.

The settings page mirrors the five Advanced Game Settings groups (Game, Controls, Graphics, Performance and Audio). It reads and writes the same per-game keys used by EmulationStation in `/userdata/system/batocera.conf`; there must be one source of truth, not a second private settings database.

## Input and safety

- D-pad/left stick moves focus; A confirms; B backs out; shoulders switch top-level pages where useful.
- Never run a ROM while a settings write is in progress.
- Write configuration atomically, preserve unrelated lines and keep a backup before the first mutation.
- The GUI and EmulationStation must display each other's changes after a refresh.
- Scanning the library is read-only. No game, shell script or user content is executed by the scanner.
- GUI availability is gated on the actual runtime and device adapter; it must not appear as installable until the frontend can launch on the target firmware.
