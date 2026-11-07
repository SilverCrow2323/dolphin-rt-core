# Troubleshooting

First look at: portal **LOG** tab, handheld **START ▸ Tools ▸ Last stream log**, portal **SYSTEM** checklist, and
`spdw-stream status` on the PC.

## Black bars top and bottom
A 16:9 desktop is letterboxed on the 4:3 handheld.
- Portal ▸ SYSTEM ▸ DISPLAY ▸ *Stream display mode* must be a 4:3 mode (default `4:3 1280x960`). Press **APPLY TO SUNSHINE APPS**, restart Sunshine.
- Check the mode switch works: `sh /usr/lib/spdw-stream-portal/display-mode.sh set 1280x960; sh .../display-mode.sh status; sh .../display-mode.sh restore`
- The monitor refuses the mode → try `1024x768` or `800x600`.
- Wayland session → `xrandr` cannot switch modes; use an X11 session (or create a 4:3 virtual display yourself and use *Command before/after stream*).
- Wii games in 16:9 are letterboxed *inside* the 4:3 frame: that is their real aspect ratio.

## The PC desktop or panel is visible in the stream
- SYSTEM ▸ DISPLAY: *Dolphin fullscreen* and *Hide the XFCE panel* must be ticked, then APPLY + restart Sunshine.
- Check an app: `grep -A3 '"cmd"' ~/.config/sunshine/apps.json` must contain `Dolphin.Display.Fullscreen=True`.
- Dolphin was already running (a window from an earlier session) → close it; the `-b` batch run cannot take over a running instance.
- A hotkey toggled fullscreen: the packaged hotkeys never map *Toggle Fullscreen*; check you did not add one.

## Stuck in 4:3 or panel hidden after a crash
```
sh /usr/lib/spdw-stream-portal/display-mode.sh restore
sh /usr/lib/spdw-stream-portal/panel-hide.sh show
```
(portal ▸ SYSTEM ▸ RESTORE DISPLAY NOW does the first one).

## The stream does not start
- Handheld **START ▸ Tools ▸ Connection test**: ping, library server (`:8765`), Sunshine (`:47989`), pairing keys. Fix the first red line.
- Not paired → **Tools ▸ Pair with Sunshine**, enter the PIN in Sunshine's web UI (`https://<pc>:47990`, tab PIN).
- Sunshine app names changed after a rescan → restart Sunshine; names are `GC - <title>` / `Wii - <title>`.
- Failure toast after returning to the library: open **Last stream log**.
- Moonlight is slow to connect over Tailscale → set *Network mode* to `yes`.

## Sync shows `ERR: PC unreachable`
Library server stopped (portal ▸ SERVICES ▸ START), wrong host/port, firewall on `8765`, or the PC is asleep.

## Covers are missing
No internet on the PC, game ID not found on GameTDB, or the file name has no ID and the header could not be read.
Put `<rom name>.png` next to the ROM, or `<rom name>.png` in a `covers/` folder next to it, then SCAN NOW.

## Controller: nothing / wrong buttons in the game
1. Dolphin ▸ Controllers: is `evdev/0/Sunshine (libvirtualhid) X-Box Series Controller` listed? If it is `evdev/1`, adjust the `Device` line (see CONTROLS.md).
2. Portal ▸ SYSTEM: profiles installed? Press **APPLY NOW** with Dolphin closed.
3. Face buttons mirrored → switch GameCube pad to `muos-xbox` (Controls screen, `Y`), or change the binding there.
4. Wii game wants a nunchuk → Wii Remote profile `muos-nunchuk`.

## Controls screen says `ERR`
| Message | Meaning |
|---|---|
| `ERR token not set` | START ▸ Streaming ▸ Edit token |
| `ERR bad token` | token rotated on the PC; type the new one |
| `ERR PC unreachable` | server stopped / wrong host |
| `ERR only muos* profiles can be edited` | the active profile is one of your own files; edit it on the PC |
| `ERR unknown key` | the profile does not contain that key |

## The Controls screen is empty
It reads `conf/profiles.tsv`. Press **SELECT** inside Controls (or run a normal sync) while the server is running.

## Hotkeys do nothing
The hotkey profile is applied before each launch; test with `MODE + SELECT` (pause). If MODE (Guide) never reaches
Dolphin because muOS or Moonlight keeps it for itself, edit the Hotkeys profile on the PC and replace `MODE` with another
button you can spare (for example `THUMBL`), then open an issue telling us which handheld button reaches Dolphin as Guide.

## Boot animation too slow / unwanted
**START ▸ Interface ▸ Boot animation** off. Any button skips it. *Animations* off also turns off all motion; *Battery saver* caps the UI at ~30 fps.

## Handheld app crashes at start
Run it from a shell: `cd DolphinStream && ./love gui` and read the Lua error. Missing `gui/assets/` (font, logos) is the most common cause after copying the app by hand.
