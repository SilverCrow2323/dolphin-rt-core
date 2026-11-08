# UI screenshot workflow

The muOS LÖVE frontend already contains an opt-in screenshot hook in `core/devshot.lua`. This repository helper standardises its invocation and stores captures outside the source tree by default.

## Requirements

- LÖVE 11.5 available as `love` (or pass `LOVE_BIN=/path/to/love`).
- X11 display, or `xvfb-run` for headless Linux.
- The frontend's normal runtime dependencies.

## Capture one screen

From the repository root:

```sh
tools/capture-ui.sh library
tools/capture-ui.sh triage artifacts/screenshots/triage.png
```

Options:

```sh
tools/capture-ui.sh --help
tools/capture-ui.sh --screen settings --output /tmp/settings.png --delay 2.5
tools/capture-ui.sh --screen triage --pads "R1,A,DOWN" --output /tmp/triage.png
```

The helper sets `DOLPHINUI_SHOT`, passes `--screen=<name>` to LÖVE and uses `xvfb-run` when no display is available. It does not patch application source files.

## Batch capture

Provide a comma-separated list of screen names. Screen names must match the names registered by the frontend; unknown names are not silently translated.

```sh
tools/capture-ui.sh --screens "boot,library,settings,triage" --out-dir artifacts/screenshots
```

A capture is considered successful only when LÖVE exits successfully and a non-empty PNG exists. Review every image: a successful process exit does not prove that the desired screen rendered correctly.

## Handheld evidence

For UI changes, also capture the actual target device when available. Record device model, firmware version, display resolution, frontend build and whether the image is desktop-rendered or device-captured. Do not label an Xvfb screenshot as hardware evidence.
