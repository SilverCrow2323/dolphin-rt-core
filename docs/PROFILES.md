# Rt:Core profiles

## 1. What a profile is

A folder under `workshop/rtcoreprofile/<name>/` containing:

- `Dolphin.ini`
- `GFX.ini`
- `rtprofile_data.ini` (metadata)

At launch, `profile_manager.apply("rtcoreprofile", name)` copies
the two INIs into the live Config directory.

## 2. Families and tiers

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

## 3. Locked profiles

Family profiles set `Runtime.Locked = True`. The editor refuses to
overwrite them; edits are saved as a new `Custom_<date>` profile
under `workshop/rtcoreprofile/`.

## 4. GameSettings

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

## 5. Apply flow

1. `profile_manager.set_active()` updates `S.opts.profile`.
2. At launch, `launch.sh` calls into the frontend, which copies
   the profile's INIs into `Config/`.
3. A backup of the previous INIs is placed under
   `Config/.backup_<timestamp>/`.
4. The Dolphin binary is spawned with `-u <emu_dir> -e <rom>`.

## 6. Diff viewer

`workshop_diff.lua` compares a profile against `workshop/base/`.
Rows are grouped by file, section, key, with FROM and TO columns.

## 7. Tier comparison

`workshop_editor` opens a Tier Overlay on SELECT when the profile
belongs to a family with all three variants present. Columns:
LITE / STANDARD / MAX. The overlay flags any row where the ordering
`lite < std < max` is violated.
