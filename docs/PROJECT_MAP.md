# Project map

## Product boundaries

Dolphin Rt:Core is a multi-platform repository. The root README is authoritative for the current release matrix; this page describes where to work.

| Area | Location | Responsibility |
|---|---|---|
| muOS Andromeda | `dolphin-rtcore-muos/` | Current muOS package, shared Dolphin data, launcher and LÖVE frontend |
| Knulli | `dolphin-rtcore-k/` | Knulli integration and packaging |
| ROCKNIX | `dolphin-rtcore-r/` | Experimental ROCKNIX derivative; hardware status remains as stated in its README |
| Rt:Stream PC portal | `portal/` | PC-side portal, protocol, profiles and packaging |
| Historical releases | `Core_History/` | Preserved prior releases and historical implementation; not the default source for current behavior |
| Shared compatibility/data/art | `data/`, `assets/` | Shared data and repository-level artwork |

## Current muOS frontend

The active LÖVE application is under:

`dolphin-rtcore-muos/app/Dolphin RtUI/`

Useful entry points:

- `main.lua` — LÖVE lifecycle, input routing and logical 640×480 rendering.
- `conf.lua` — window and runtime configuration.
- `core/` — application services and state.
- `ui/` — screen registry, widgets and screen implementations.
- `assets/` — frontend images, fonts and other bundled visual resources.
- `core/devshot.lua` — opt-in screenshot hook. It is inert unless `DOLPHINUI_SHOT` is set.

## Rules for changing boundaries

1. Prefer the current platform directory over copying code from `Core_History/`.
2. Keep platform-specific paths and install behavior inside that platform's package.
3. Shared Dolphin configuration/data must remain compatible with the platform ports that consume it.
4. Never add ROMs, BIOS, copyrighted game art, device secrets, pairing tokens or user logs.
5. Mark hardware-only verification explicitly; a desktop/headless test is not a device test.
