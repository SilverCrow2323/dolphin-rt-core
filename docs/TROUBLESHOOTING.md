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

## GameCube fonts missing (NFS Most Wanted)

Some games require `font_western.bin` and `font_japanese.bin` in
`Sys/GC/`. Copy the official Dolphin 2412 font files into that
directory.

## Nexus loads but library is empty

1. Check ROM paths in Settings → ROM Paths.
2. Verify the paths exist and are readable.
3. Wait for the scan to complete (bottom-right of the Nexus shows
   the count).
4. Look at `data/logs/launcher_<timestamp>.log` for scan errors.

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
