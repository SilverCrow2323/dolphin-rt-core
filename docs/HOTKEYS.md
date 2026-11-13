# Hotkeys

Dolphin Rt:UI supports two hotkey paths. The active path is selected by
`[Hotkeys1] Device` in the chosen profile's `Hotkeys.ini`.

## Keyboard mode (bundled Default)

The bundled profile uses:

```ini
[Hotkeys1]
Device = Keyboard
```

In this mode, Dolphin receives keyboard events. `gptokeyb2` adds keyboard
events from the handheld controller using
`workshop/hotkeys/Default/ext-dolphin.gptk`. SELECT is the modifier:

| Handheld combo | Action |
|---|---|
| SELECT + L1 | Save State 1 (F1) |
| SELECT + R1 | Load State 1 (F2) |
| SELECT + L2 | Save State 2 (F3) |
| SELECT + R2 | Load State 2 (F4) |
| SELECT + A | Save State 3 (F5) |
| SELECT + B | Load State 3 (F6) |
| SELECT + D-pad Up | Toggle Pause (F7) |
| SELECT + D-pad Down | Fast Forward (F8) |
| SELECT + D-pad Left | Frame Limit − (F9) |
| SELECT + D-pad Right | Frame Limit + (F10) |
| SELECT + X | Screenshot (F11) |
| SELECT + Y | Reset (F12) |
| SELECT + MENU / GUIDE | Exit (Escape) |

Unmodified 1 / 2 / 3 select the active save-state slot. The gptokeyb2
mapping documents SDL tokens including L3 and R3; the editor converts
captured logical buttons to the corresponding lowercase tokens.

The launcher starts `gptokeyb2` only when `[Hotkeys1] Device = Keyboard`.

## Native SDL pad mode

For direct Dolphin controller hotkeys, the profile uses the built-in muOS
Andromeda device:

```ini
[Hotkeys1]
Device = SDL/0/muOS-Keys
Keys/Save State Slot 1 = `Button 11`
```

The Hotkey Designer in `ui/screens/hotkeys.lua` writes Dolphin button
expressions from `core/app_input.lua`'s muOS Andromeda map. H700 indices:

| SDL index | Key |
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
| 10 | Volume Up (not a hotkey button in the app map) |
| 11 | L3 |
| 12 | R2 |

In native SDL mode, the launcher does **not** start `gptokeyb2`; Dolphin
handles the bindings directly. This prevents keyboard-injection hotkeys
from running alongside native SDL hotkeys. The D-pad is delivered as a hat
(`Pad N/S/W/E`), not as a numbered button; the current native pad designer
does not serialize hat directions into `Button N` expressions.

## Safe exit

The muOS overlay exit watcher independently detects START + SELECT and
terminates Dolphin. It is a safety path outside `Hotkeys.ini`; do not
confuse it with the keyboard-profile Exit binding (SELECT + MENU / GUIDE).

## Editing

1. Open the Hotkeys editor and select a profile.
2. Choose Keyboard or Pad with L1/R1.
3. In Pad mode, press A on an action and then press the desired button combo.
4. Hold the combo briefly to commit; the editor warns about unsupported
   D-pad or unmapped inputs.
5. Press START to save. B returns to the profile list; unsaved changes prompt
   before leaving.
