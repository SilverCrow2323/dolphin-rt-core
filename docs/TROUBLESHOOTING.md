# Troubleshooting

## Black screen on launch

1. Confirm the ISO isn't corrupted.
2. Try the `Black Screen Fix` profile.
3. If persistent, try `Compatibility`.
4. Some titles need `EFBAccessEnable = True` (per-game).
5. Skies of Arcadia Legends needs `MMU = True` (per-game only).

## Textures flickering

Almost never `SafeTextureCacheColorSamples` at 0. First suspect:
`FastDepthCalc`. Despite the name it's the more accurate method on
modern Dolphin, but on Panfrost it can cause flicker. Disable
per-game.

## Choppy FMVs

Raise `SafeTextureCacheColorSamples` to 512 for that specific Game
ID. Never globally.

## Crashes during loading (OOM)

Likely excessive RAM use from texture packs. With 1 GB total, keep
the system lean. Disable `HiresTextures` globally and enable
per-game only.

## Low FPS everywhere

1. Try the Performance or Speedhack profile.
2. Verify `Fastmem = True`.
3. Verify `ShaderCompilationMode = 3`.
4. Reduce internal resolution if above 1.
5. Verify `MSAA = 1` and `SSAA = False`.

## Store download fails (rc=8)

The item's URL points to a release that no longer exists. Report it
in the tracker, or download manually.

## Live Menu does not open

1. Verify Live Menu is enabled in the chips row.
2. Check `gptokeyb2` is present in `lib/`.
3. Check `/dev/uinput` is writable.
4. Look at `data/logs/livemenu.log`.

## GameCube fonts missing (Windows-1252 not loaded)

Dolphin loads the GameCube system fonts from its **Sys directory**, not
from the operating-system font folders. Rt:Core's muOS binary must be
built with `LINUX_LOCAL_DEV=ON`; this makes it look for `Sys/GC/` next
to the executable at `/opt/muos/share/emulator/dolphin/Sys/GC/`.

A binary built with `LINUX_LOCAL_DEV=OFF` instead looks under the
compiled system data directory (normally
`/usr/local/share/dolphin-emu/sys/GC/` on this build). Merely shipping
fonts under the app's uppercase `Sys/` directory will not satisfy that
lookup. Rebuild using the Rt:Core muOS target rather than copying fonts
into `/usr/share/fonts` or renaming individual font files.

The package builder verifies that `font_western.bin`,
`font_japanese.bin`, `dsp_rom.bin`, and `dsp_coef.bin` are present in
`Sys/GC/` before creating the update archive.

## RTUI library is empty or does not discover ROM folders

1. Open Settings → ROM folders and use **Auto-detect ROM roots**. On the first library scan RTUI also probes the muOS ROM mount and common `roms` / `ROMS` paths.
2. Confirm the detected paths exist and contain supported disc images (`.iso`, `.gcm`, `.rvz`, `.gcz`, `.ciso`, `.wbfs`, or `.wia`).
3. If auto-detection misses the folder, use **Browse for a ROM folder** and add it to the correct GC/Wii scanner.
4. Use **Registratore Z** to inspect names that match muOS skip patterns, lack a GameCube/Wii assignment, or need manual review. It shows the exact reason and proposed `Rt...` rename before changing anything.
5. The scanner does not treat every GameCube/Wii-named directory as banned. muOS `skip.ini` rules currently include hidden names (`.*`), underscore-prefixed names (`_*`), `/img*`, and file patterns; they do not explicitly ban `GameCube` or `Wii` folders by name.
6. Look at `data/logs/ui.log`, launch logs, and the muOS assignment generator log if folders still do not appear.

Auto-discovery is read-only: it adds roots to RTUI settings and does not rename or move ROM folders.

## Safe Exit closes a game unexpectedly or does not respond

1. Open Settings → Safe Exit. The default is **START + SELECT** (joydev indices **9 + 8** on the documented RG35XX H `js1` sequence).
2. A single-button custom exit is allowed only for **MENU / M** (index **10**); otherwise record a 2–4 button combination that does not conflict with the game or device overlay.
3. Check `data/safe_exit.conf` and the watcher log under `data/logs/` or `RtSys/logs/watcher.log`.
4. Verify that the launcher selected a real character device. The preferred order is `js1`, `js0`, then another available `js*`; phantom/non-character nodes are ignored.
5. Confirm the exact firmware and controller indices. EV_KEY, joydev and Dolphin SDL button numbering are different; see [Controller input reference](CONTROLLER_INPUT.md).

## Hotkeys do not work

1. Confirm that the selected hotkey profile is not Disabled.
2. Keyboard mode starts `gptokeyb2`; Pad (SDL) mode does not. Do not run both paths simultaneously.
3. Check the copied `Config/Hotkeys.ini` `Device` field and the matching `workshop/hotkeys/<profile>/ext-dolphin.gptk` file.
4. Check the corresponding `gptokeyb2` log under `data/logs/` or `RtSys/logs/`.
5. The bundled keyboard profile uses L2 combinations and does not remap SELECT globally. Safe Exit defaults to START + SELECT; MENU / M is the supported single-button custom exit.

## Frontend does not return after a game

1. Check `DOLPHINUI_RETURN_TO` was set (see `launch.sh`).
2. Check the last line of `data/logs/frontend.log`.
3. If LOVE failed to restart, kill it manually and relaunch from
   the muOS launcher.

## Where to find logs

| Producer | Path |
|---|---|
| Launcher | `data/logs/launcher_<timestamp>.log` |
| Dolphin | `data/logs/dolphinrtcore_*.log` |
| Live Menu | `data/logs/livemenu.log` |
| Crash | `data/logs/crash_<timestamp>.log` |
| dev.sh | `.pclogs/dev_*.log` |
