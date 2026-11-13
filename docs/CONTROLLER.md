# Controller profiles

## Profile locations and application

Controller profiles are stored in:

```
workshop/controller/GameCube/<Name>/GCPadNew.ini
workshop/controller/Wii/<Name>/WiimoteNew.ini
```

The Controller Profiles screen selects the system and profile, then opens
the active editor in `ui/screens/controller_map.lua`. The editor writes
the selected Dolphin INI. At game launch, `scripts/launch.sh` copies the
selected profile into `Config/GCPadNew.ini` or `Config/WiimoteNew.ini`
(falling back to the bundled Default profile and then `workshop/base`).

## H700 / muOS Andromeda built-in pad

For the H700 built-in controller, the Dolphin device is:

```ini
Device = SDL/0/muOS-Keys
```

The current Andromeda SDL button indices used by H700 profiles are:

| SDL index | Physical / logical key |
|---:|---|
| 0 | B |
| 1 | A |
| 2 | X |
| 3 | Y |
| 4 | L1 |
| 5 | R1 |
| 6 | SELECT |
| 7 | START |
| 8 | MENU / GUIDE |
| 9 | L2 |
| 10 | Volume Up |
| 11 | L3 (left-stick click; GameCube Z) |
| 12 | R2 |

Do not shift or reverse the face-button indices: A is 1 and B is 0.
The D-pad is represented by Dolphin's `Pad N/S/W/E` tokens and analog
directions by `Left X/Y` and `Right X/Y` axes.

## Default mappings

### GameCube

```ini
Buttons/A = `Button 1`
Buttons/B = `Button 0`
Buttons/X = `Button 2`
Buttons/Y = `Button 3`
Buttons/Z = `Button 11`
Buttons/Start = `Button 7`
Triggers/L = `Button 4`
Triggers/L-Analog = `Button 9`
Triggers/R = `Button 5`
Triggers/R-Analog = `Button 12`
```

### Wii Remote + Nunchuk

```ini
Buttons/A = `Button 1`
Buttons/B = `Button 0`
Buttons/1 = `Button 2`
Buttons/2 = `Button 3`
Buttons/+ = `Button 7`
Buttons/- = `Button 6`
Buttons/Home = `Button 8`
Nunchuk/Buttons/C = `Button 4`
Nunchuk/Buttons/Z = `Button 5`
```

Nunchuk C and Z therefore use L1 and R1, not the analog triggers L2/R2.
The Wii D-pad uses `Pad N/S/W/E`.

## Other handhelds and stick-count variants

`RtSys/apply_profile.sh` reads the muOS board/stick variable and selects
the matching `.0joy`, `.1joy` or `.2joy` baseline. These are
device-specific fallbacks. Do not copy the H700 two-stick indices into
every variant without checking that device's SDL layout. For H700 two-stick
profiles, use the mapping table above.

## Input implementation

- `core/app_input.lua` owns the logical frontend-pad-to-raw-button map,
  including L3 at index 11.
- `ui/input.lua` translates raw LÖVE button events into logical names.
- `ui/screens/controller_map.lua` edits Dolphin's GCPad/Wiimote INIs and
  recognizes the SDL `leftstick` event as Andromeda Button 11 / L3.
