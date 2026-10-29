# Controller profiles

## 1. Layout

Profiles live under:

```
workshop/controller/GameCube/<Name>/GCPadNew.ini
workshop/controller/Wii/<Name>/WiimoteNew.ini
```

At launch, `profile_manager.apply("controller", name)` copies the
relevant INI into `Config/GCPadNew.ini` or `Config/WiimoteNew.ini`.

## 2. Bundled profiles

### GameCube

| Name | Notes |
|---|---|
| Default | muOS SDL standard |
| FPS | Inverted Y, tight dead zone |
| Fighting | Arcade layout, 5% dead zone |
| Inverted | Y-axis inverted both sticks |
| Platformer | X/Y swapped |
| Z_L3 | Z mapped to L3 only |

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

Device is `SDL/0/muOS-Keys` for the built-in controller. External
controllers show up as `SDL/1`, `SDL/2`, etc.

## 4. Button numbering (muOS SDL)

| SDL index | Label |
|---|---|
| 0 | B |
| 1 | A |
| 2 | X |
| 3 | Y |
| 4 | L1 |
| 5 | R1 |
| 6 | SELECT |
| 7 | START |
| 8 | MENU |
| 9 | L2 (analog) |
| 10 | volume up |
| 11 | Z (L3) |
| 12 | R2 (analog) |

The mapping from raw button index to logical label lives in
`input_map.lua` (`S.raw_to_logical`). Never hardcode indices
outside `input_map.lua`.

## 5. Dead zones

Default dead zone is 15%. Fighting uses 5%, FPS uses 10%. Dead
zone is written to `Main Stick/Dead Zone` and `C-Stick/Dead Zone`
(Nunchuk equivalent for Wii).

## 6. Calibration

Every profile writes `Calibration = 100.00 ...` (8 values, all
100). This is the neutral calibration; adjust per-device only if
the sticks don't reach full deflection.
