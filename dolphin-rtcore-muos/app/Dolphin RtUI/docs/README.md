# Dolphin Rt:UI 3.7 "Arcade" — Release candidate for Rt:Core 12.5.00

Controller-first frontend for Dolphin on muOS (RG35XX H, 640x480, 1 GB RAM).
Full description, screenshots and install guide: see the Flavour III README
shipped with the release (`README_Flavour_III_FrontendONE.md`).

## Screens
Home · Library · Game options · Cheats & Boost · Cheat DB · Mod Vault · Hotkeys · Safe Exit ·
ROM folders / FolderWaker · Controller map · Rt:Profiles / Editor · GameSettings ·
Compatibility list · Settings · Diagnostics · **Rt:Core Env Triage** · About.

### FolderWaker

Recognizes only the exact muOS-blocked names `gc`, `ngc`, `gamecube`, `game cube`, and `wii` (case-insensitive). It shows an English warning explaining why Content Explorer skips those folders. YES opens a preview for the canonical `RtGC` / `RtWii` rename and matching assignment alias; NO leaves the folders unchanged. Scanning itself is read-only and never renames folders automatically.

**Why rename instead of symlink?** muOS Content Explorer's storage collector indexes real directory and regular-file entries; symbolic-link entries are skipped. In addition, exFAT ROM partitions cannot store POSIX symlinks. FolderWaker therefore renames only the directory entry (not the ROM files), then registers the alias; if registration fails, it rolls the name back. See the [muOS storage collector](https://github.com/MustardOS/frontend/blob/main/common/storage/union.c) and the [muOS symlink discussion](https://community.muos.dev/t/possible-to-create-folder-symbolic-link-for-box-art/64).

## Controls
D-pad move (hold to scroll) · A select/play · B back · X options · Y favourite ·
L1/R1 filter or tab · L2/R2 letter jump · START settings · SELECT opens Rt:Stream from Home only · MENU system drawer.
GameSettings Editor, Hotkeys and Safe Exit live under Settings → Editors. Safe Exit defaults to START + SELECT; MENU / M is the allowed single-button custom exit.



### Arcade interface refresh

Home uses a compact two-column, controller-first grid designed around the RG35XX H 640×480 logical canvas. The hero panel surfaces the last-played game and library count. Compatibility uses filter chips and a focused detail panel with cover art or a generated fallback, Game ID, FPS/status, community rating and field notes.

The Library scan is incremental from directory discovery through ROM-header reads. Folder roots are added only by the explicit Add GC / Add Wii actions; case variants of the same path are kept as one entry.

Mod Vault can enable or disable installed mods globally (including native GraphicMods), park them reversibly under `Load/<Category>.off`, or set per-game exceptions for categories that support them. A globally parked mod remains disabled for every game.

## Firmware and controller mapping

The System settings include a muOS profile selector: Auto, `= Andromeda`, and `!= Andromeda`. Jacaranda belongs to the non-Andromeda branch and keeps the initial EV_KEY map; Andromeda uses the alternative map. RTUI, joydev Safe Exit, and Dolphin SDL controller profiles use distinct input layers—never copy their button numbers between layers. See the repository [Controller input reference](../../../../docs/CONTROLLER_INPUT.md) and [Hotkeys / Safe Exit](../../../../docs/HOTKEYS.md).

## Layout
- `ui/` — design system (`kit.lua`), navigation (`init.lua`), screens.
- `core/nexus.lua` — NEXUS registry for stable screen IDs, screen metadata and named actions. `ui/init.lua` exposes `register_action`, `run_action` and `catalog`; navigation transitions remain owned by the UI layer.

### Library action contract

The Library screen publishes these NEXUS action IDs after screen registration:

| Action | Arguments | Behavior |
|---|---|---|
| `library.rescan` | none | Starts the incremental ROM scan; rejects a second concurrent scan |
| `library.launch_selected` | none | Launches the currently selected game |
| `library.open_selected_options` | none | Opens options for the selected game |
| `library.toggle_selected_favorite` | none | Toggles the selected game's favorite state |
| `library.set_filter` | `GC`, `WII`, `FAV`, or `1`–`3` | Changes the active Library filter and preserves selection when possible |

Actions that require a selected game return a controlled failure when the selection is empty.
The filter action validates its argument before changing screen state. The action registry
does not bypass Library logic or take ownership of navigation transitions.

### NEXUS contract
- Screen modules are registered once by stable ID; unknown IDs are rejected before navigation.
- Action IDs are explicit names (for example `library.rescan`) and callbacks are invoked through a protected call.
- `ui.catalog()` returns sorted screen and action metadata for diagnostics, menus and future integrations.
- The registry does not execute shell commands or resolve arbitrary module paths from user input.
- `core/` — launcher, library, settings, cheats, covers, triage.
- `scripts/` — `launch.sh`, `rtcheats_sync.sh`, `overlay_exit.sh`.
- `workshop/` — profiles, controllers, hotkeys, game cards (your data).
- Logs: `data/logs/ui.log`, `data/logs/triage_report.txt`, launch logs.

## Environment
`DOLPHINUI_FPS=30` caps the UI · `DOLPHINUI_TRIAGE_ROOT=<dir>` fake muOS tree for the triage ·
`DOLPHINUI_SHOT=out.png:2.5` headless screenshot (dev).
