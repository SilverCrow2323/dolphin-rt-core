# Platform Support

The project has separate deliverables. Never install a package on a different platform merely because its directory names look similar.

| Target | Repository area | Current guidance |
|---|---|---|
| muOS 2606.0 Andromeda | `dolphin-rtcore-muos/` | Current v12 package line; see the root README and [[muOS-Registration]] |
| muOS 2601.1 Jacaranda | `Core_History/` and shared registration logic | v11.5.1 is the legacy release line. Do not assume the current Andromeda .muxupd is a supported Jacaranda release |
| Knulli | `dolphin-rtcore-k/` | Separate launcher, paths and package |
| ROCKNIX | `dolphin-rtcore-r/` | Experimental unless the current root README changes status |
| PC Rt:Stream portal | `portal/` | Separate desktop application and streaming services |

## muOS registration APIs

The runtime helper detects the installed version string, then checks its actual filesystem API:

- Single `info/manifest/core.json`: merge Rt:Core systems into that file and preserve unrelated entries.
- Namespace manifest tree `info/manifest/core/<Namespace>/<System>.json`: write only the two Nintendo system definitions.
- Legacy `info/assign/<System>/*.ini`: write the legacy folders while preserving unrelated files.

See [[muOS-Registration]] for behavior and test commands.

## Evidence levels

- A shell dry-run validates code against a synthetic filesystem; it does not certify muOS behavior.
- A package build validates archive assembly; it does not prove a successful installation.
- A desktop LÖVE screenshot is not a physical-device screenshot.
- A physical test applies only to the device, board revision, firmware, package and configuration actually tested.

When reporting a problem, include the exact device, firmware, package version, emulator binary and reproduction steps.
