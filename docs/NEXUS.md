# NEXUS // Action Reference

**Rt:Core · Interface Contract / Field Manual**

NEXUS is the toolkit-independent action registry used by Dolphin Rt:UI. Screen adapters publish stable action IDs while the UI remains the owner of navigation, input, persistence and existing confirmation flows.

## Contract

- Action IDs are stable, lowercase and namespaced. External callers must not depend on widget positions or private Lua function names.
- Each action accepts only its documented arguments.
- Return `false, reason` when an operation is rejected or cannot be completed.
- State actions return read-only snapshots. Callers must not mutate screen-owned state.
- Adapters must reuse existing screen behavior. They must not create a second persistence or navigation path.
- Sensitive connection data must never be included in state snapshots, logs or action metadata.

## Rt:Stream Settings

| Action | Arguments | Purpose |
|---|---|---|
| `stream_settings.select` | 1-based index | Select a setting, choice or tool row |
| `stream_settings.change_selected` | `-1` or `1` | Change the selected choice |
| `stream_settings.set_text` | key, value | Set validated `HOST`, `SYNC_PORT` or `MAC` |
| `stream_settings.open_text_editor` | — | Open the existing on-screen keyboard for a selected text field |
| `stream_settings.run_selected` | — | Start the selected pairing or diagnostic tool |
| `stream_settings.cancel_mode` | — | Return from the keyboard or output viewer |
| `stream_settings.state` | — | Read the current mode and redacted selection state |

### Input boundaries

- `HOST` accepts a non-empty address containing only letters, digits, dots, hyphens and colons.
- `SYNC_PORT` must be an integer from 1 to 65535.
- `MAC` may be empty or contain exactly 12 hexadecimal digits, with optional colon or hyphen separators.
- Other keys are rejected by the text action. Choice updates continue to use the screen's own supported values.
- Resolution is persisted as one batch. A failed write restores every in-memory value in that batch.

### Redaction

The state snapshot may expose the screen mode, whether a host is configured, the selected row label/type and non-sensitive viewer/editor labels. It never returns the configured host, port, MAC address, pairing PIN, token, keyboard contents or diagnostic output.

### Persistence

Stream configuration writes use a temporary file and atomic rename. Single-setting and multi-setting updates roll back their in-memory values when persistence fails; failed batch updates also remove keys that were not previously present.

## Diagnostics

| Action | Arguments | Purpose |
|---|---|---|
| `diagnostics.refresh` | — | Refresh log categories and the session tail |
| `diagnostics.select_category` | 1-based index | Select a log category |
| `diagnostics.open_selected` | — | Open the newest log in the selected category |
| `diagnostics.scroll_viewer` | integer delta | Scroll the open log viewer |
| `diagnostics.close_viewer` | — | Close the log viewer |
| `diagnostics.request_clear_selected` | — | Request cleanup of the selected category |
| `diagnostics.request_clear_all` | — | Request cleanup of all supported log files |
| `diagnostics.switch_mode` | `list` or `settings` | Switch between log categories and settings |
| `diagnostics.select_setting` | 1-based index | Select a log setting |
| `diagnostics.change_setting` | `-1` or `1` | Change the selected log setting |
| `diagnostics.state` | — | Read mode, selection and viewer counts |

### Cleanup safety

Cleanup actions only open the existing confirmation modal. Files are deleted only by the modal's accepted callback; cancelling the modal does not remove anything. The all-log action is rejected while a log viewer is open.

The state snapshot contains counts and selection metadata only. It does not expose log file paths or log contents.

## Hotkey Designer

| Action | Arguments | Purpose |
|---|---|---|
| `hotkeys.refresh_profiles` | — | Refresh existing profiles and preserve selection |
| `hotkeys.select_profile` | 1-based index | Select an existing profile |
| `hotkeys.open_profile` | exact safe profile name | Open a validated profile |
| `hotkeys.open_selected_profile` | — | Open the selected profile |
| `hotkeys.select_action` | 1-based index | Select a hotkey binding |
| `hotkeys.set_device` | `keyboard` or `pad` | Switch binding target |
| `hotkeys.change_key` | `-1` or `1` | Change emitted keyboard key |
| `hotkeys.clear_selected` | — | Clear selected binding |
| `hotkeys.start_capture` | — | Start input capture for the selected binding |
| `hotkeys.capture_input` | logical name or raw SDL button index | Add a recognized input to capture |
| `hotkeys.finish_capture` | boolean | Commit or cancel the capture |
| `hotkeys.duplicate_profile` | — | Duplicate and save the current profile |
| `hotkeys.reload` | — | Discard unsaved edits and reload from disk |
| `hotkeys.save` | — | Persist the current profile |
| `hotkeys.request_back` | — | Leave through the existing unsaved-changes confirmation |
| `hotkeys.state` | — | Read profile, binding, dirty/capture and conflict state |

