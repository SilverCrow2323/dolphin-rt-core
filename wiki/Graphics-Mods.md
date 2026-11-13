# Dolphin Graphics Mods and GameSettings

This page explains which Dolphin system resources must stay installed and how Rt:UI manages graphics mods safely.

## Keep the official Dolphin resources

Do **not** remove these directories as a cleanup shortcut:

| Path | Role | Policy |
|---|---|---|
| `Sys/GameSettings/` | Official per-title Dolphin INI defaults | Keep intact |
| `Config/GameSettings/` | User-specific GameSettings overrides | Keep user content |
| `Sys/Load/GraphicMods/` | Built-in Dolphin Graphics Mods | Keep intact |
| `Load/GraphicMods/` | User-installed Graphics Mods | Keep user content |
| `Config/GraphicMods/<GameID>.json` | Per-game enabled state for Graphics Mods | Managed by Dolphin / Rt:UI |

Dolphin combines its system-provided resources with the user configuration. Rt:Core must not delete or rewrite the upstream `Sys` tree during routine maintenance.

## “All Games” means compatible with all games

A graphics mod folder such as `All Games Bloom Removal` contains an `all.txt` marker. Dolphin treats that marker as a match for each game's graphics-mod catalog.

It does **not** mean the mod should be enabled globally.

Every mod starts disabled until selected for a particular Game ID. This is deliberate: two global graphics mods may change the same rendering feature and should not be forced on together.

Dolphin's per-game profile is stored at:

```text
Config/GraphicMods/<GameID>.json
```

A profile entry records the source (`system` or `user`), the relative path to the mod's actual `metadata.json` file, its `enabled` state and Dolphin's other per-mod settings. The metadata path is not just the enclosing directory name; nested metadata files retain their full relative path. The emulator still discovers the metadata and assets in their original directory; Rt:UI only updates the per-game profile.

## Rt:UI Mod Vault

Open a game's options and enter **Mod Vault**. Use the **Graphics Mods** tab to browse the official system catalog and user mods that match that game's Game ID.

Matching follows Dolphin's lookup rules:

1. A direct folder named with the full Game ID is preferred.
2. A direct three-character region-free folder is used when the full-ID folder does not exist.
3. Nested marker files named `<GameID>.txt`, `<prefix>.txt` or `all.txt` can add further matching directories. Dolphin then scans every `metadata.json` below each selected directory, so a marker folder can contain multiple nested mod definitions.

| Control | Action |
|---|---|
| **A** | Toggle selected mod for this game |
| **X** | Enable all matching mods for this game |
| **Y** | Disable all matching mods for this game |
| **L1 / R1** | Switch Mod Vault category |
| **B** | Return |

The home/catalog view is read-only; per-game enablement requires a selected game.

## Launch behaviour

Before Dolphin starts, Rt:UI checks the selected game's profile. It sets `GFX.ini → [Settings] EnableMods` to `True` only when at least one entry in that game's profile is enabled. Otherwise it leaves the Graphics Mods engine disabled.

The launcher and catalog perform a one-time compatibility restore for folders left in `Load/GraphicMods.off`. User folders are returned to `Load/GraphicMods` only when the destination does not already exist.

On first use for a game, Rt:UI also migrates old RTID `[MODS] Selected` entries into Dolphin's native per-game profile. Only matching user mods are migrated; newly available built-in `Sys` mods remain disabled. If a Dolphin per-game profile already exists, it is never overwritten by the legacy migration.

## Related data: Rt:Core GameSettings

Do not confuse Dolphin's official `Sys/GameSettings/` INI files with Rt:Core's downloaded `data/gamesettings.json` database. Rt:Core uses the JSON database to populate its own presets and GameSettings browser. Both sources are useful and should be retained.

## Troubleshooting

- **No Graphics Mods appear:** confirm `Sys/Load/GraphicMods` and `Load/GraphicMods` exist and that each mod has a valid `metadata.json`.
- **A game-specific mod is missing:** confirm its marker file uses the exact Game ID or three-character prefix expected by Dolphin.
- **A mod is listed but inactive:** enable it for that game in Mod Vault and relaunch the title.
- **Changes appear global:** inspect the Game ID profile under `Config/GraphicMods/`; do not manually turn on every mod in `GFX.ini`.

Never delete `Sys/GameSettings` or `Sys/Load/GraphicMods` as a generic performance or cleanup fix.
