# Architecture

Dolphin Rt:Core is a multi-deliverable repository. Keep the root README as the canonical release and support matrix.

## Main areas

| Area | Responsibility |
|---|---|
| `dolphin-rtcore-muos/` | muOS install package, runtime overlay and current frontend |
| `dolphin-rtcore-k/` | Knulli-specific integration and release scripts |
| `dolphin-rtcore-r/` | experimental ROCKNIX integration |
| `portal/` | PC-side Rt:Stream portal, services, packaging and tests |
| `data/` | shared repository data and databases |
| `assets/` | repository-level artwork and icon resources |
| `Core_History/` | archived prior implementations; historical reference, not current source by default |
| `index.html`, `manifest.json`, `sw.js` | static Compatibility Database web app and PWA shell |
| `wiki/` | tracked Markdown source used by the Wiki publisher |

## Current muOS frontend

The active LÖVE application is `dolphin-rtcore-muos/app/Dolphin RtUI/`.

- `main.lua` owns LÖVE lifecycle, frame pacing and input entry points.
- `core/` contains application services and data logic.
- `ui/` contains navigation, widgets, themes and screens.
- `assets/` contains fonts, visual resources and audio.
- `data/` contains bundled databases and defaults; user-generated runtime data must remain separate from source-controlled defaults.
- `scripts/` launches Dolphin and handles platform integration.

## Data flow

The frontend's compatibility service reads the bundled `data/games_data.json`. The website reads that same tracked JSON through raw GitHub / jsDelivr URLs. Update the data once, then validate the website contract and the frontend loader.

Rt:Stream separates handheld UI from the PC portal. The PC performs emulation; the handheld receives the stream and sends input. Do not describe Rt:Stream as local handheld emulation.

## Boundaries

- Keep device paths in platform-specific code.
- Avoid runtime writes into packaged source defaults.
- Keep historical releases immutable unless explicitly maintaining an archive.
- Treat reports, external metadata and uploaded assets as untrusted input.
