# UI screenshot workflow

The muOS LÖVE frontend has an opt-in screenshot hook in `core/devshot.lua`. The repository helper standardises its invocation and stores generated images outside source directories by default.

## Requirements

- LÖVE 11.5 available as `love` (or set `LOVE_BIN=/path/to/love`).
- X11 display, or `xvfb-run` for headless Linux.
- The frontend's normal runtime dependencies.

## Capture one screen

From the repository root:

```sh
bash tools/capture-ui.sh library
bash tools/capture-ui.sh --screen triage --pads "R1,A,DOWN" --output artifacts/screenshots/triage.png
```

## Capture many or all screens

```sh
bash tools/capture-ui.sh --screens "boot,library,settings,triage" --out-dir artifacts/screenshots
bash tools/capture-ui.sh --all --out-dir artifacts/screenshots
```

`--all` reads the screen registrations directly from `ui/init.lua` at runtime, so newly registered screens are included automatically and removed screens are not captured accidentally. Use `--list` to print the discovered screen IDs without requiring LÖVE. If one screen fails, the batch continues and reports a final success/failure count instead of abandoning the remaining captures.

## Options

```sh
bash tools/capture-ui.sh --help
bash tools/capture-ui.sh --screen settings --output /tmp/settings.png --delay 2.5
bash tools/capture-ui.sh --screen triage --pads "R1,A,DOWN" --output /tmp/triage.png
```

The helper passes `DOLPHINUI_SHOT` and `DOLPHINUI_SHOT_PADS` to the existing opt-in hook, then uses Xvfb when no display is available. It does not patch frontend source.

A successful process exit only proves a non-empty PNG was produced. Inspect every image for correct state, clipping, focus visibility, missing resources and text contrast at the logical 640×480 resolution.

## Handheld evidence

For UI changes, also capture the actual target device where available. Record device model, firmware, display resolution, frontend build and whether the image is desktop-rendered or device-captured. Never label an Xvfb screenshot as hardware evidence.
