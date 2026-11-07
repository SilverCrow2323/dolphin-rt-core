# Dolphin Rt:Core v12 — muOS 2606.0 Andromeda

## Install
1. Copy `Dolphin_RtCore_v12_0_0_Andromeda.muxupd` into the `ARCHIVE` folder of the ROM card and install it from *Archive Manager*.
   The package ships an integrity manifest (`manifest.sha256`) as Andromeda requires, and registers GameCube/Wii in the
   core list by itself at the end of the installation.
2. Put your `dolphin` binary in `/opt/muos/share/emulator/dolphin/` (it is not part of this package).
3. If GameCube/Wii do not show up as systems: *Task Toolkit > Dolphin Rt-Core > Register GameCube and Wii*
   (the app also does this every time it starts).
4. Existing GameCube/Wii folders may need a fresh core choice: Content Explorer > folder > *Core Assignment*.

## Things to know
- `core.json` on 2606.0 is **one file that replaces the bundled one**. The tool merges instead of replacing, but a
  muOS update that adds systems will not show them until you remove our entries (`RtSys/uninstall_dolphinrt.sh`) or re-merge.
  The original is kept once as `MUOS/info/manifest/core.json.rtcore.bak`.
- Quit while playing: the muOS quit hotkey (kills `dolphin`), or START+SELECT via the Rt watcher.

## Rt:Stream (PC side)
The PC portal must serve, on the library port (default 8765):
`/health`, `/library.tsv` and `/covers/<file>`; Sunshine answers on 47989 and games appear as Sunshine apps.
`library.tsv` lines: `gc|wii <TAB> title <TAB> sunshine-app <TAB> covers/<file> <TAB> id <TAB> rom`.
Different endpoints? Set `SYNC_LIBRARY_PATH` / `SYNC_COVER_PATH` in `tools/stream/paths.sh`.
`lib/moonlight` needs libgamestream, libmoonlight-common, libavcodec 58 on the device; if any is missing the
error names it (and Diagnostics lists it).
