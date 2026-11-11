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

## Validation

Run the contract checks from the repository root:

```sh
luajit tests/test_stream_settings_nexus.lua
luajit tests/test_stream_config_persistence.lua
luajit tests/test_diagnostics_nexus.lua
```

The muOS CI job runs these contract checks before packaging the `.muxupd` archive. Native ARM64 Dolphin build workflows are not required for these UI-only changes.
