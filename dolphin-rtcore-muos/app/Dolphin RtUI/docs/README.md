# Dolphin Rt:UI 3.4 "Triage" — Flavour III of Dolphin Rt:Core

Controller-first frontend for Dolphin on muOS (RG35XX H, 640x480, 1 GB RAM).
Full description, screenshots and install guide: see the Flavour III README
shipped with the release (`README_Flavour_III_FrontendONE.md`).

## Screens
Home · Library · Game options · Cheats & Boost · Cheat DB · Mod Vault · Hotkeys ·
Controller map · Rt:Profiles / Editor · GameSettings · Compatibility list ·
Settings · Diagnostics · **Rt:Core Env Triage** · About.

## Controls
D-pad move (hold to scroll) · A select/play · B back · X options · Y favourite ·
L1/R1 filter or tab · L2/R2 letter jump · START settings · START+SELECT quit · MENU system drawer.

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

### Profile picker action contract

The Rt:Profiles picker publishes these NEXUS action IDs:

| Action | Arguments | Behavior |
|---|---|---|
| `profiles.refresh` | none | Rescans profile metadata and rebuilds the picker |
| `profiles.create` | none | Creates a new custom profile from Default (or empty INI files) |
| `profiles.open_selected` | none | Opens the currently selected profile in Rt:Editor |
| `profiles.open` | exact profile name | Selects and opens the named profile; rejects unknown names |

Picker actions are available only while the profile screen is in its browse phase.
Creation and selection remain implemented by the profile screen; NEXUS only exposes
stable entry points for menus, shortcuts and diagnostics.

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

### NEXUS integrity diagnostics

`core/nexus_diagnostics.lua` provides a read-only integrity report over the public
catalog returned by `ui.catalog()`. It checks that every registered screen has its
generated `navigation.go.<screen-id>` action, that generated route metadata declares
the `navigation` group and matching screen, and that action targets resolve to known
screens. It also rejects empty registries, malformed or duplicate catalog entries, and sparse/non-array catalog keys. It does not execute
callbacks, mutate the registry, or probe hardware/runtime availability.

Example from a developer console or diagnostic integration:

```lua
local UI = require("ui")
local NexusDiagnostics = require("core.nexus_diagnostics")
local report = NexusDiagnostics.inspect(UI.catalog())
print(NexusDiagnostics.format(report))
```

The report is suitable for support bundles and automated tests. A PASS means the
registry relationships are internally consistent; it is not a claim that every
screen has been exercised on physical muOS hardware.

From the Diagnostics screen, press L1/R1 to open the live NEXUS report. A refresh
rebuilds the catalog snapshot; X exports it to `data/logs/nexus_report.txt`. The
report view is read-only and can be scrolled with the D-pad / L2 / R2.
