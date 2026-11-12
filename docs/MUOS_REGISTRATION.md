# muOS registration and firmware detection

`dolphin-rtcore-muos/overlay/opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh` is the single entry point used by the installer, startup launcher and Rt:UI Settings. It delegates release/API detection to `muos_platform.sh`.

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

## Runtime integration

- `opt/update.sh` registers the core entries after package installation.
- The muOS application launcher runs `manifest_tool.sh ensure` synchronously before opening LÖVE. A failure is logged but does not prevent the frontend from opening.
- Rt:UI Settings exposes **Repair GameCube/Wii registration** and **Core profile visibility**; installation and startup still run the automatic registration check.
- The triage screen checks the definition and alias index on manifest builds, and checks legacy `global.ini` files on Jacaranda-style installations.

## Tests

Run `bash tests/test_muos_registration.sh`. CI checks `sh -n`, `bash -n`, and exercises single-file, split-manifest and legacy fixtures using disposable directories. The test does not replace a physical muOS test.

## Support boundary

The current v12 release remains documented for Andromeda 2606.0. Jacaranda's v11.5.1 line remains separate in the root support matrix. The detection layer makes the registration method adaptable; it does not claim the v12 package is a certified Jacaranda release.
