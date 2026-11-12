# Rt:Core profiles

## 1. One source of truth

`workshop/` is the canonical editable store for Rt:Core profiles, controller
layouts, hotkeys, logging presets and per-game GameSettings. Dolphin's live
`Config/` directory is a generated runtime projection, not another profile
library. The core-profile pipeline starts from
`workshop/rtcoreprofile/Default/`, layers the family folder and selected tier,
then applies the active per-game GameSettings before Dolphin starts.
`workshop/base/` remains a shared fallback for controller, hotkey and other
non-core profile families; its old Dolphin.ini/GFX.ini copies are not the
authoritative core-profile baseline.

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

The same chain resolver is used by the Rt:UI profile manager and
`tools/rt_profile_merge.py`: `Default -> family -> tier -> GameSettings`.
The selected tier therefore inherits its family patch (for example,
`RtPrime/std` applies `Default`, then `RtPrime`, then `RtPrime/std`).
The resulting INIs are written to the live `Config/` directory; source
profiles remain untouched.

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

Per-game overrides live only in `workshop/gamesettings/<ID>/`. The
`rtgameset_data.ini` metadata selects the active file through `ActiveConfig`.
The shared launcher reads that same active file from both entry points and
merges it into the runtime Dolphin.ini/GFX.ini projection. The editable source
is never taken from Config. Sections are namespaced:

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

1. RtSys applies only the neutral firmware/device baseline.
2. `scripts/launch.sh` resolves the canonical profile chain from Workshop.
3. The active GameSettings file is merged after the selected family/tier.
4. Controller, hotkeys, logging and selected mods are projected from their
   Workshop sources into the runtime Config/Load paths.
5. Dolphin starts with `-u <emu_dir> -e <rom>`.

## 7. Diff viewer

`workshop_diff.lua` compares core profiles against
`workshop/rtcoreprofile/Default/`; non-core families retain their shared
`workshop/base/` fallback.
Rows are grouped by file, section, key, with FROM and TO columns.

## 8. Tier comparison

`workshop_editor` opens a Tier Overlay on SELECT when the profile
belongs to a family with all three variants present. Columns:
LITE / STANDARD / MAX. The overlay flags any row where the ordering
`lite < std < max` is violated.
