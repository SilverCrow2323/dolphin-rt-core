# Platform Support

Dolphin Rt:Core has multiple platform directories. Support status is version-specific and must be read from the root README and the current platform release notes.

| Target | Repository area | Guidance |
|---|---|---|
| muOS Andromeda | `dolphin-rtcore-muos/` | Current primary package and LÖVE frontend |
| Knulli | `dolphin-rtcore-k/` | Separate launcher, paths and package |
| ROCKNIX | `dolphin-rtcore-r/` | Experimental unless the current README explicitly says otherwise |
| PC Rt:Stream portal | `portal/` | Separate desktop application and handheld streaming client |

## Important distinctions

- A successful shell dry-run is not a hardware certification.
- A desktop LÖVE screenshot is not a physical-device screenshot.
- A package that builds successfully may still require a separately supplied emulator binary.
- Device model, SoC, firmware, screen orientation and input driver can affect behavior.

When reporting an issue, include the exact release, firmware and device combination. Do not describe an experimental port as generally supported because it works on one device.
