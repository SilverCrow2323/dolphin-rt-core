# Hotkeys

Dolphin Rt:Core builds against Dolphin **2606**. Its hotkey file uses the
current `[Hotkeys]` section and grouped action names; the old `[Hotkeys1]`,
`Keys/...` layout is not the format used by this build.

## Keyboard / gptokeyb2 profile

The bundled `workshop/hotkeys/Default/Hotkeys.ini` uses SDL's virtual keyboard:

```ini
[Hotkeys]
Device = SDL/0/Keyboard Mouse
Save State/Save State Slot 1 = F1
Load State/Load State Slot 1 = F2
General/Toggle Pause = F7
General/Exit = Escape
```

`gptokeyb2` is started by `scripts/launch.sh` and reads the matching
`ext-dolphin.gptk` file. The default modifier is **SELECT**; individual
SELECT + button combinations emit F-keys to Dolphin. The normal gamepad
device remains assigned to gameplay.

The exit combination is **SELECT + START**. `overlay_exit.sh` remains a
separate safety net that terminates Dolphin from the raw muOS joystick event
stream; it does not replace the Dolphin hotkey configuration.

## PAD (SDL) profile

The designer can also write direct SDL button expressions. In PAD mode the
hotkey device is `SDL/0/muOS-Keys`, and expressions use the button indices
from the active Rt:UI app-pad map, for example:

```ini
[Hotkeys]
Device = SDL/0/muOS-Keys
General/Exit = (`Button 6` & `Button 7`)
```

## Older profiles

The designer still reads the previous `[Hotkeys1]` / `Keys/...` layout and
translates its known actions when loading a profile. Saving writes the
current Dolphin 2606 format. Profiles with custom action names not present in
the current Dolphin build are ignored by Dolphin and should be rebound in
the designer.
