# Dolphin Rt:Core — muOS platform detection and registration

## Current release support

The current v12 package is documented for **muOS 2606.0 Andromeda**. The repository also retains the **muOS 2601.1 Jacaranda v11.5.1 legacy line**. A version-aware registration helper does not, by itself, make an Andromeda-only package a supported Jacaranda release: use the package and version listed in the root README.

## Install on Andromeda 2606.0

1. Back up the SD card and Dolphin configuration.
2. Copy the release `.muxupd` into the ROM card's `ARCHIVE` folder.
3. Install it from muOS Archive Manager.
4. Place your compatible aarch64 `dolphin` executable at `/opt/muos/share/emulator/dolphin/dolphin` (the project does not redistribute that binary).
5. Open Dolphin Rt:Core. The installer and launcher run `RtSys/manifest_tool.sh ensure`; use **Settings → System** to repair GameCube/Wii registration and choose **Standard Only** or **All Tiers** profile visibility.
6. In Content Explorer, select a ROM folder, choose **Core Assignment**, then choose a profile.

## Automatic muOS detection

The helper reads `/opt/muos/config/system/version` (or muOS's `GET_VAR system version` helper), then probes the installed manifest structure. Filesystem capability takes priority over the codename:

| Detected API | Registration strategy |
|---|---|
| `info/manifest/core.json` | Merge only Rt:Core's GameCube/Wii definitions into the user manifest; preserve unrelated systems and keep a one-time backup |
| `info/manifest/core/<Namespace>/<System>.json` | Write only `Nintendo/Nintendo Gamecube.json` and `Nintendo/Nintendo Wii.json` |
| Legacy `info/assign/<System>/*.ini` | Stage the two system folders atomically and preserve unrelated user files |

After a manifest update, the helper invokes muOS's own `script/system/assign.sh -p -v` to regenerate `assign.json`. A valid core definition without its content-to-system aliases may still be absent from automatic Content Explorer assignment.

Known version identifiers include `2606.0_ANDROMEDA`, `2601.1_JACARANDA`, and newer manifest-based builds. Unknown codenames are not a blocker when the filesystem exposes a supported manifest API.

## Diagnostics

```sh
sh /opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh status
sh /opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh ensure
```

Logs from the app launch-time check are stored in the frontend's `data/logs/manifest.log`. The muOS assignment generator writes its own report under `MUOS/log/assign_gen.txt`.

## Rollback and uninstall

Use the release-matched uninstall procedure. The registration helper removes only the two Rt:Core systems and their Dolphin profiles; it does not remove other Nintendo systems or user notes. Keep a card backup before upgrading firmware or changing package lines.

## External emulator binary

The Dolphin executable is a separately supplied dependency. Follow the repository's GPL source and redistribution notices for any binary you use.
