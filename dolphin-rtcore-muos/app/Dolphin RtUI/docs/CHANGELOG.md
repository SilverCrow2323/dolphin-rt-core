## 3.7.0 "Arcade" — Rt:Core v12.5.00 for muOS 2606.0 Andromeda
**Release candidate · 2026-11-12**

### Boot and library
- Boot intro now exits autonomously on its final frame or a strict wall-clock ceiling (5.5 s Full, 2.8 s Quick, 0.35 s Off/no mascot); it never waits for network tasks.
- ROM enumeration runs in a detached background worker and is consumed incrementally from a regular file. Boot and Settings rescan no longer wait for a full recursive find.
- The frame budget uses monotonic wall time. File-size reads no longer spawn stat / wc for every ROM.
- ROM roots and discovered paths are deduplicated case-insensitively. Automatic root registration remains disabled: the user explicitly selects a folder with **Add GC** or **Add Wii**.

### FolderWaker and muOS
- Legacy Task Toolkit entries retired. Registration and profile visibility now live in **Settings → System**; upgrades remove previous `Dolphin Rt*Core` task directories without touching unrelated muOS tasks.
- Exact FolderWaker names are gc, ngc, gamecube, game cube, and wii, matched case-insensitively only. Prefixes, suffixes, punctuation and extra whitespace are not accepted.
- The warning explains the muOS Content Explorer firmware restriction in English and presents an explicit YES / NO choice. YES previews the reversible RtGC / RtWii rename and alias; NO leaves the folders untouched.

### Editors and Mod Vault
- GameSettings Editor, Hotkeys and Safe Exit are grouped under **Settings → Editors**, without duplicate rows in Tools.
- Mod Vault supports global enable / disable, bulk enable-all / disable-all and per-game selection. Global disable parks a mod under Load/<Category>.off; it can be restored without deleting its files.
- A globally parked mod cannot be silently re-enabled by a per-game launch plan. Native GraphicMods remain globally toggleable from a per-game Mod Vault view.

### Visual refresh
- Home is the actual post-boot landing screen (first-run ROM setup still takes priority), rebuilt as a controller-first two-column hub with an adventure banner, last-played game, Library, Compatibility and compact tiles tuned to the 640×480 handheld canvas.
- Compatibility uses compact filter chips, game covers (with a fallback tile), large FPS/status, community score, test count and field notes.
- Select opens Rt:Stream from Home only.
- Shared header chrome now reserves separate title, subtitle and status lanes; Settings section tabs no longer collide with section labels or navigation hints.
- Footer hints use controller-shaped keycaps: A red, B yellow, X blue, Y green; shoulder and system controls use grey / charcoal caps.
- Rt:Stream receives a vaporwave refresh with a neon sunset and perspective grid, dedicated connection/status lanes, visible filter and sort state, and three selectable layouts: **Flow**, **Grid** and **List**.

### Package contents
- The full Andromeda release bundle includes the native AArch64 Dolphin executable, its matching Sys resources and required private runtime libraries.
- Official Dolphin GameSettings, Sys/Load resources, stock textures, GraphicMods and Rt:UI per-game presets are retained. Mod Vault manages activation/deactivation without deleting their source payload.
- A fresh build Sys tree is merged over the curated Sys payload; it does not erase official resources that are absent from the build output.
- Developer-local settings, generated app-local caches, backups and temporary files are excluded.
- CI's UI-only package is separately labelled and is not a substitute for the full engine update.

### Release gate
- CI and Xvfb checks are required for this candidate; a green CI result is not a physical-device certification.
- RG35XX H install, boot, input, game launch, frame pacing and Safe Exit still require a test on the target firmware before publishing a final release.

---

# Changelog

## 3.6.0 "Kanzentai" — Rt:Core v12.0.00 for muOS 2606.0 Andromeda

### muOS Andromeda compatibility (checked against the 2606.0_Andromeda sources)
- **Core list moved to the manifest.** Andromeda no longer reads `info/assign/*.ini`. New
  `RtSys/manifest_tool.sh` (apply / ensure / remove / status) turns `switch_weapon/{gc,wii}/mode N/*.ini`
  into manifest entries for *Nintendo Gamecube* and *Nintendo Wii*. It merges into the user manifest
  (`MUOS/info/manifest/core.json` on 2606.0, one file per system on newer builds), never drops another
  system, keeps a one-time backup (`core.json.rtcore.bak`) and refreshes the assign index.
  The app runs `ensure` at every start; three Tasks (Register / Mode 1 / Mode 2) do it by hand.
