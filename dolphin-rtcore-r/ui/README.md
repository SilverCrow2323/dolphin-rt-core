# Dolphin Rt:Core R — GUI specification

**Status: planned; not shipped in the current port candidate.**

The Rt:Core GUI is a separate handheld application. It does not replace the dedicated GAMECUBE and WII EmulationStation systems.

## ROCKNIX placement

- Install one visible launcher `.sh` under `/storage/roms/ports/`.
- Do not place an ordinary user application in ROCKNIX Tools: the Tools system is reserved for system modules.
- Keep GUI resources in the Rt:Core installation's private data directory, not as visible loose files in Ports.

## Pages

1. **HOME / DIAGNOSTICS** — firmware, device, Dolphin build, Wayland/runtime health and logs.
2. **GAMECUBE** — discovered GameCube games, per-game profile and status.
3. **WII** — discovered Wii games, per-game profile and controller orientation.
4. **GAME SETTINGS** — the five shared groups (Game, Controls, Graphics, Performance, Audio) plus the ROCKNIX-only Window Platform selector.
5. **PROFILES** — inspect/select profiles and explain their performance/compatibility trade-offs.
6. **CONTROLS** — controller layout, Wii Remote orientation, Safe Exit and detected input device.

## Shared settings contract

`config/options.tsv` is the catalog for both the GUI and the EmulationStation Advanced Game Settings menu. The GUI reads/writes the same keys in `/storage/.config/system/configs/system.cfg`; *Profile default* means the setting is absent and the selected profile retains control.

Configuration edits must be atomic, preserve unrelated system settings, and create a backup before mutation. Library scanning remains read-only; scripts and ROMs are never executed during discovery.

The GUI must not register its Ports launcher until a working runtime/frontend has been packaged and smoke-tested on the target. A placeholder menu item is not a delivered feature.
