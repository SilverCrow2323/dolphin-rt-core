# Rt:Core profiles

## 1. One source of truth

`workshop/` is the canonical editable store for Rt:Core profiles, controller
layouts, hotkeys, logging presets and per-game GameSettings. Dolphin's live
`Config/` directory is a generated runtime projection, not another profile
library. The launch pipeline starts from `workshop/base/`, layers the selected
profile and tier, then applies the active per-game GameSettings before Dolphin
starts.

Both entry points use the same pipeline:

- **Dolphin Rt:UI** passes the selected options from its Library and game screens.
- **muOS Content Explorer** resolves the selected external-core name to a
  `workshop/rtcoreprofile/<name>/` entry, reads the ROM GameID and optional
  `workshop/gameslibrary/rtid_<ID>.ini` launch settings, then invokes the same
  `scripts/launch.sh`.

`RtSys` remains the muOS integration layer: device baseline, firmware
compatibility, core registration and Content Explorer entry points. It is not
a second editable catalogue of per-game or Rt:UI profiles. Legacy
`Config/Dolphin.ini.<profile>` files remain only as compatibility/bootstrap
inputs during migration; normal launches are layered from `workshop/`.

## 2. What a profile is

A folder under `workshop/rtcoreprofile/<name>/` containing:

- `Dolphin.ini`
- `GFX.ini`
- `rtprofile_data.ini` (metadata)

At launch, `profile_manager.apply("rtcoreprofile", name)` copies
the two INIs into the live Config directory.

## 3. Families and tiers

| Family | Purpose | Tiers |
|---|---|---|
| `Rt:Boost` | Performance-first, aggressive | Lite / Std / Max |
| `Rt:Prime` | Balanced daily driver | Lite / Std / Max |
| `Rt:Pure` | Strict accuracy | Lite / Std / Max |
| `Rt:Verbose` | Diagnostic (Prime + logs) | — |

Base profiles under `workshop/rtcoreprofile/`:

| Name | Underclock | Notes |
|---|---|---|
| `Default` | 1.00 | Safe baseline |
| `Performance` | 0.70 | Async shaders |
| `Speedhack` | 0.70 | VISkip on |
| `Compatibility` | 1.00 | No speedhacks, sync |
| `Black Screen Fix` | 1.00 | Accurate EFB/XFB |
| `Sweet Spot` | 0.70 | Hand-tuned |
| `Rintromping` | 0.55 | Extreme |

## 4. Locked profiles

Family profiles set `Runtime.Locked = True`. The editor refuses to
overwrite them; edits are saved as a new `Custom_<date>` profile
under `workshop/rtcoreprofile/`.

## 5. GameSettings

Per-game overrides under `workshop/gamesettings/<ID>/`. Copy to
`Config/GameSettings/<ID>.ini` at launch. Sections are namespaced:

| Dolphin.ini section | GameSettings section |
|---|---|
| `[Core]` | `[Core]` |
| `[DSP]` | `[DSP]` |
| `[Interface]` | `[Interface]` |
| `[Settings]` (GFX) | `[Video_Settings]` |
| `[Enhancements]` (GFX) | `[Video_Enhancements]` |
| `[Hacks]` (GFX) | `[Video_Hacks]` |
| `[Hardware]` (GFX) | `[Video_Hardware]` |

**Rule:** writing `[Hacks]` inside a GameSettings file is silently
ignored by Dolphin. Always use `[Video_Hacks]`.

## 6. Apply flow

1. `profile_manager.set_active()` updates `S.opts.profile`.
2. At launch, `launch.sh` calls into the frontend, which copies
   the profile's INIs into `Config/`.
3. A backup of the previous INIs is placed under
   `Config/.backup_<timestamp>/`.
4. The Dolphin binary is spawned with `-u <emu_dir> -e <rom>`.

## 7. Diff viewer

`workshop_diff.lua` compares a profile against `workshop/base/`.
Rows are grouped by file, section, key, with FROM and TO columns.

## 8. Tier comparison

`workshop_editor` opens a Tier Overlay on SELECT when the profile
belongs to a family with all three variants present. Columns:
LITE / STANDARD / MAX. The overlay flags any row where the ordering
`lite < std < max` is violated.
