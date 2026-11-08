# Project Map

Dolphin Rt:Core contains several platform deliverables. The repository root README is authoritative for current support status.

| Component | Source |
|---|---|
| muOS | `dolphin-rtcore-muos/` |
| Knulli | `dolphin-rtcore-k/` |
| ROCKNIX (experimental) | `dolphin-rtcore-r/` |
| Rt:Stream PC portal | `portal/` |
| Historical releases | `Core_History/` |

The current muOS LÖVE frontend is `dolphin-rtcore-muos/app/Dolphin RtUI/`. Its entry points include `main.lua`, `conf.lua`, `core/`, `ui/` and `assets/`.

Do not copy historical code into current deliverables without checking compatibility and provenance. Keep platform-specific paths in their platform package.