- **Installable on Andromeda:** the `.muxupd` now carries the `manifest.sha256` that Andromeda requires.
- `switch_weapon.sh`, `mode_status.sh`, Env Triage and the uninstaller work on the manifest.
- Device facts via `GET_VAR device board/stick` (the `/opt/muos/device/config/board/*` files are gone).
- `mux_launch.sh`: no more SIGSTOP of daemons, no forced `SDL_GAMECONTROLLERCONFIG_FILE`, no global
  `killall gptokeyb2` (Andromeda owns gptokeyb in a process group); screen size validated.
- `scripts/launch.sh`: stops only its own gptokeyb2.
- `overlay_exit.sh`: stops when Dolphin ends, no orphan `dd`; the native muOS quit hotkey keeps working
  (`foreground_process` is still set to `dolphin`).
- Uninstaller: fixed the Task-folder removal (wrong arguments) and removes the manifest entries first.

### Fixes in the shared profile data (also used by the Knulli/ROCKNIX ports)
- `WiimoteNew.ini.2joy` and `.2joy.sideways`: the four `Nunchuk/Stick/*` lines were missing the closing backtick.

### Rt:Stream (new, integrated)
- Play the GameCube/Wii library hosted on your PC (Sunshine + Moonlight) from the same app:
  **SELECT** in the Library, or *Settings > Rt:Stream*.
- Views: **Flow** (2.5D), **Grid**, **List**; tabs Library / Favourites / Recent; filter GC/Wii (L2/R2);
  sort (SELECT); favourites (Y); portal + Sunshine status LEDs; launch overlay with a pre-flight check.
- Stream settings: PC address, port, MAC, resolution, FPS, bitrate, codec, network, game optimisation,
  with an on-screen keyboard; tools: Pair (PIN shown on screen), Sync library + covers, Connection test,
  Wake-on-LAN, Latency, Sunshine apps, Disk space, Diagnostics (token/MAC hidden).
- Streams run through the same loop as local games, so muOS never shows its menu in between.
- Runtime data lives in `data/stream/` and is never shipped in the package.
- Works with the real Rt:Stream PC portal (`/library.tsv`, `/covers/<file>`): real titles with `:` `&` `'` accents and
  `(2)` suffixes are accepted (every argument is quoted end to end), the portal LED checks `/library.tsv`.
- Uses a system Moonlight app (`/opt/muos/share/application/Moonlight`, with its libs and keys) when present, else the
  bundled `lib/moonlight`; missing libraries are named in the error and in Diagnostics.
- One-time import from an installed standalone *Dolphin RtStream* (settings, library, covers, pairing keys).

## 3.4.0 "Triage" — Flavour III release (Rt:Core v11.5.00 Triptych)

### Rt:Core Env Triage (rebuilt from scratch)
- New dashboard: one **card per flavour** (I Comfort Zone · II Bash Arsenal · III FrontendONE) with
  READY / PARTIAL / MISSING state and one segment per check, a **checklist** of the selected flavour,
  a **verdict ring** (HEALTHY / DEGRADED / BROKEN + % of checks passed + "fix first") and a
  **numbers panel** (ROMs GC/Wii, emulator size, SD free, profiles, cheat titles, Rt:UI · core versions).
- **A** inspects the checks one by one (full path + what breaks if it is missing),
  **X** saves `data/logs/triage_report.txt`, **Y** rescans, **L1/R1** switch flavour.
- The scan is **incremental**: the UI keeps animating and the cards fill in while it works
  (the old screen froze on `find` + `du`). Executable bits are really checked (`not +x`).
- Fixed: the old screen drew empty boxes instead of ✓/✗ (the font has no such glyphs — now vector icons),
  showed `0 KB` / `0 ROMs` because it ignored your ROM folders (now uses Settings > ROM folders),
  and looked for Flavour III under a hard-coded path (now checks the app that is actually running).
- `DOLPHINUI_TRIAGE_ROOT=<dir>` runs the triage against a fake muOS tree (PC testing).

