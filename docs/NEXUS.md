# NEXUS action reference

NEXUS is the toolkit-independent action registry used by the LÖVE frontend. Screen adapters register stable action IDs during UI initialization. The action catalog is intended for keyboard/controller input, automation, accessibility bridges and future frontends.

## Action contract

- IDs are lowercase, namespaced and stable. Do not bind external callers to Lua function names or widget positions.
- An action callback receives only its documented arguments.
- Return `true` for success. A second return value may carry a result.
- Return `false, error_message` when an operation is rejected or cannot complete.
- The registry protects callbacks with `pcall`; exceptions become failed action results.
- State actions return snapshots. Callers must treat them as read-only.
- Screen adapters must reuse the screen's existing business logic; do not duplicate persistence or navigation rules in NEXUS.

## Navigation

| Action | Arguments | Purpose |
|---|---|---|
| `navigation.back` | — | Return to the previous screen |
| `navigation.open_library` | — | Open the local game library |
| `system.open_drawer` | — | Open the system drawer |
| `navigation.go.<screen>` | — | Navigate to a registered screen |

## Local library

| Action | Arguments | Purpose |
|---|---|---|
| `library.rescan` | — | Rescan installed games |
| `library.launch_selected` | — | Launch the selected local game |
| `library.open_selected_options` | — | Open selected game options |
| `library.toggle_selected_favorite` | — | Toggle the selected game's favourite state |
| `library.set_filter` | filter ID | Change the library filter |

## Rt:Profiles

| Action | Arguments | Purpose |
|---|---|---|
| `profiles.refresh` | — | Refresh profile list and preserve selection |
| `profiles.create` | — | Start the existing profile creation flow |
| `profiles.open_selected` | — | Open the selected profile |
| `profiles.open` | exact profile name | Open a profile by exact name |

## Rt:Editor

| Action | Arguments | Purpose |
|---|---|---|
| `editor.save` | — | Save pending INI changes |
| `editor.change_selected` | `-1` or `1` | Change selected supported value |
| `editor.recommend_selected` | — | Apply selected guide recommendation |
| `editor.switch_tab` | stable tab ID | Switch editor tab |
| `editor.state` | — | Read editor mode, profile/game, tab, selection, dirty and lock state |

## GameSettings

| Action | Arguments | Purpose |
|---|---|---|
| `gameset_browser.refresh` | — | Refresh browser and preserve selection |
| `gameset_browser.switch_tab` | tab ID | Switch Library/Storage/Database tab |
| `gameset_browser.open_selected` | — | Open selected game or expand selected group |
| `gameset_browser.state` | — | Read browser state |
| `gameset_explorer.refresh` | — | Refresh per-game config list |
| `gameset_explorer.open_selected` | — | Open or create selected config |
| `gameset_explorer.create` | — | Create a new per-game config |
| `gameset_explorer.set_active_selected` | — | Activate/deactivate selected config |
| `gameset_explorer.request_delete_selected` | — | Open the existing deletion confirmation |
| `gameset_explorer.state` | — | Read per-game config state |

## Settings and Mod Vault

| Action | Arguments | Purpose |
|---|---|---|
| `settings.switch_section` | section ID | Switch LIBRARY/EDITORS/DISPLAY/SYSTEM/ABOUT |
| `settings.change_selected` | `-1` or `1` | Change selected choice/toggle |
| `settings.run_selected` | — | Run selected action row |
| `settings.state` | — | Read selected settings state |
| `mods.switch_tab` | category ID | Switch Mod Vault category |
| `mods.toggle_selected` | — | Toggle selected mod for current game |
| `mods.set_all` | boolean | Enable/disable all mods in category |
| `mods.state` | — | Read enabled counts and read-only state |

## ROM folders and compatibility

| Action | Arguments | Purpose |
|---|---|---|
| `folders.refresh` | — | Refresh current folder view |
| `folders.start_browse` | — | Start directory browsing |
| `folders.open_selected` | — | Open selected directory/list entry |
| `folders.add_selected` | `GC` or `Wii` | Register current directory |
| `folders.return_to_list` | — | Return to registered ROM folders |
| `folders.remove_selected` | — | Remove selected registered path |
| `folders.finish` | — | Rescan library and return |
| `folders.state` | — | Read folder navigation state |
| `compat.refresh` | — | Reload compatibility database |
| `compat.set_filter` | `all`, `playable`, `issues`, `not_playable` | Change compatibility filter |
| `compat.set_mine_only` | boolean or omitted | Filter to owned games, or toggle |
| `compat.jump_letter` | `-1` or `1` | Jump by title initial |
| `compat.open_selected` | — | Open selected game only if locally owned |
| `compat.state` | — | Read filter, selection and result counts |

## Environment triage

| Action | Arguments | Purpose |
|---|---|---|
| `triage.rescan` | — | Restart incremental environment scan |
| `triage.select_flavour` | 1-based index | Select environment layer |
| `triage.inspect` | — | Open/close checklist after scan completes |
| `triage.select_check` | 1-based index | Select checklist item |
| `triage.save_report` | — | Save report after scan completes |
| `triage.state` | — | Read progress, verdict and selection |

## Controller profiles and mapping

