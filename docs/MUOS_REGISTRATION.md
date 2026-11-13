# muOS registration and firmware detection

`dolphin-rtcore-muos/overlay/opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh` is the single entry point used by the installer, startup launcher and Task Toolkit. It delegates release/API detection to `muos_platform.sh`.

## Detection strategy

1. Read `config/system/version` (or `GET_VAR system version` when available).
2. Probe the installed shared manifest directory.
3. Select the registration layout from filesystem capability rather than assuming that a codename uniquely determines it.
4. Validate both profile source trees and the configured default profile before touching the device.

| Capability | Operation |
|---|---|
| `info/manifest/core.json` | Merge the two Nintendo entries and retain other existing system keys. Preserve the original user file once as `.rtcore.bak`. |
| `info/manifest/core/<Namespace>/<System>.json` | Write one JSON file per system under the Nintendo namespace. |
| Legacy `info/assign/<System>/*.ini` | Stage and replace only the two Rt:Core system folders, retaining unrelated user files. |

On manifest-based versions, the tool calls the installed muOS `script/system/assign.sh -p -v` and verifies the generated `assign.json` contains the canonical aliases. Andromeda reads `friendly` arrays from `core.json`; a static legacy `share/info/assign` overlay is not a substitute for this generated map.

## Folder aliases and Registratore Z

The built-in GameCube and Wii definitions include canonical aliases and the observed folder-name variants. RTUI's **Registratore Z** scans detected ROM roots and labels candidate folders as:

- `SKIP MATCH`: the folder name matched a current rule from muOS `skip.ini`.
- `NO ASSIGN`: the name suggests GameCube/Wii but no matching alias is present in the assignment map.
- `MAPPED`: an assignment alias already resolves to that system.
- `REVIEW`: the folder needs manual system selection.

The scanner does not assume that every GameCube/Wii directory is blacklisted. Current Andromeda skip patterns include hidden names (`.*`), underscore-prefixed names (`_*`), the `/img*` path pattern, and several file patterns; they do not explicitly blacklist GameCube or Wii directory names.

When the user confirms a rename, Registratore Z renames the selected folder to `Rt<original-name>` and calls `manifest_tool.sh alias-add <gc|wii> <alias>`. Custom aliases are stored in `/run/muos/storage/info/manifest/rtcore-folder-aliases-*.txt` and merged into the manifest/legacy assignments. The rename is blocked for registered scan roots, existing destinations and symbolic links. If alias registration fails, the folder rename is rolled back. ROM files themselves are not modified.

## Runtime integration

- `opt/update.sh` registers the core entries after package installation.
- The muOS application launcher runs `manifest_tool.sh ensure` synchronously before opening LÖVE. A failure is logged but does not prevent the frontend from opening.
- Task Toolkit exposes explicit register and profile-mode actions.
- The triage screen checks the definition and alias index on manifest builds, and checks legacy `global.ini` files on Jacaranda-style installations.

## Tests

Run `bash tests/test_muos_registration.sh`. CI also runs Lua tests for Safe Exit, Registratore Z and ROM-root discovery. These tests do not replace a physical muOS test.

## Support boundary

The v12 release remains documented for Andromeda 2606.0. Jacaranda's v11.5.1 line remains separate in the root support matrix. The detection layer makes the registration method adaptable; it does not claim the v12 package is a certified Jacaranda release.
