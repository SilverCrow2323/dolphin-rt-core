# Screens

Every screen is a module under `frontend/screens/`. Screens are
registered in `main.lua`'s `screens` table.

## Entry screens

Entered as root; never pushed onto history.

| Screen | Purpose | Notes |
|---|---|---|
| `spdw_warning` | SPDW Factory advisory | Once per launch unless disabled |
| `onboarding` | First-run ROM path wizard | Once ever unless reset |
| `boot` | Boot animation | Random variant + random splash |

## Main flow

| Screen | Entry point | Params |
|---|---|---|
| `menu` | After boot | — |
| `library` | Menu → Game Library | — |
| `game_detail` | Library → [A] | `game` (State.roms item) |
| `compatibility` | Menu → Compatibility | — |
| `homebrew_hub` | Menu → Homebrew Hub | — |
| `homebrew` | Homebrew Hub → ENTER | — |
| `enhancer_boot` | Menu → Rt:Enhancer Dock | — (once per session) |
| `ethostore` | enhancer_boot finish | — |
| `workshop` | Menu → Workshop | — |
| `settings` | Menu → Settings | — |
| `about` | Menu → (usually via Settings) | — |
| `manual` | Menu → Manual | — |
| `minoru_room` | Menu shortcut | — |

## Workshop

| Screen | Purpose |
|---|---|
| `workshop_profiles` | Rt:Core profile families and tiers |
| `workshop_editor` | Universal INI editor |
| `workshop_restore` | Backups + snapshots (two-column) |
| `workshop_data` | Logger profiles |
| `workshop_files` | Config file browser |
| `workshop_mods` | Graphics mod engine toggle |
| `workshop_controller` | Controller profile picker |
| `workshop_hotkeys` | Hotkey profile picker |
| `workshop_hotkey_edit` | Single hotkey binding editor |
| `workshop_gamesets` | GameSettings manager |
| `workshop_rollback` | (Legacy) rollback timeline |
| `workshop_diff` | Profile vs base diff viewer |
| `workshop_snapshots` | Snapshot manager |
| `workshop_logger` | Logger toggle (legacy entry) |

## Configuration

| Screen | Purpose |
|---|---|
| `config_choice` | Manual vs Guided chooser |
| `config_wizard` | Guided profile builder |
| `rom_paths` | ROM path manager per system |
| `file_explorer` | Grid-based folder picker |
| `input_center` | Input hub (keymap / debug / external) |
| `input_debug` | Guided input analysis |
| `settings_app` | App-level settings |
| `settings_keymap` | Keyboard remap UI |
| `external_input_station` | BURST LINK pairing |
| `external` | External Dolphin core hub |

## Reports and tools

| Screen | Purpose |
|---|---|
| `report_window` | Test report form + saved reports |
| `check_rtcore` | Rt:Core diagnostic screen |
| `saves` | Save state browser |
| `cheats` | Cheat code viewer + toggle |

## Conventions

- `S.enter(params)` may receive a table. Always default it:
  ```lua
  function S.enter(params)
    params = params or {}
    ...
  end
  ```
- Screens that own raw input set `State.raw_input = true` in
  `enter()`, release it in `leave()`.
- Screens that need raw button numbers define
  `S.joystickpressed`. They also need `S.joystickreleased` if they
  track release.
- Screens that need keyboard text entry set
  `State.capture_mode = true` while the input overlay is open.
