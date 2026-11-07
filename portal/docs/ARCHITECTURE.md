# Architecture

Dolphin Rt:Stream has two halves that only talk over HTTP (library, profiles) and Moonlight/Sunshine (video, audio, input).

```
PC                                                          Handheld (muOS)
──────────────────────────────────────────────              ──────────────────────────────────────
portal.py  (Tk, gcui.py)  ─┐                                main.lua      state machine, library, menus
spdw_stream_core.py        ├─ config.json                   ui.lua        theme, plates, icons, 3D cube
  scan ─▶ library.tsv      │                                boot.lua      boot animation (canvas)
  covers/*.png             │                                controls.lua  controller mapping screen
  Sunshine apps.json       │                                cfg.lua       settings / stats / overrides
  library server  ─────────┼───── HTTP ────────────────────▶ tools/*.sh   sync, test, pair, profiles, ctl
profiles.py                │                                mux_launch.sh launches Moonlight
  Dolphin ini files   ─────┘
Sunshine ◀══════════════════════ Moonlight stream ═════════ moonlight (moonlight-embedded)
```

## PC side

| File | Role |
|---|---|
| `pc/portal/portal.py` | Tk front end. Runs long jobs in a thread, talks to the core as a library. |
| `pc/portal/gcui.py` | Canvas/Pillow widgets: extruded plates, buttons, slanted tabs, animated header, 3D cube, cover "case" renderer. |
| `pc/portal/spdw_stream_core.py` | Library scan, covers, Sunshine `apps.json`, library server, autostart, system checks, CLI (`spdw-stream`). |
| `pc/portal/profiles.py` | Controller profile manager (install, apply, validated edits, export). No GUI imports. |
| `pc/portal/panel-hide.sh` | `hide`/`show` the XFCE panel via `xfconf-query`, state kept in `~/.cache`. |
| `pc/portal/display-mode.sh` | `set WxH`/`restore` the display mode via `xrandr` (creates the mode with `cvt` if the monitor lacks it). |
| `pc/standalone/spdw_stream_sync.py` | Same scan/Sunshine/serve flow without GUI or profile manager. |

### What happens when a game starts
Sunshine runs the app entry the portal generated:

1. `prep-cmd` **profiles apply** — writes the active GCPad / Wiimote / Hotkeys profile into Dolphin's ini files (Dolphin is not running yet, so nothing overwrites them).
2. `prep-cmd` **panel-hide.sh hide** — only if enabled and `xfconf-query` exists.
3. `prep-cmd` **display-mode.sh set 1280x960** — only if a display mode is configured; the previous mode is saved.
4. `cmd`: `dolphin-emu -b -e "<rom>" -C Dolphin.Display.Fullscreen=True -C Dolphin.Display.RenderToMain=False -C Dolphin.Display.KeepWindowOnTop=True -C Dolphin.Interface.ConfirmStop=False [-C Graphics.Settings.AspectRatio=N]`
5. When Dolphin exits, Sunshine runs the `undo` commands in reverse order: display restored, panel shown.

### Data on the PC
| Path | Content |
|---|---|
| `~/.config/spdw-stream/config.json` | portal configuration (ROM folders, Dolphin command, port, display mode, active profiles, token, ...) |
| `~/.config/spdw-stream/serve.pid` | PID of the library server |
| `~/.local/share/spdw-stream/library/` | `library.tsv`, `covers/` — what the server publishes |
| `~/.config/dolphin-emu/Profiles/{GCPad,Wiimote,Hotkeys}/` | the editable copies of the profiles (source of truth) |
| `~/.config/dolphin-emu/{GCPadNew,WiimoteNew,Hotkeys}.ini` | what Dolphin reads; section 1 is rewritten on every launch |
| `~/.config/autostart/spdw-stream-*.desktop` | autostart entries |

## Handheld side

The app is a single LÖVE project started by `mux_launch.sh` in a loop:

```
while true:
    run the LÖVE GUI                      (library, menus, Controls ...)
    if launch.txt was not written: break  (user exited)
    source conf/stream.conf + launch.env  (settings + per-game overrides)
    run moonlight stream -app "<app>" ... (log → conf/last_stream.log)
    write conf/last_result.txt if it failed or ended within 6 s
```

`main.lua` is a small state machine: library / menus stack / viewer / keyboard / dialog / Controls / launch overlay,
with `press(button)` as the single input entry point (keyboard, gamepad, held-direction repeat all funnel into it).
Drawing is done in a virtual 640×480 space scaled to the window; boot runs into a canvas and is cross-faded onto the
library.

### Data on the handheld (`DolphinStream/conf/`)
| File | Written by | Content |
|---|---|---|
| `stream.conf` | GUI | `KEY="value"` lines sourced by shell scripts (HOST, SYNC_PORT, WIDTH, HEIGHT, FPS, BITRATE, CODEC, REMOTE, SOPS, PLATFORM, EXTRA_ARGS, TOKEN) |
| `library.tsv` | `sync.sh` | games (see PROTOCOL) |
| `profiles.tsv` | `profiles.sh` | controller profiles (see PROTOCOL) |
| `ui.cfg` | GUI | theme, view, sort, toggles |
| `stats.tsv` | GUI | `app<TAB>plays<TAB>last<TAB>fav` |
| `games.tsv` | GUI | per-game overrides `app<TAB>res<TAB>bitrate<TAB>fps` |
| `state.txt` | GUI | last tab and selections |
| `last_stream.log`, `last_result.txt`, `ctl.result`, `pair.log`, `test.log`, `*.status`, `*.done` | scripts | logs and completion flags |

The GUI never blocks on the network: it starts a script in the background and polls a `*.done`/`*.result` file.

## Design decisions

- **Dolphin config is rewritten per launch, not per edit.** Editing a profile only touches the profile file; the active
  ones are applied right before Dolphin starts. That avoids fighting a running Dolphin that rewrites its ini on exit.
- **`muos*` is the editable family.** Your own profiles with other names are listed but never modified remotely.
- **TSV instead of JSON** for everything the handheld reads: busybox has no JSON tools and the Lua side stays tiny.
- **Always HTTP 200 from `/ctl`.** busybox `wget` drops the body on 4xx; the first word of the body (`OK`/`ERR`) carries the result.
- **4:3 at the source.** Moonlight cannot stretch video, and stretching 16:9 to 4:3 only distorts it. Making the stream 4:3 on the PC is exact.
