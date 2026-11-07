# Development guide

## Setup
```bash
git clone https://github.com/SilverCrow2323/dolphin-rt-stream && cd mockrt-core
sudo apt install python3-tk zip              # Tk for the portal, zip for packaging
pip install lupa pillow                      # lupa = headless Lua tests, pillow = portal graphics
make lint test
```
Optional, for real rendering of the handheld UI: `sudo apt install love xvfb libgl1-mesa-dri`.

## Code map

| Want to change... | Look at |
|---|---|
| a handheld menu / setting | `muos/Dolphin\ RtStream/gui/main.lua` (`streamMenu`, `uiMenu`, `toolsMenu`, `mainMenu`) |
| handheld look (plates, icons, themes, footer) | `gui/ui.lua` |
| boot animation | `gui/boot.lua` (timeline in `scene(bt)`) |
| Controls screen | `gui/controls.lua` |
| what Moonlight is started with | `muos/Dolphin\ RtStream/mux_launch.sh` |
| portal widgets | `pc/portal/gcui.py`, layout in `portal.py` |
| Sunshine app command / prep steps | `build_cmd`, `prep_cmds` in `pc/portal/spdw_stream_core.py` |
| controller profiles | `pc/portal/profiles.py`, files in `pc/profiles/` |
| server endpoints | `serve()` in `spdw_stream_core.py` |

## Tests
```bash
cd tests
python3 -m unittest discover -v      # profiles, server (real subprocess + HTTP), standalone script
python3 -m unittest lua.test_gui -v  # real Lua code against a mocked LÖVE API (needs lupa)
```
Every test runs against a throw-away `HOME`; nothing touches your Dolphin config.
The GUI test boots the app, plays the boot animation, walks the Controls screen and sends 2500 random button presses,
so a `nil` index or a bad draw call fails CI. It cannot judge how things *look* — use the screenshot recipe below.

## Screenshots (real LÖVE, no display needed)
```bash
Xvfb :93 -screen 0 800x600x24 &
export DISPLAY=:93 SDL_AUDIODRIVER=dummy LIBGL_ALWAYS_SOFTWARE=1 DOLPHINSTREAM_WINDOWED=1
love muos/Dolphin\ RtStream/gui
```
To script it, append a small block to a *copy* of `main.lua` that wraps `love.update`, calls `press("start")`, … and
`love.graphics.captureScreenshot("name.png")` (files land in `~/.local/share/love/dolphinstream/`). The portal can be
captured the same way with `import -window root shot.png` under `Xvfb`. Use generated demo covers only.

## Conventions
- Handheld UI strings are English; keep labels short (menu value column is ~190 px).
- The handheld never blocks on I/O: start a script with `&`, poll a `*.done` / `*.result` file.
- Shell scripts are POSIX `sh` and quote everything; user-controlled values reach shells only after the strict checks in `profiles.py` / `cfg.lua`.
- New icon → add `function I.<name>(x, y, s)` in `ui.lua` (and keep the line width calls balanced).
- New hotkey/profile → add the `.ini`, run the tests.
- Keep the 640×480 virtual canvas; sizes are tuned for a 3.5" screen.

## Release checklist
1. Update `VERSION`, `CHANGELOG.md`, `VERSION` string in `muos/Dolphin\ RtStream/gui/main.lua` and `VERSION` in `spdw_stream_core.py`.
2. `make lint test`
3. `make all` → `dist/*.deb`, `dist/DolphinStream-muOS-*.zip`
4. Install the `.deb` on a clean machine, run **SYSTEM ▸ APPLY**, stream one GameCube and one Wii game, edit a binding from the handheld.
5. Tag and attach the two artifacts to the GitHub release.

## Known limits / ideas
- X11 only for display switching and panel hiding (Wayland: use *Command before/after stream*).
- Per-game controller profiles (e.g. Wii: nunchuk only for some games) — natural extension of `games.tsv`.
- Editing analog axes and dead zones from the handheld.
- Wake-on-LAN from the handheld.
