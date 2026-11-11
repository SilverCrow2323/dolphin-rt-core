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

On manifest-based versions, the tool calls the installed muOS `script/system/assign.sh -p -v` and verifies `assign.json` contains the the canonical `nintendogamecube` and `nintendowii` aliases. This reflects the actual Content Explorer pipeline: definitions alone are not sufficient if the alias index is stale.

## Content Explorer visibility is separate from core registration

The Nintendo manifest controls which system/core choices muOS can assign. It
does **not** mount arbitrary directories or add Rt:UI's private ROM paths to
muOS Explore Content.

Rt:UI's library scans the paths stored in its own `data/settings.json`.
muOS Explore Content scans the mounted storage library under a directory
named `ROMS`. Consequently, a game can appear in Rt:UI while its parent
folder remains absent from native muOS Explore Content when that path is
outside the mounted `ROMS` tree.

For example, place the GameCube library beneath
`/mnt/mmc/ROMS/GameCube` or `/mnt/sdcard/ROMS/GameCube` (use the mount that
actually contains the ROMs). The GameCube manifest now includes the
`gamecube` friendly alias as well as `gc`, `ngc` and Nintendo aliases.
After changing a folder alias, run `RtSys/manifest_tool.sh ensure` and
reopen Explore Content so muOS can rebuild its visible content list.

## Runtime integration

- `opt/update.sh` registers the core entries after package installation.
- The muOS application launcher runs `manifest_tool.sh ensure` synchronously before opening LÖVE. A failure is logged but does not prevent the frontend from opening.
- Task Toolkit exposes explicit register and profile-mode actions.
- The triage screen checks the definition and alias index on manifest builds, and checks legacy `global.ini` files on Jacaranda-style installations.

## Tests

Run `bash tests/test_muos_registration.sh`. CI checks `sh -n`, `bash -n`, and exercises single-file, split-manifest and legacy fixtures using disposable directories. The test does not replace a physical muOS test.

## Support boundary

The current v12 release remains documented for Andromeda 2606.0. Jacaranda's v11.5.1 line remains separate in the root support matrix. The detection layer makes the registration method adaptable; it does not claim the v12 package is a certified Jacaranda release.
