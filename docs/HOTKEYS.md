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


## H700 / muOS Andromeda controller indices

The H700 built-in pad is exposed as \`SDL/0/muOS-Keys\`. Rt:UI's canonical
logical input map is:

| SDL button | Control |
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
| 10 | Volume Up (not an Rt:UI hotkey action) |
| 11 | L3 (left-stick click) |
| 12 | R2 |

The Hotkey Designer uses the current Dolphin 2606 \`[Hotkeys]\` grouped
action format. In PAD mode, an L3 binding is serialized as \`Button 11\`.
The keyboard/gptokeyb2 path serializes the same physical control with the
\`l3\` token. The launcher keeps the two paths mutually exclusive: gptokeyb2
is only started for the virtual-keyboard profile, never on top of native SDL
pad hotkeys.

The D-pad is an SDL hat rather than a numbered button; the current native pad
designer reports hat directions as unbindable instead of writing a false
\`Button N\` mapping. START + SELECT remains the independent muOS Safe Exit
chord.
