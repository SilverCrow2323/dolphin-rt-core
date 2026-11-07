# Controllers, profiles and hotkeys

## The idea

Moonlight turns the handheld's buttons into an **Xbox pad** and Sunshine exposes it on the PC as a virtual device named
`Sunshine (libvirtualhid) X-Box Series Controller`. Dolphin does not know "A" or "B" of the handheld, it only sees the
names of that virtual pad. A *profile* is the list `Dolphin control = virtual pad source`.

| Dolphin source | Xbox button / axis | Drawn as (Controls screen) |
|---|---|---|
| `SOUTH` / `EAST` / `WEST` / `NORTH` | A / B / X / Y | green / red / blue / yellow buttons |
| `TL` / `TR` | LB / RB | bumpers |
| `` `Full Axis 2+` `` / `` `Full Axis 5+` `` | LT / RT (analog) | triggers |
| `SELECT` / `START` / `MODE` | Back / Start / Guide | center buttons |
| `THUMBL` / `THUMBR` | left / right stick click | L / R |
| `` `Axis 0±` `` `` `Axis 1±` `` | left stick X / Y | L |
| `` `Axis 3±` `` `` `Axis 4±` `` | right stick X / Y | R |
| `` `Axis 6±` `` `` `Axis 7±` `` | D-pad X / Y (hat) | D-pad |

Which physical handheld button produces which Xbox button depends on the muOS / Moonlight mapping, **not** on this
project. That is why the face buttons of `muos` look unusual (`B = SELECT`): they were tuned by pressing the real
buttons. If yours feel mirrored, use `muos-xbox` or change the binding from the Controls screen.

## Packaged profiles

### GameCube pad
| Control | `muos` | `muos-xbox` |
|---|---|---|
| A | `SOUTH` | `SOUTH` |
| B | `SELECT` | `EAST` |
| X | `NORTH` | `WEST` |
| Y | `WEST` | `NORTH` |
| Z | `THUMBR` (R3) | `THUMBR` |
| Start | `START` | `START` |
| L / R (click) | `TL` / `TR` | `TL` / `TR` |
| L / R analog | LT / RT | LT / RT |
| Main stick / C-stick | left / right stick, dead zone 8 % | same |
| D-pad | hat | hat |

*Z used to share `SELECT` with B; it now sits on R3 so a Z press can no longer fire B.*

### Wii Remote
| Control | `muos` (sideways) | `muos-nunchuk` |
|---|---|---|
| 1 / 2 | `WEST` / `SOUTH` | `WEST` / `NORTH` |
| A | `NORTH` | `SOUTH` |
| B | `TL` | RT (`Full Axis 5+`) |
| − / + | `SELECT` / `START` | `SELECT` / `START` |
| Home | `TR` | `MODE` |
| D-pad | hat | hat |
| Pointer (IR) | – | right stick |
| Nunchuk stick / C / Z | – | left stick / `TL` / `TR` |
| Shake | – | Wiimote: `THUMBR`, Nunchuk: `THUMBL` |
| Options | sideways, always connected | always connected |

Use `muos` for 2D games (NSMB, Kirby, ...), `muos-nunchuk` for pointer/3D games (Zelda, Metroid Prime 3, Galaxy).
Switch per kind from the handheld (**Y** on the Controls screen) or the portal.

### Hotkeys
Everything is on the **MODE layer** (hold MODE, press a button), because `B` is mapped to `SELECT` in the GameCube
profile and no hotkey may fire from a bare gameplay button.

| Hotkey | `muos` | `muos-minimal` |
|---|---|---|
| Exit Dolphin (ends the stream) | `MODE + START` | `MODE + START` |
| Pause | `MODE + SELECT` | `MODE + SELECT` |
| Screenshot | `MODE + NORTH` | – |
| Save / load state, slot 1 | `MODE + TL` / `MODE + TR` | – |
| Undo load state | `MODE + WEST` | – |
| Volume up / down | `MODE + D-pad ▲` / `▼` | – |
| Mute | `MODE + THUMBL` | – |
| Emulation speed − / + | `MODE + D-pad ◀` / `▶` | – |
| No speed limit | `MODE + THUMBR` | – |

*Toggle Fullscreen* is **not** mapped on purpose: leaving fullscreen shows the PC desktop in your stream.
*Stop* is not mapped either: in batch mode (`-b`) Exit and Stop end the session the same way.

## Editing

### On the handheld — START ▸ Controls
- `L1 / R1` GameCube · Wii Remote · Hotkeys, `▲ ▼` choose a row, `◀ ▶` change the binding (the matching part of the
  drawn pad lights up), `Y` switch profile, `SELECT` reload from the PC, `B` back.
- Editable: face/shoulder/menu buttons (cycled through the 11 pad buttons) and every hotkey (`MODE +` button or D-pad).
- Read-only: sticks, D-pad axes, analog triggers, dead zones, booleans. Edit those on the PC.
- Edits are sent 0.6 s after your last change, validated on the PC and applied **at the next game launch**.
- Needs *PC host*, *Edit token* (START ▸ Streaming) and the library server running. The footer toast shows `OK ...` or `ERR ...`.

### In the portal — SYSTEM ▸ CONTROLLER PROFILES
Pick the active profile per kind, install, apply now (with backups), reset `muos*` to defaults, copy/rotate the token.

### CLI
```
spdw-stream profiles list                                  # all profiles, * = active
spdw-stream profiles show GCPad [muos]
spdw-stream profiles set GCPad muos Buttons/Z TL           # one binding (muos* only)
spdw-stream profiles active Hotkeys muos-minimal
spdw-stream profiles reset GCPad muos                      # back to the packaged copy
spdw-stream profiles apply [--backup]                      # write active profiles into Dolphin now
spdw-stream profiles export                                # profiles.tsv as the handheld sees it
spdw-stream token [show|new]
```

### By hand
Profiles are plain Dolphin profile files in `~/.config/dolphin-emu/Profiles/<Kind>/<name>.ini`
(Flatpak: `~/.var/app/org.DolphinEmu.dolphin-emu/config/dolphin-emu/...`). Edit them freely; `profiles apply` copies the
active one into `GCPadNew.ini` / `WiimoteNew.ini` / `Hotkeys.ini` (section 1) before each launch.

## Your own profile

1. Copy a packaged one: `cp pc/profiles/GCPad/muos.ini ~/.config/dolphin-emu/Profiles/GCPad/muos-mine.ini`
2. Keep the name starting with `muos` to make it editable from the handheld; any other name works but is read-only remotely.
3. `spdw-stream profiles active GCPad muos-mine`

To ship it with the project add the file under `pc/profiles/<Kind>/` — `tests/test_profiles.py` checks duplicate keys,
the `Device` line and (for hotkeys) the MODE layer.

## The `Device` line

`Device = evdev/0/Sunshine (libvirtualhid) X-Box Series Controller` assumes the virtual pad is device `0`. If Dolphin's
own controller dialog lists it as `evdev/1`, change the `Device` line of the profiles (the handheld editor never touches it).

## Dolphin key names

The key names (`General/Toggle Pause`, `Save State/Save State Slot 1`, `Nunchuk/Stick/Up`, ...) follow Dolphin 5/2xxx
profile files. Dolphin silently ignores keys it does not know, so a wrong name shows up as "nothing happens", never as an
error. If a hotkey does nothing on your build, open Dolphin's Hotkey dialog, bind it once, and compare the key name in
the saved profile.
