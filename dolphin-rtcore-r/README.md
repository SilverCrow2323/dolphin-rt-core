# Dolphin Rt:Core R — ROCKNIX (experimental)

> [!WARNING]
> **Experimental. This has never been run on a device.** It is a derivative of [Rt:Core K](../dolphin-rtcore-k)
> (the Knulli port, tested by the maintainer) adapted from reading the ROCKNIX and EmulationStation sources.
> It passes automated dry-run tests on a fake filesystem (`tests/test_ports_dryrun.sh`); nothing more is claimed.

## What it is
The same idea as Rt:Core K: two EmulationStation systems (`wii`, `gamecube`) whose "cores" are the Rt:Core profiles,
launched through `bin/rtcore-r.sh`, which prepares the Dolphin config for the chosen profile and starts `core/dolphin`.

## What is different from the Knulli port (and why)
| | Knulli (K) | ROCKNIX (R) | Source of the fact |
| :--- | :--- | :--- | :--- |
| user data | `/userdata` | `/storage` | ROCKNIX scripts |
| ES custom systems | `/userdata/system/configs/emulationstation/es_systems_*.cfg` | `/storage/.emulationstation/es_systems_*.cfg` | `SystemData.cpp::loadAdditionnalConfig` + ROCKNIX `es_settings.cfg` path |
| settings file | `batocera.conf` | `/storage/.config/system/configs/system.cfg` | ROCKNIX scripts |
| per-game option menu | `es_features_rtcore.cfg` | **not available** | this ES reads one `es_features.cfg`, it does not merge `es_features_*.cfg` |
| restart ES | `/etc/init.d/S31emulationstation` | `systemctl restart emulationstation` | ROCKNIX scripts |
| theme | installed | **not installed** | ROCKNIX themes live elsewhere |

Without the option menu, the **profile** is still chosen per game (Emulator/Core), and the other options use defaults.
To change them by hand, add lines to `system.cfg`, e.g. `wii["/storage/roms/wii/Game.rvz"].rtc_orient=sideways`
(keys: `rtc_pad`, `rtc_orient`, `rtc_gamesettings`, `rtc_exit`, `rtc_textures`, `rtc_cheats`, `rtc_fps`).

## You must bring your own Dolphin
**ROCKNIX's H700 image ships no Dolphin** (its H700 emulator list is drastic, mednafen, uae4arm). Put your aarch64 build at
`core/dolphin`, together with the `core/Config`, `core/GameSettings` … folders of an Rt:Core release.

## Install (at your own risk)
```sh
cd dolphin-rtcore-r && ./install.sh --dry-run     # see what it would do, writes nothing
./install.sh                                      # writes es_systems_rtcore.cfg, restarts ES
```
Then update the game lists. To undo: `./uninstall.sh`.

## Known unknowns (please report what you find)
- the pad name / SDL GUID / button numbers in `config/devices/rg35xx-h.conf` are copied from Knulli — check them with `sdl2-jstest`
- whether Dolphin opens its window under ROCKNIX's compositor, and which environment variables it needs
- whether the exit combo (read from `/dev/input/js0`) works with ROCKNIX's input stack
