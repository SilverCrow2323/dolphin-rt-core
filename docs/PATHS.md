# Paths

CWD at runtime is `<root>/frontend/`. Every relative path in the
code resolves inside `frontend/`.

## 1. Live Dolphin config (read by the emulator)

```
/opt/muos/share/emulator/dolphin/Config/Dolphin.ini
/opt/muos/share/emulator/dolphin/Config/GFX.ini
/opt/muos/share/emulator/dolphin/Config/GCPadNew.ini
/opt/muos/share/emulator/dolphin/Config/WiimoteNew.ini
/opt/muos/share/emulator/dolphin/Config/Hotkeys.ini
/opt/muos/share/emulator/dolphin/Config/Logger.ini
/opt/muos/share/emulator/dolphin/Config/GameSettings/<ID>.ini
```

These are copied from `workshop/` at launch time by
`profile_manager.lua`.

## 2. Workshop (managed by DolphinUI)

```
workshop/base/                     Baseline INIs
workshop/rtcoreprofile/<name>/     Rt:Core profiles
workshop/controller/GameCube/<n>/  GC controller layouts
workshop/controller/Wii/<n>/       Wii controller layouts
workshop/gamesettings/<ID>/        Per-game overrides
workshop/hotkeys/<name>/           Hotkey profiles
workshop/logging/<name>/           Logger profiles
workshop/snapshots/                Snapshot files
workshop/flashback/<id>/           Full config backups
```

## 3. Dolphin resources

```
/opt/muos/share/emulator/dolphin/Load/GraphicMods/   Graphics mods
/opt/muos/share/emulator/dolphin/Load/Textures/<ID>/ HD texture packs
/opt/muos/share/emulator/dolphin/StateSaves/         Save states
/opt/muos/share/emulator/dolphin/GC/USA|EUR|JAP/     GameCube BIOS
/opt/muos/share/emulator/dolphin/Wii/title/          Wii NAND dump
```

## 4. Runtime data

```
frontend/data/frontendone.json       User settings
frontend/data/keybindings.json       Keyboard remaps
frontend/data/games_data.json        Community compat index
frontend/data/rtenhancerhub.json     Store catalogue
frontend/data/wiitdb.txt             GameTDB titles
frontend/data/external_input.json    Paired controllers
frontend/data/installed.json         Installed store items
frontend/data/downloads/queue.json   Download queue
frontend/data/covers/                Cover cache
frontend/data/reports/               Test reports
frontend/data/logs/                  Runtime logs
frontend/data/icons/                 Cached icon assets
```

## 5. Minoru data

```
frontend/minoru/data/persona.json    Traits
frontend/minoru/data/history.json    Event log
frontend/minoru/data/workspace.json  Virtual files
```

## 6. Homebrew

```
frontend/hb/<AppDir>/                One folder per app
frontend/hb/<AppDir>/rtcore_hb.ini   Native metadata
frontend/hb/<AppDir>/meta.xml        HBC standard metadata
frontend/hb/<AppDir>/icon.png        Icon (fallback)
frontend/hb/<AppDir>/boot.dol|elf    Executable
```

## 7. Logs

| File | Producer |
|---|---|
| `data/logs/launcher_<timestamp>.log` | `launch.sh` |
| `data/logs/dolphinrtcore_*.log` | Dolphin core |
| `data/logs/frontend.log` | LOVE restart |
| `data/logs/livemenu.log` | Live menu daemon |
| `data/logs/crash_<timestamp>.log` | `crash_handler.lua` |
| `/opt/muos/share/emulator/dolphin/rtdata/logs/overview.log` | External core |

Rotation: `main.lua`'s `rotate_all_logs()` keeps the 20 most recent
of each pattern.

## 8. Environment variables

| Variable | Set by | Meaning |
|---|---|---|
| `DOLPHINUI_RETURN_TO` | `launch.sh` | Screen to open after a game exits |
| `DOLPHINUI_LAST_EXIT` | `launch.sh` | Exit code of the last Dolphin run |
| `DOLPHINUI_LAST_TITLE` | `launch.sh` | Title of the last game |
| `DOLPHINUI_LAST_ID` | `launch.sh` | Game ID of the last game |
| `XDG_DATA_HOME` | `mux_launch.sh` | Redirected to `frontend/data/` |
| `HOME` | `mux_launch.sh` | Same |
| `SDL_GAMECONTROLLERCONFIG_FILE` | `mux_launch.sh` | Native muOS gamepad DB |
