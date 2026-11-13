# muOS Registration

This page explains how Dolphin Rt:Core adds GameCube and Wii to the muOS core registry. It is about the registration API, not a blanket promise that every package release supports every firmware.

## Detection inputs

The helper reads the muOS version from `/opt/muos/config/system/version` (or `GET_VAR system version`). It then probes the installed manifest directories. The directory layout wins over the codename so downstream builds and point releases can use the same compatible API.

## Supported registration layouts

| Layout | Typical generation | What the helper changes |
|---|---|---|
| Single `core.json` | Andromeda 2606.0 | Adds or replaces only `Nintendo Gamecube` and `Nintendo Wii`; creates a one-time backup before changing an existing user manifest |
| Split `core/<Namespace>/<System>.json` | Newer manifest-based builds | Writes the two system files below `core/Nintendo/`; leaves every other manifest untouched |
| Legacy `info/assign/<System>/*.ini` | Jacaranda and older releases | Stages the two system folders and copies only Rt:Core profile INIs |

The helper also checks the generated `assign.json` on manifest-based systems. A core definition without a matching content-to-system alias may not be selectable automatically in Content Explorer.

## Rt:UI controls

Registration repair and profile visibility are managed inside Dolphin Rt:UI:

- **Settings → System → Repair GameCube/Wii registration** runs the safe `manifest_tool.sh ensure` action.
- **Settings → System → Core profile visibility** selects **Standard Only** or **All Tiers**.

The legacy muOS Task Toolkit entries are no longer installed. The upgrade hook removes old `Dolphin Rt*Core` task directories while preserving unrelated muOS tasks.

## Commands

Run on the handheld:

```sh
sh /opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh status
sh /opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh ensure
sh /opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh apply 1
sh /opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh apply 2
```

- `status` reports detected firmware, registration API and current profile mode.
- `ensure` repairs missing or stale registration and is safe to run at startup.
- `apply 1` exposes the standard profile set.
- `apply 2` exposes all tier profiles.
- `remove` removes only Rt:Core's two systems and Dolphin profiles.

## Logs

- Frontend boot check: `data/logs/manifest.log`
- muOS automatic assignment generator: `MUOS/log/assign_gen.txt`
- Package install: `RtSys/logs/install.log`

## Safety

- The single-manifest path makes a one-time backup before writing.
- Manifest updates use a temporary file and rename.
- Legacy updates stage the new directories and restore the previous directory if the final rename fails.
- Unrelated systems and non-Rt:Core files are preserved.
- A failed registration does not make the frontend itself refuse to launch.

## Support status

The current v12 release is documented for Andromeda 2606.0. Jacaranda remains a separate legacy release line in the root README; use only the package published for that line. Runtime detection is designed to select the appropriate registration strategy when the code is present, but detection alone does not certify package compatibility.

See [[Platform-Support]] and [[Quick-Start]].
