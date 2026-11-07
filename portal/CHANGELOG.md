# Changelog

## 3.5.0

### Handheld — new features

- **SERVER STATUS panel** in the library header: SUNSHINE and LIBRARY LEDs (green = reachable, red = down, gray =
  unknown or HOST empty), refreshed every 15 s by a background HTTP check with a 3 s timeout.
- **Pre-flight host check**: pressing A on a game pings the PC in the background (max 1 s) and shows "CHECKING PC..."
  first. If the PC is offline, you get a clear error toast instead of 5 seconds of "CONNECTING TO STREAM".
- **Guide panel (M)**: on any menu item, pressing M opens a help panel with a short intro and, for options with
  selectable values, per-value descriptions. Values can carry a ✓ recommended or ▲ warning marker. Works from the main
  menu, submenus, overlays and the Controls screen.
- **Search**: filter the current tab by title or app name. X opens the on-screen keyboard with the current query
  pre-filled, B clears the filter. Header shows `[query]` in the accent color, info bar shows "N results".
- **New diagnostic tools** in Tools:
  - *Diagnostics export* — writes system info, all config files and the last stream log to `conf/diagnostics.txt`.
  - *Verify Sunshine apps* — compares the Sunshine app list with the local library and reports mismatches.
  - *Disk space* — filesystem and app folder sizes with warnings.
  - *Measure latency* — 10 pings with min / avg / max / loss.
- **Colored icons** across the whole UI: each category has its own tint (Search cyan, Sync yellow, Streaming violet,
  Interface green, Tools orange, Exit red, and per-type colors inside submenus and overlays).
- **Advanced Options overlays** now show a short intro at the top and inline descriptions under each item.
- **Boot animation v2**: 120-frame sprite sheet (12×10), "Mock Rt:Core" logo with electric flicker, "Dolphin Rt:Core for
  muOS" / "Project" footer, "PRESS ANY BUTTON" prompt removed.
- **Dolphin spin icon** replaces the static logo in the library header (frame-synced rotation).
- **Recent games merged into Favorites** (with deduplication): Favorites tab shows starred games first, then recently
  played. The standalone Recent tab is removed.
- **Uppercase section titles** (STREAMING, INTERFACE, TOOLS) and breadcrumb for consistency.

### Handheld — menu and navigation

- New main menu: quick actions (Search, Sync) on top, then Streaming, Controller profiles, Interface, Tools. Exit
  removed from the menu (B still exits, with the confirm dialog if enabled).
- Controller profiles promoted from Tools to the main menu.
- Menu navigation: ▲ from the top of the item list returns to the last quick action you were on; ▼ from a quick action
  jumps to the first item; ▲ from Search wraps to the last item; ▼ from the last item wraps to Search.
- Overlay layout: dynamic item height so all entries fit without scrolling for the current overlays (up to 6 items).
- Guide panel draws the parent icon as the bullet for each selectable value (Screen, Chart, Disc, Clock, …), keeping
  ✓ / ▲ markers where relevant.

### Handheld — bug fixes and reliability

- `safe()` no longer strips quotes silently: values that lose characters are flagged and a toast appears.
- `launch.txt` is validated before writing (`^[%w_%.%-]+$`, max 64 chars) and the shell script checks it again — no
  shell injection is possible through the library file even if `mux_launch.sh` is edited.
- Zombie `gptokeyb2` after each stream: `wait` added after `kill -9`, plus a `trap INT TERM` handler that cleans up
  GUI and streaming processes on exit.
- Cover cache: LRU size increased from 64 to 256, budget 4/frame (was 2), plus a burst of 48 covers when switching tab.
- RTC guard: dates show "unknown (RTC)" instead of "2047 years ago" when the device clock is below 2025-01-01, plus a
  one-time toast at boot.
- Fixed `wrapInto` to handle `Font:getWrap` order variance safely.
- Controls screen: removed the DS4 profile and the "(Y switches)" hint that made the header too long.
- Menu: fixed "Search / Sync" quick actions that did nothing (missing `t = "quick"`).
- Overlay: `overlayPress` now takes precedence over menu handlers, so navigation inside an overlay no longer leaks to
  the menu below.

### PC portal

- No changes since 3.0.0. Version bumped to keep the handheld and PC packages in sync.

---

## 3.0.0
- **Controls screen on the handheld** (START > Controls): the Dolphin controller mapping drawn on a virtual Xbox pad,
  editable from the handheld (changes are validated and sent to the PC with a token).
- **Controller profile manager** on the PC (`profiles.py`): GCPad, Wiimote and Hotkeys families, `muos*` profiles,
  active profile per kind, applied to Dolphin before every game launch. New profiles: `muos-xbox`, Wiimote
  `muos-nunchuk`, Hotkeys `muos-minimal`. The `muos` hotkeys now live on a MODE layer; Z moved to R3.
- CLI: `spdw-stream profiles ...`, `spdw-stream token`.
- Library server endpoints `/profiles.tsv` and `/ctl` (token protected).
- Portal: profile selectors, token display, scan on every start + SCAN NOW.
- Repository, docs, tests and CI.

## 2.x
- 2.5D GameCube interface for portal and handheld, cover flow, boot animation, English UI.
- Fullscreen Dolphin, XFCE panel hidden while streaming, 4:3 display mode during the stream.

## 1.0
- First release: library sync, Sunshine apps, autostart.
## 4.0.0 — PC portal hardening

### New commands
- `spdw-stream preflight` — run all checks, exit 1 on critical failure
- `spdw-stream cleanup covers` — remove orphan cover PNGs
- `spdw-stream config export|import` — backup/restore `config.json`

### Bug fixes
- `shrink()`: log failures instead of swallowing them silently
- `server_start()`: precheck port availability, wait up to 3s for bind
- `install_dolphin_profiles()`: refuse to apply if Dolphin is running
- `system_checks()`: fix residual Italian string

### Declared for 4.1
- Deduplicate `standalone/spdw_stream_sync.py` vs `portal/spdw_stream_core.py`
- Post-stream watchdog (restore 4:3 / panel after crash)
- Persistent log with rotation
- Treeview search bar
- Auto-update check for Sunshine / Dolphin
