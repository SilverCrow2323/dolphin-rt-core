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

These are the live runtime projection read by Dolphin. The shared launcher
builds them from the canonical editable sources under `workshop/` immediately
before starting a game. Do not edit these active files as profile masters.

Legacy files such as `Dolphin.ini.<profile>` and `GFX.ini.<profile>` are kept
for compatibility/bootstrap during migration; the shared Content Explorer and
Rt:UI launch path does not use them as the selected profile catalogue.

`Config/GameSettings/<ID>.ini` is generated from the one selected
`workshop/gamesettings/<ID>/<ActiveConfig>` file immediately before launch.
Never edit the Config copy directly. When a game has no active preset, the
launcher removes that game's previous user override so old values cannot leak
into a later run.

## 2. Workshop (managed by DolphinUI)

```
workshop/base/                     Shared fallbacks for non-core profiles; legacy Dolphin INIs
workshop/rtcoreprofile/Default/    Canonical core-profile base
workshop/rtcoreprofile/<name>/     Rt:Core profiles, families and tiers
workshop/controller/GameCube/<n>/  GC controller layouts
workshop/controller/Wii/<n>/       Wii controller layouts
workshop/gamesettings/<ID>/        Per-game GameINI source + ActiveConfig
workshop/hotkeys/<name>/           Hotkey profiles
workshop/logging/<name>/           Logger profiles
workshop/snapshots/                Snapshot files
workshop/flashback/<id>/           Full config backups
```


The same `workshop/` catalogue is used by both launch routes. The Content
Explorer adapter resolves its selected external-core slug and ROM GameID, reads
optional `workshop/gameslibrary/rtid_<ID>.ini` migration overrides, and invokes
`scripts/launch.sh`. Rt:UI passes its selections to that same script directly.
The selected core profile comes only from `workshop/rtcoreprofile` and is
layered as `Default -> family -> tier`. GameSettings remain independent and
are projected as one native per-game INI. RtSys is the muOS integration and
compatibility layer; its legacy INI files are bootstrap/fallback inputs, not
the editable profile catalogue.

## 3. Dolphin resources

```
/opt/muos/share/emulator/dolphin/Load/GraphicMods/   Installed graphic mods
/opt/muos/share/emulator/dolphin/Load/Textures/<ID>/ Installed HD texture packs
/opt/muos/share/emulator/dolphin/StateSaves/         Save states
/opt/muos/share/emulator/dolphin/GC/USA|EUR|JAP/     GameCube BIOS
/opt/muos/share/emulator/dolphin/Wii/title/          Wii NAND dump
```


`Load/` is Dolphin's single active resource root, not a profile catalogue.
Installed mod/texture payloads live there; Rt:UI stores per-game enable/disable
choices and temporary link plans in its own data, then prepares that one
`Load/` tree before launch. A frontend/desktop package may have a staging
directory, but the active muOS runtime destination remains
`/opt/muos/share/emulator/dolphin/Load/`.

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
