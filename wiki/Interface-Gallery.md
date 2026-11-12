<div align="center">

# 🖥️ Rt:UI · Visual Gallery

**Real LÖVE screen captures from the current CI smoke run**

</div>

## Capture set

The CI capture job exercised the declared Rt:UI screens and exported **69 PNG captures** across three viewport sizes:

| Viewport | Intended use |
|---|---|
| **640 × 480** | RG35XX H reference display |
| 720 × 480 | Wider handheld layouts |
| 720 × 720 | Square / expanded layout regression checks |

The archive contains Library, Boot, Settings, Controller Map, Key Map, Safe Exit, Hotkeys, Diagnostics, Rt:Profiles, GameSettings, Rt:Stream and the other registered screens.

**All screen smoke checks passed.**

**Download the PNG capture archive:** [GitHub Actions · CI run #1035](https://github.com/SilverCrow2323/dolphin-rt-core/actions/runs/43213964642)

> [!NOTE]
> These are automated Xvfb/LÖVE captures, not photographs or captures from an RG35XX H. They verify screen loading and layout rendering in CI; they do not certify physical-device rendering, input or performance. GitHub retains this workflow artifact for a limited period (currently 14 days).

## What to inspect first

- **Library** — empty-state layout and navigation footer.
- **Key Map** — button labels and Dolphin SDL tokens.
- **Safe Exit** — visible default combination, **START + SELECT**.
- **Diagnostics / Env Triage** — diagnostic panels and status presentation.

For installation, key mappings and firmware-specific details, see [[Controller-Input]], [[muOS-Firmware-Profiles]] and [[Troubleshooting]].
