<div align="center">

# 🖥️ Rt:UI · Visual Gallery

**Arcade 3.7.0 · Real LÖVE screen captures from CI**

</div>

## Capture set

The Arcade CI capture job exercised all 23 declared Rt:UI screens and exported **69 PNG captures** across three viewport sizes:

| Viewport | Intended use |
|---|---|
| **640 × 480** | RG35XX H reference display |
| 720 × 480 | Wider handheld layouts |
| 720 × 720 | Square / expanded layout regression checks |

The archive contains the refreshed Home, Library, Compatibility browser, Mod Vault, Boot, Settings, Editors, Controller Map, Hotkeys, Safe Exit, Diagnostics, Rt:Profiles, GameSettings and Rt:Stream screens.

**All 23 screens passed the LÖVE smoke test and were captured at all three viewport sizes (69 PNGs total).**

**Download the PNG capture archive:** [GitHub Actions · CI run #1198](https://github.com/SilverCrow2323/dolphin-rt-core/actions/runs/43283168682)

> [!NOTE]
> These are automated Xvfb/LÖVE captures for the 12.1.0 / Rt:UI 3.7.0 Arcade candidate, not photographs or captures from an RG35XX H. They verify screen loading and layout rendering in CI; they do not certify physical-device rendering, input or performance. GitHub retains this workflow artifact for a limited period (currently 14 days).

## What to inspect first

- **Library** — empty-state layout and navigation footer.
- **Key Map** — button labels and Dolphin SDL tokens.
- **Safe Exit** — visible default combination, **START + SELECT**.
- **Diagnostics / Env Triage** — diagnostic panels and status presentation.

For installation, key mappings and firmware-specific details, see [[Controller-Input]], [[muOS-Firmware-Profiles]] and [[Troubleshooting]].
