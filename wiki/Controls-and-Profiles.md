# Controls and Profiles

This page explains the bundled GameCube/Wii controller profiles and the boundaries of the muOS SDL input map.

## In breve

- Use a GameCube profile for GameCube games.
- Use a Wii profile for Wiimote/Nunchuk or Classic Controller emulation.
- Start with **Default** before applying a specialised profile.
- Treat the built-in muOS controller mapping separately from external controllers.

> [!IMPORTANT]
> **MUST KNOW!!** The numeric SDL labels in this guide describe the built-in `SDL/0/muOS-Keys` device in the documented muOS setup. External controllers can appear as `SDL/1`, `SDL/2` and use different button identities. Do not assume the same physical mapping.

## GameCube controller profiles

| Profile | Intended use |
|---|---|
| Default | muOS SDL standard mapping |
| FPS | Inverted Y and tighter dead zone |
| Fighting | Arcade-style layout and 5% dead zone |
| Inverted | Inverted Y axis on both sticks |
| Platformer | X/Y swapped |
| Z_L3 | Z mapped to L3 |

## Wii controller profiles

| Profile | Intended use |
|---|---|
| Default | Standard Wiimote + Nunchuk |
| Classic | Emulated Classic Controller |
| FPS | Inverted IR and tighter dead zone |
| MotionPlus | Enhanced motion |
| Nunchuk | Nunchuk-primary |
| NoNunchuk | Wiimote only |

## Rt:Core performance and accuracy profiles

| Family | Focus | Tiers |
|---|---|---|
| Rt:Boost | Performance-first | Lite / Std / Max |
| Rt:Prime | Balanced | Lite / Std / Max |
| Rt:Pure | Accuracy | Lite / Std / Max |
| Rt:Verbose | Diagnostic logging | — |

Start from **Default** or the balanced Rt:Prime family when unsure. Results still depend on the exact game, region, firmware and handheld.

## Editing and rollback

- Family profiles are locked and should not be overwritten.
- Save custom changes as a new profile.
- The launch flow backs up the previous live INI files under `Config/.backup_<timestamp>/`.
- Change one setting at a time and record the game ID and result.

> **Optional** — Use the profile diff viewer to compare a custom profile against its base.

## Game-specific settings

GameSettings use Dolphin's game-specific section names. For video hacks, use `[Video_Hacks]`; a `[Hacks]` section in a GameSettings file is ignored by Dolphin.

## Developer reference

See [Controller profiles](https://github.com/SilverCrow2323/dolphin-rt-core/blob/main/docs/CONTROLLER.md) and [Rt:Core profiles](https://github.com/SilverCrow2323/dolphin-rt-core/blob/main/docs/PROFILES.md) for exact file names, SDL index handling and implementation details.
