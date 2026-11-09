# Changelog

## 0.3.0-experimental (includes 0.2.0)
- **Found by testing on a device:** the install works, the emulator does not start (see README: the bundled binary opens windows only through fbdev).
- `./rtcore.sh doctor` and an automatic short report in `logs/launch.log` when the emulator exits within 6 s.
- The launcher links unversioned libraries (e.g. `libEGL.so`) to the versioned ones present on the system and logs what is still missing.
- Starts like ROCKNIX's own scripts: `source /etc/profile`, `set_kill set dolphin` (its exit hotkey).
- Window platform chosen from what the binary offers (`--platform=wayland|x11`), option *Window platform*; `doctor` checks glibc.
- **24 per-game options in 6 submenus** (was 7), from one table `config/options.tsv`; new ones default to "Profile default" (no change).
- The ES menu is merged into `es_features.cfg` (this ES has no `<sharedFeatures>` and does not merge extra files); idempotent, backed up, removable.
- `uninstall.sh` restarted ES with the Knulli init script and called a theme script that does not exist here: fixed.

## 0.1.0-experimental
- First ROCKNIX derivative of Rt:Core K 0.2.0. **Not tested on a device.**
- Paths: `/storage`, ES custom systems in `/storage/.emulationstation`, settings in `/storage/.config/system/configs/system.cfg`.
- No `es_features_*.cfg`: this EmulationStation reads a single `es_features.cfg`, so the per-game option menu is not added. The Rt:Core profile is still chosen per game (Emulator/Core); the other options default and can be set by hand in `system.cfg` (see README).