### Capture and profile safety

Profile names must be safe exact directory names and refer to an existing `Hotkeys.ini`. Capture accepts recognized logical inputs or mapped raw button indices only. D-pad-only captures are rejected in pad mode because Dolphin cannot express them as pad-button combinations. Saving, reloading, device changes and leaving the designer are rejected while capture is active. Exit uses the existing unsaved-changes modal.

## Cheats & Boost

| Action | Arguments | Purpose |
|---|---|---|
| `cheats.refresh` | — | Reload the active game's entries and restart missing database synchronization |
| `cheats.switch_tab` | `boost`, `fps` or `cheats` | Switch the active tab |
| `cheats.select` | 1-based row index | Select a cheat entry; category headers are rejected |
| `cheats.toggle_selected` | — | Change the selected entry in the per-game user data |
| `cheats.bulk_toggle` | — | Run the existing bulk operation for the active tab |
| `cheats.apply` | — | Write enabled codes to Dolphin's GameSettings file |
| `cheats.state` | — | Read the game, tab, selected entry, sync state and per-group counts |

### Persistence and apply boundary

Toggling and bulk operations update the per-game `rtcheats_data.ini` layer only. They do not write codes into Dolphin's GameSettings file. The separate `cheats.apply` action performs that write and reports an explicit failure if Dolphin's file cannot be updated.

Category headers are not selectable or toggleable. All mutation actions reject calls without a valid active game ID. The state snapshot contains entry metadata and counts; it does not expose cheat code contents.

## Game / Launch Configuration

| Action | Arguments | Purpose |
|---|---|---|
| `game.launch` | — | Launch the active game with its saved options |
| `game.select_row` | 1-based row index | Select a non-section game option |
| `game.change_selected` | `-1` or `1` | Change the selected choice or toggle |
| `game.set_choice` | setting key, allowed value | Set a validated profile, tier, controller, hotkey or GameSettings choice |
| `game.set_overlay` | overlay ID, boolean | Set FPS, VPS, speed or OSD HUD overlay |
| `game.run_selected` | — | Run the selected action or launch the game |
| `game.open_editor` | — | Open the selected profile, GameSettings or controller editor |
| `game.request_reset` | — | Request reset through the existing confirmation modal |
| `game.state` | — | Read game identity, selected row, launch choices and overlay state |

### Launch configuration boundaries

Choice values must exist in the current option list for that game. Section headers cannot be selected or changed. Overlay IDs are explicitly allow-listed. Launch and editor actions require a valid active game; controller profile names are checked before constructing editor paths. Reset continues to use the screen's confirmation modal and does not reset anything until accepted.

The state snapshot exposes launch metadata and row labels only; it does not return the ROM path or internal filesystem paths.

## Controller Keymap

| Action | Arguments | Purpose |
|---|---|---|
| `keymap.switch_system` | — | Switch between GameCube and Wii mappings |
| `keymap.select` | 1-based index | Select a controller mapping |
| `keymap.start_remap` | — | Begin a capture for the selected mapping |
| `keymap.capture_input` | raw SDL button index | Capture a validated controller button |
| `keymap.confirm_remap` | — | Persist the proposed controller mapping |
| `keymap.cancel_remap` | — | Discard the current capture |
| `keymap.state` | — | Read system, profile, selection and pending remap metadata |

### Remap safety and persistence

Selection and system changes are blocked while capture is active. Raw button indices must be integers from 0 to 255. A captured mapping is not written until explicitly confirmed. Failed or throwing INI writes restore the in-memory lines and keep the pending confirmation available for retry or cancellation.

Controller profiles are restricted to safe directory names before constructing the INI path. The state snapshot never returns the INI path or file contents.

## Validation

Run the contract checks from the repository root:

```sh
luajit tests/test_stream_settings_nexus.lua
luajit tests/test_stream_config_persistence.lua
luajit tests/test_diagnostics_nexus.lua
luajit tests/test_hotkeys_nexus.lua
luajit tests/test_cheats_screen_nexus.lua
luajit tests/test_game_nexus.lua
luajit tests/test_keymap_nexus.lua
```

The muOS CI job runs these contract checks before packaging the `.muxupd` archive. Native ARM64 Dolphin build workflows are not required for these UI-only changes.