### System drawer (MENU) fixed
- `ui/system_panel.lua` required `ui.button_icons`, a module that was never shipped: the MENU drawer
  (operations + notification history) **never loaded**. Module restored, dead "History" key removed.

### Dev tools
- `core/devshot.lua` — `DOLPHINUI_SHOT=out.png:2.5 love . --screen=triage` takes a headless screenshot
  and quits; `DOLPHINUI_SHOT_PADS="R1,A,DOWN"` presses buttons first. Costs nothing when unset.

### Release hygiene
- Default `settings.json` (no `last_game`), empty notification history, no `.bak` copies, no sample game card.
- `SHA256SUMS` regenerated.

## 3.3.0 — Settings rebuilt, Compatibility list, Mod Vault gets Graphic Mods

### Settings
- 5 sections, each with its own colour and dedicated icon, big title:
  **Library** (blue) · **Editors** (yellow) · **Display & Sound** (teal) · **System** (lime) · **About & Tools** (pink).
  Switch with **L1/R1** (section chips top right). The START "Sections" panel is gone.
- Bugs fixed: L1/R1 and START did nothing (`S.cats`/`S.cycle_cat` never existed); choice rows
  (Orientation, Boot intro, Effects, Palette, Frame cap) could not be changed (read `row.list`, rows had `values`);
  `sub`/`badge` ran `ls` and per-game scans every frame (now cached).
- Removed the duplicate **Key Map** row (Controller Key Map stays) and the dead *Rt:GameSettings* toggle.
- *Update check* now writes `auto_update_check` (the key boot actually reads); *Compatibility data* really
  switches the DB off; new **Idle power saver** toggle.

### Compatibility list (new)
- Browse the whole games_data.json: filters ALL / PLAYABLE / ISSUES / NOT PLAYABLE (L1/R1),
  "mine only" (X), letter jump (L2/R2), detail panel (status, FPS, stars, profile, devices, best note).
  A opens the game options if it is in your library.

### Mod Vault
- 5th tab **Graphic Mods** (Load/GraphicMods, Dolphin native mods): all installed listed, default off, as before.

## 3.2.0 — Game options rework, Mod Vault, "back" remembers the row

### Game options
- **Profile** and **Hotkeys**: `A` now opens their editor (Profiles / Hotkeys designer);
  `LEFT/RIGHT` still cycle the value.
