# Project Map

Dolphin Rt:Core contains several platform deliverables. The repository root README is authoritative for current support status and release versions.

| Component | Source | Responsibility |
|---|---|---|
| muOS Andromeda | `dolphin-rtcore-muos/` | Current muOS package, shared Dolphin integration and LÖVE frontend |
| Knulli | `dolphin-rtcore-k/` | Platform-specific integration and packaging |
| ROCKNIX | `dolphin-rtcore-r/` | Experimental platform derivative |
| Rt:Stream PC portal | `portal/` | PC portal, host services, profiles and packaging |
| Compatibility Database | `index.html`, `sw.js`, `manifest.json` | Searchable community test reports and PWA shell |
| Historical releases | `Core_History/` | Archived versions; not the current source of truth |

The active muOS LÖVE frontend is `dolphin-rtcore-muos/app/Dolphin RtUI/`. Entry points include `main.lua`, `conf.lua`, `core/`, `ui/` and `assets/`.

The frontend and website use the same tracked compatibility data files. Update the data once; do not create a second source of truth.

Do not copy historical code into current deliverables without checking compatibility and provenance. Keep platform-specific paths in each platform package. 
