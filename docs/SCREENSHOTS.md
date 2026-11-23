# UI screenshot workflow

Rt:UI already has an opt-in LÖVE screenshot hook in `core/devshot.lua` and a low-level capture helper in `tools/capture-ui.sh`. For release documentation, use **Screenshot Studio**: it calls that real renderer, discovers screens from the live registry, captures a resolution matrix, validates the PNGs and creates the accompanying Markdown.

## Requirements

- Python 3.10 or newer (standard library only; no pip install required).
- LÖVE 11.5 available as `love` (or set `LOVE_BIN=/path/to/love`).
- X11 display, or `xvfb-run` / Xvfb for headless Linux.
- The frontend's normal runtime dependencies.

## One-command release gallery

From the repository root:

```sh
python3 tools/screenshot_studio.py
```

By default, this captures **every screen registered in Rt:UI** at 640×480, 720×480 and 720×720. The default output directory is automatically named from the current Core version, Rt:UI version and codename under:

```text
screenshots/releases/
```

The tool writes:

- One PNG per screen and resolution, grouped into resolution subdirectories.
- `GALLERY.md` — complete browsable image gallery.
- `README_GALLERY_SNIPPET.md` — compact block ready to paste into the project README.
- `RELEASE_NOTES_SNIPPET.md` — selected images and link for GitHub release notes.
- `manifest.json` — source commit/ref, versions, capture host, dimensions, byte sizes and SHA-256 for every PNG.

The README and release-note snippets use the current GitHub repository/ref when the output is inside the repository. Run with `--ref v12.5.00` when preparing URLs for a published tag. Images must be committed before those URLs will resolve.

## Useful options

```sh
# Discover screen IDs without launching LÖVE
python3 tools/screenshot_studio.py --list

# Capture only the main showcase screens
python3 tools/screenshot_studio.py --screens "library,triage,settings,compat_list,diagnostics"

# Capture the full UI at the handheld's logical resolution only
python3 tools/screenshot_studio.py --resolutions 640x480

# Choose a specific publish directory and ref for generated image URLs
python3 tools/screenshot_studio.py \
  --out-dir screenshots/releases/v12.5.00-rtui-3.7.0-arcade \
  --ref v12.5.00

# Show the plan without launching LÖVE or writing images
python3 tools/screenshot_studio.py --dry-run
```

Options:

- `--screens LIST`: comma-separated registered screen IDs. Default: all screens.
- `--resolutions LIST`: comma-separated `WIDTHxHEIGHT` values. Default: `640x480,720x480,720x720`.
- `--out-dir DIR`: output directory. Default: versioned directory under `screenshots/releases/`.
- `--delay SECONDS`: settling time before each capture (default: 1.0).
- `--pads SEQUENCE`: inject the same logical button sequence before each selected screen; use sparingly because it can change screen state.
- `--ref REF`: Git ref used in generated GitHub image URLs (default: current branch).
- `--image-base-url URL`: explicitly override the raw-image base URL in snippets.

For a single quick capture or a custom interactive state, the lower-level helper remains available:

```sh
bash tools/capture-ui.sh library
bash tools/capture-ui.sh --screen triage --pads "R1,A,DOWN" --output /tmp/triage.png
bash tools/capture-ui.sh --all --out-dir /tmp/all-screens
```

## Review before publishing

A successful capture proves that a PNG was generated and passed structural/dimension checks. It does not decide whether the image is visually correct. Review the gallery for clipping, overlap, text legibility, contrast, missing resources, focus state and incorrect/empty data.

**Privacy check:** Rt:UI can display the user's actual ROM titles, paths, Wi-Fi details and device diagnostics. Inspect and redact every image before committing or attaching it to a public release. Screenshot Studio never publishes or commits images automatically.

An Xvfb/X11 capture is a screenshot of the LÖVE-rendered UI, not a photograph of an RG35XX H. For handheld evidence, capture the actual device separately and label the device model, firmware, resolution and frontend build. Never label a desktop-rendered image as hardware evidence.
