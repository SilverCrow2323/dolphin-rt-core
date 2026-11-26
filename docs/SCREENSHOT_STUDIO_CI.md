# Automated Rt:UI screenshot packs

The repository includes a real-render capture pipeline:

- `tools/capture-ui.sh` navigates the LÖVE frontend and captures the registered screens.
- `tools/screenshot_studio.py` validates PNG signatures and dimensions, records SHA-256 provenance, and generates a gallery plus README/release-note snippets.
- `.github/workflows/ui-screenshot-pack.yml` runs the same tool on GitHub Actions and uploads the complete result as an artifact.

## Run locally

```sh
sudo apt install love xvfb
python3 tools/screenshot_studio.py --list
python3 tools/screenshot_studio.py \
  --resolutions 640x480,720x480,720x720 \
  --out-dir screenshots/releases/current
```

On a headless Linux host, the capture wrapper uses `xvfb-run` automatically. Set `LOVE_BIN` if LÖVE is installed under a non-standard executable name.

## Run on GitHub

Open **Actions → Rt:UI screenshot pack → Run workflow**. Choose resolutions, optionally restrict the screen IDs, and select a branch. The workflow:

1. lists registered screen IDs before launching LÖVE;
2. validates the requested capture plan;
3. renders the actual frontend at each resolution;
4. checks every image's dimensions and SHA-256;
5. uploads `manifest.json`, `GALLERY.md`, `README_GALLERY_SNIPPET.md`, `RELEASE_NOTES_SNIPPET.md` and PNGs as one artifact.

The workflow does not commit generated screenshots or edit release notes automatically. Review the artifact for visual glitches and personal data, then copy the approved gallery into the release branch.
