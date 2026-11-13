# Controller profiles

## 1. Profile files

Profiles live under:

```
workshop/controller/GameCube/<Name>/GCPadNew.ini
workshop/controller/Wii/<Name>/WiimoteNew.ini
```

At launch, the selected profile is copied into `Config/GCPadNew.ini` or `Config/WiimoteNew.ini`.

## 2. Bundled profiles

### GameCube

| Name | Notes |
|---|---|
| Default | muOS SDL standard |
| FPS | Inverted Y, tight dead zone |
| Fighting | Arcade layout, 5% dead zone |
| Inverted | Y-axis inverted on both sticks |
| Platformer | X/Y swapped |
| Z_L3 | Maps GameCube Z to the L3 hardware button |

### Wii

| Name | Notes |
|---|---|
| Default | Standard Wiimote + Nunchuk |
| Classic | Emulated Classic Controller |
| FPS | Inverted IR, tight dead zone |
| MotionPlus | Enhanced motion |
| Nunchuk | Nunchuk-primary |
| NoNunchuk | Wiimote only |

## 3. Device naming

The built-in controller is exposed to Dolphin as `SDL/0/muOS-Keys`. External controllers appear as separate SDL devices; the number can change when devices are connected or removed.

## 4. Dolphin SDL button numbering

The bundled profiles use zero-based `Button n` tokens:

| SDL token | Hardware meaning |
|---:|---|
| 0 | B |
| 1 | A |
| 2 | X |
| 3 | Y |
| 4 | L1 |
| 5 | R1 |
| 6 | SELECT |
| 7 | START |
| 8 | MENU |
| 9 | L2 (analogue trigger) |
| 10 | Volume + |
| 11 | L3 (also used for GameCube Z in the default profile) |
| 12 | R2 (analogue trigger) |

The default GameCube and Wii INIs are the source of truth for their individual control assignments. The RtUI numeric input map uses the same SDL button IDs; the standardized gamepad path uses SDL names.

**Do not confuse this table with Linux EV_KEY codes or `/dev/input/js1` joydev indices.** Those are separate interfaces with different numbering. See [Controller input reference](CONTROLLER_INPUT.md) for the Jacaranda and Andromeda kernel maps, joydev values and the complete layer diagram.

## 5. Dead zones

Default dead zone is 15%. Fighting uses 5%, FPS uses 10%. Dead zone is written to `Main Stick/Dead Zone` and `C-Stick/Dead Zone` (Nunchuk equivalent for Wii).

## 6. Calibration

Every profile writes `Calibration = 100.00 ...` (8 values, all 100). This is the neutral calibration; adjust per-device only if the sticks do not reach full deflection.