| Action | Arguments | Purpose |
|---|---|---|
| `controller_profiles.refresh` | — | Refresh profile list |
| `controller_profiles.switch_system` | `GameCube` or `Wii` | Select controller system |
| `controller_profiles.open_selected` | — | Open selected controller profile |
| `controller_profiles.state` | — | Read profile browser state |
| `controller_map.select` | 1-based index | Select mapping row |
| `controller_map.start_remap_selected` | — | Begin raw input capture |
| `controller_map.confirm_remap` | — | Persist captured input |
| `controller_map.cancel_remap` | — | Cancel capture |
| `controller_map.state` | — | Read selected mapping and capture state |

## Cheat Database

| Action | Arguments | Purpose |
|---|---|---|
| `cheatdb.refresh` | — | Rebuild database and ownership index |
| `cheatdb.set_filter` | `all`, `boost`, `mine` | Filter cheat entries |
| `cheatdb.jump_letter` | `-1` or `1` | Jump by title initial |
| `cheatdb.open_selected` | — | Open selected cheat entry |
| `cheatdb.state` | — | Read selection and database counts |

## Rt:Stream

| Action | Arguments | Purpose |
|---|---|---|
| `stream_library.refresh` | — | Reload Stream metadata |
| `stream_library.set_tab` | `library`, `favourites`, `recent` | Select Stream tab |
| `stream_library.set_view` | `flow`, `grid`, `list` | Select presentation |
| `stream_library.set_filter` | `all`, `gamecube`, `wii` | Filter system |
| `stream_library.set_sort` | `az`, `recent`, `most_played` | Change sort order |
| `stream_library.select` | 1-based index | Select Stream game |
| `stream_library.toggle_favourite` | — | Toggle selected favourite |
| `stream_library.launch_selected` | — | Start existing health preflight and launch flow |
| `stream_library.cancel_launch` | — | Cancel active preflight |
| `stream_library.state` | — | Read current Stream browser state |
| `stream_settings.select` | 1-based index | Select setting/tool row |
| `stream_settings.change_selected` | `-1` or `1` | Change selected choice |
| `stream_settings.set_text` | key, value | Set validated HOST/SYNC_PORT/MAC |
| `stream_settings.open_text_editor` | — | Open existing on-screen keyboard |
| `stream_settings.run_selected` | — | Run selected pairing/diagnostic tool |
| `stream_settings.cancel_mode` | — | Return from viewer/keyboard |
| `stream_settings.state` | — | Read redacted state (no host, MAC, PIN or token values) |

## Safety and persistence guarantees

- Locked Rt:Profiles cannot be edited or saved through the editor.
- Failed Rt:Editor writes do not clear the dirty flag.
- GameSettings deletion is only requested through the existing confirmation modal.
- Compatibility entries not present in the local library cannot be opened as local games.
- Mod Vault mutations are rejected when no game is selected.
- Triage reports cannot be saved before the scan completes.
- Controller remaps are not committed until captured input is explicitly confirmed; failed writes restore the previous in-memory mapping.
- Stream launch still uses the existing host configuration and health preflight.
- Stream connection state is redacted; the NEXUS state action never returns host/MAC/token values.
- Failed Stream configuration writes roll back the in-memory setting.

## Diagnostics

| Action | Arguments | Purpose |
|---|---|---|
| `diagnostics.refresh` | — | Refresh log categories and session tail |
| `diagnostics.select_category` | 1-based index | Select a log category |
| `diagnostics.open_selected` | — | Open the latest log in the selected category |
| `diagnostics.scroll_viewer` | integer delta | Scroll the open log viewer |
| `diagnostics.close_viewer` | — | Close the log viewer |
| `diagnostics.request_clear_selected` | — | Request deletion through the existing confirmation modal |
| `diagnostics.request_clear_all` | — | Request all-log deletion through confirmation |
| `diagnostics.switch_mode` | `list` or `settings` | Switch diagnostics mode |
| `diagnostics.select_setting` | 1-based index | Select a log setting |
| `diagnostics.change_setting` | `-1` or `1` | Change selected log setting |
| `diagnostics.state` | — | Read viewer, category and setting state |

Log deletion actions only open the existing confirmation flow; they never delete files merely because an action was invoked.

## Hotkey Designer

| Action | Arguments | Purpose |
|---|---|---|
| `hotkeys.refresh_profiles` | — | Refresh profiles and preserve selection |
| `hotkeys.select_profile` | 1-based index | Select a profile |
| `hotkeys.open_profile` | exact safe profile name | Open an existing profile |
| `hotkeys.open_selected_profile` | — | Open the selected profile |
| `hotkeys.select_action` | 1-based index | Select a hotkey binding |
| `hotkeys.set_device` | `keyboard` or `pad` | Change binding target |
| `hotkeys.change_key` | `-1` or `1` | Change emitted keyboard key |
| `hotkeys.clear_selected` | — | Clear selected binding |
| `hotkeys.start_capture` | — | Begin raw input capture |
| `hotkeys.capture_input` | logical name or raw button number | Add captured input |
| `hotkeys.finish_capture` | boolean | Commit or cancel capture |
| `hotkeys.duplicate_profile` | — | Duplicate the current profile |
| `hotkeys.reload` | — | Discard unsaved edits and reload from disk |
| `hotkeys.save` | — | Persist the current profile |
| `hotkeys.request_back` | — | Leave through the existing unsaved-changes confirmation |
| `hotkeys.state` | — | Read profile, selected binding, dirty/capture and conflict state |

Hotkey profile names are restricted to existing safe directory names. The exit action uses the same unsaved-changes confirmation as controller navigation.