- Removed the *Edit controller mapping* row (the controller row's `A` already opens the mapper).
- **GameSettings** moved under Profile in PERFORMANCE.
- **Cheats enabled** removed. Cheats are applied at launch if at least one
  cheat/boost is enabled in the database for that game (`U.cheats_active`).
- Section CHEATS & BOOST renamed **CUSTOMIZATION** (Cheats & Boost + Mod Vault).

### Mod Vault (was "Graphic mods")
- 4 coloured tabs with icons: Textures · Wii SD Sync · Riivolution · Dynamic Input,
  reading `/opt/muos/share/emulator/dolphin/Load/<Textures|WiiSDSync|Riivolution|DynamicInputTextures>`.
- Entries applicable to a game: folder = GameID · first 3 chars of the ID (all regions) ·
  game title (case/punctuation-insensitive) · folder named All/Global/Common/…
- Per-game on/off (default: everything applicable is on). The launcher parks
  switched-off entries in `Load/<Cat>.off` and, for Textures/DynamicInputTextures
  entries matched by name or "All", creates a temporary `Load/<Cat>/<GAMEID>` link
  (removed after the game). Plan file: `data/mods_plan.txt`.

### Navigation
- Going back restores the row (and Mod Vault tab) you left from, on every screen.

## 3.1.0 "Definitive+" — compatibility DB fixed, real ROM sizes, smoother handheld UI

### games_data.json / Compatibility (fixed)
- **The Library panel never showed compatibility data**: it read a `[COMPAT]`
  section of the per-game cards that nothing ever wrote. Library and Game
  options now both use `core/compatibility.lua`.
- `core/compatibility.lua` rewritten: *Playable* now comes from
  `test_review.playable` (was "rating > 0"), FPS is the real range (min of mins
  to max of maxes, `N/A` instead of `0-0`), rating ignores unrated entries.
- Duplicate IDs in the DB (e.g. `GEDP01` = Eternal Darkness **and** Geist) are
  kept as variants and picked by title instead of overwriting each other;
  entry-level IDs (`SEKJ99`/`SEKE99`) are indexed too; same game with another
  publisher code is matched by its 4-char prefix (shown as `~`).
- `null` values, BOM, CRLF, string-only FPS (`"15"`) no longer break parsing.
- The DB is parsed once and reloaded only when the file changes (Game options
  re-parsed 260 KB of JSON on every open).
- Downloads are validated (`{ … }`) before replacing the file; the previous
  copy is kept as `games_data.json.bak` and used as fallback if the live file
  is ever corrupt. Applies to `gamesettings.json` and `rtcheats_db.json` too.

### ROM size / scanner
- Size is read with `seek("end")` (no process), with `stat`/`wc -c` fallbacks
  for >2 GB files on 32-bit LuaJIT (Wii images). Unknown size shows `—`, not
  `0 KB`. Format: `512 KB` · `12.4 MB` · `743 MB` · `1.36 GB` (+ file type).
- GameID is read natively per format (ISO/GCM 0x0, RVZ/WIA 0x58, WBFS 0x200,
  CISO 0x8000, `[GAMEID]` in the file name for GCZ) — no more `dd | tr | grep`
  processes per ROM.
- Incremental scan (`scan_begin`/`scan_step`): the Library stays responsive,
  shows a progress bar and fills the list while scanning.

### Handheld / animations
- Screen transitions: slide + fade with cubic easing (forward = left, back =
  right), ~0.25 s.
- List/scroll smoothing is frame-rate independent (`1 - exp(-dt·k)`).
- Idle power saver: 30 fps after 10 s without input, 20 fps after 60 s
  (`DOLPHINUI_IDLE_FPS=0` disables). `dt` clamped so hitches don't make
  animations jump.
- Resolution: `mux_launch.sh` already passed `WxH`; `conf.lua` now uses it and
  `main.lua` scales the 640×480 UI (letterboxed) on 720×480 / 720×720 /
  1280×720 panels. No extra cost at 640×480.
- `K.star` fixed (concave polygon fill artifacts).
- Removed stray empty files (`[Video_*]`, `bare`) and the shipped `ui.log`.

## 3.0.0 "Definitive" — new launcher, mosaic home, mods, cheat database

### Launcher (rewritten)
- `scripts/launch.sh` is now ~270 lines (was 1030) and follows the same
  sequence as `/opt/muos/script/launch/ext-dolphinrt.sh`: muOS env
  (`func.sh`, SDL, foreground process) → `RtSys/apply_profile.sh` baseline →
  workshop profile → controller/hotkeys/logging → cheats + overlays → mods →
  `cd <emu dir> && ./dolphin -e ROM -u <emu dir>` → back to the frontend.
- Removed: the session dir with symlinks, ROM/game-id detection, CPU/IO
  tuning, virtual/HB modes, report files. The UI passes everything explicitly.
- Every step is logged in `data/logs/launch_<ID>_<time>.log`; Dolphin's own
  output goes to `dolphin_<ID>_<time>.log` (last 12 kept).
- Tiers LITE / STANDARD / MAX are applied **only** to Rt:CORE families
  (profile folders with lite/ std/ max/); any other profile ignores them, and
  the Tier row is hidden for them in Game options.
- `--orient=upright|sideways` (Settings > Orientation) goes to apply_profile.sh.

### UI
- **Home**: a mosaic of tiles in different sizes and shapes, each with its own
  colour and icon (Library, Last played, Cheat DB, Hotkeys, Mods, Settings,
  Folders, About + two decorative tiles). The D-pad jumps to the nearest tile.
- **Graphic mods**: choose which installed mods are active per game; the
  launcher parks every other mod (`Load/GraphicMods.off`).
- **Cheat database**: every title in the index with its name (from wiitdb),
  Boost bolt and a MINE badge; filters ALL / BOOST / MINE, letter jump, A opens
  its cheats.
- Settings: Orientation.

## 2.1.2 "Definitive" — launch diagnostics

- `core/rtcheats.lua`: games without an id (unreadable header) no longer crash
  the library draw (`table index is nil`).
- The launcher now runs `launch.sh` through its own interpreter
  (`/bin/bash scripts/launch.sh ...`), so a lost exec bit (zip copied to the
  SD card) cannot make the launch silently fail; `main.lua` also restores the
  exec bits on start.
- About shows the tail of the newest `data/logs/launch_*.log`, so a failed
  launch can be read on the device itself.

## 2.1.1 "Definitive" — input + launch hardening

- **Input:** `main.lua` never forwards the release of a hat (D-pad centre), so
  the "button already down" guard added in 2.0 could stay stuck and the D-pad
  could auto-repeat forever on hat-only controllers. Presses are now
  edge-triggered (a 30 ms twin filter replaces the guard); only gamepad/key
  D-pad presses auto-repeat, and never for more than 12 s.
- **Launch:** the launch call now passes the full option set explicitly
  (profile, tier, controller, hotkeys, cheats, mods, overlays, safe-exit,
  return-to), like the 1.x launch screen did, and only writes cheats into
  Dolphin when some are enabled. Every launch is logged to `data/logs/ui.log`
  (rom, profile, controller...) and failures show a toast.
- Toasts were updated and drawn twice (once by `main.lua`, once by the UI) and
  showed over the boot intro; fixed.

## 2.1.0 "Definitive" — intro + polish

- **Animated boot intro** from the cyber-dolphin spritesheet: it circles the
  handheld, lightning hits the screen (violet flash), the logo types in. The
  sheet was cropped and resized from 3456x2880 to 1896x1730 (942 KB; 13 MB of
  VRAM, released right after boot). Settings > Boot intro: full / quick / off.
  A skips it. Toasts are hidden during the intro.
- The mascot also appears in the empty-library state and in About.
- **Sliding focus cursor** in every list (smooth, follows scrolling).
- Library: detail panel fades in on selection change, cover drop shadow.
- Text clipping is cached (no per-frame measuring).

## 2.0.0 "Definitive" — clean-slate UI

The whole `ui/` layer was rewritten; `core/`, `scripts/` and the workshop data
format are unchanged, so existing profiles, hotkeys and game cards keep working.

- New design system (`ui/kit.lua`): one accent per system, flat chamfered
  surfaces, readable type (>= 12 px), background rendered once, cached text
  metrics, smooth scrolling lists. Effects: off / lite / full (Settings).
- New navigation + input (`ui/init.lua`): D-pad auto-repeat, back stack,
  fade transitions, START+SELECT quit, a broken screen is logged to
  `data/logs/ui.log` and never takes the app down.
- Eight screens replace ~30: boot, library, game options, cheats & boost,
  hotkeys, settings, ROM folders, about.
- Game options write to the rtid card immediately (no save step).
- Removed: the old Workshop zones, profile editors, comparers, data tools and
  the CRT/HUD effects. Everything they edited is still on disk and still used
  by the launcher.
- Fixed along the way: `system` is `"GC"` / `"Wii"` in the library.

## 1.3.1 "Definitive" — device hygiene

- **Frame cap (60 FPS, `DOLPHINUI_FPS` to change):** vsync is off in `conf.lua`
  and there was no limiter, so the UI ran a CPU core at 100% (heat, battery).
- `ui/case3d.lua` reuses one mesh instead of allocating one per face per frame.
- Minimum font size 10 px in the Hotkey Designer, Cheat Browser, Boost Center
  and HUD (8-9 px is unreadable on a 3.5" 640x480 panel).

## 1.3.0 "Definitive"

### Changed
- **Cheat database now uses the real source**: one `<GAMEID>.ini` per game from
  the Dolphin-Core-for-MuOS repo (`data/database/cheats_db/`), indexed by
  `data/rtcheats_db.json` (592 games, 98 with `performance_boost`). The earlier
  aggregated `rtcheats_rogue_*.ini` assumption is gone.
- `core/rtcheats.lua` reads that format: `Boost = true` entries become the
  Boost group, `[GAMEID]` heading comments (`# -- 30 FPS locks`,
  `# -- Visual load reducers`, ...) classify them, `enabled/disabled` toggles are
  understood, 3-char / 4-char ids (`GE4`, `PA3J`) apply to every matching game,
  and your own `rtcheats_data.ini` still wins.
- `scripts/rtcheats_sync.sh` rewritten: downloads only the per-game files that
  are needed, in the background, with progress in `data/rtcheats_sync.status`
  (the old script pointed at a different repo).
- Boost Center downloads missing files for your installed games on its own and
  shows progress; the Cheat Browser fetches a game's file on first open.

### Verified against live data
- Real files (GM4E01, GZLE01, RMCE01, GE4, GZ2E01, GDSE78) parse correctly:
  Boost entries land in Boost with the right class, everything else in Cheats;
  apply writes `[Gecko]` / `[ActionReplay]` blocks tagged `[Rt]`.
- End-to-end in LÖVE: index → background download → library scan → lists.

## 1.2.0 "Final Cut" — Workshop upgrade

### Added
- **Hotkey Designer** (`workshop_hotkeys_designer`): pick any action, capture a
  pad combo by pressing the buttons together, and save it as keyboard
  (gptokeyb2 F-keys, per-profile `ext-dolphin.gptk`, managed block only) or as
  pad expressions (`Button N & Button M`). Switching device translates the
  bindings. Conflict dots, unsaved-changes guard, duplicate profile, idle
  auto-cancel (handhelds have no ESC). Open it with SELECT from Hotkeys System.
- **Boost Center** (`workshop_boost`, new Workshop entry): every installed game
  that has performance patches, scanned incrementally; quick boost and clear
  are written to Dolphin immediately.
- **Cheat Browser** (`workshop_cheats`): per-game BOOST / FPS / CHEATS tabs,
  toggles, bulk actions, details card. Edits are written to Dolphin on exit.
- `core/rtcheats.lua`: two-layer Rogue DB reader (perf / gc / wii files + your
  `rtcheats_data.ini`, yours wins), automatic classification, and writer for
  `GameSettings/<ID>.ini` (`[Gecko]`/`[ActionReplay]` blocks tagged `[Rt]`,
  hand-written codes are never touched).
- `ui/hud.lua`: shared holographic-monitor frame (CRT reveal, HUD title bar).
  The three new screens use it, so the Workshop now has one visual language.
- Mods & Cheats: [Y] opens the Boost Center.

### Fixed
- D-pad never reached `S.hat` in `ui/init.lua` (it was routed to `S.pad`), so
  nine screens that navigate only through `S.hat` (Mods & Cheats, Data & Tools,
  Rt:Profile explorer/editor/comparer, GameSettings editor, Controller editor,
  profile wizard) ignored the D-pad on the device. Fixed for both hat and
  gamepad events.
- `rtgameset_data.ini` of 6 games listed `rtcheats_rouge_*` (typo) as cheat
  sources; now `rtcheats_rogue_*`. The reader accepts both spellings.

## 1.1.0 "Final Cut" — 2026-10-18 (release)

### Added
- `ui/case3d.lua`: the 3D game-case renderer that `ui/cover3d.lua` has always
  tried to load. Until now it was missing, so Compatibility and Gameset Details
  silently fell back to flat 2D covers. GC (190x238) and Wii (190x270) cases now
  rotate with perspective, per-face shading and outline; art falls back to the
  bundled default covers.

### Fixed
- `scripts/launch.sh`: the per-game rtid `Cheats = yes` was read into an unused
  variable (`CHEAT_FLAG`), so cheats were never enabled from the rtid fallback.
  It now sets `CHEATS=1` (an explicit `--cheats=` on the command line still wins
  when it is not `0`).
- Docs and `mux_launch.sh` comments pointed at `tools/launch.sh`; the script
  lives in `scripts/launch.sh`.
- `ui/init.lua`: removed stale commented-out screen registrations.
- File permissions normalised (644 files / 755 scripts + binaries); the bundled
  LÖVE libraries were owner-only.

### Release hygiene
- Removed `.bak*` files, `.devhub` logs and `dev-hub.sh` from the device package.
- Reset `data/notifications_history.json` (contained dev-machine history).
- Version is now fixed (`1.1.0`, build `20261018`) instead of using the date of
  each launch; About screen shows a stable build number.
- Added `SHA256SUMS` for every shipped file.

### Verified
- All 150+ Lua files compile under LuaJIT; every shell script passes `bash -n`;
  every JSON/INI-adjacent data file parses; all `assets/` references resolve.
- Every registered screen was loaded under LÖVE 11.5 (xvfb) with no Lua errors.
