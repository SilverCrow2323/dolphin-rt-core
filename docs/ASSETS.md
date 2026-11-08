# Visual asset inventory

The asset inventory tool scans repository image files without modifying them. It produces a JSON manifest and CSV index with path, format, dimensions (when Pillow is installed), file size and SHA-256.

## Run

```sh
python3 tools/asset_inventory.py
python3 tools/asset_inventory.py --root . --output-dir artifacts/asset-audit
```

Optional contact sheet (requires Pillow):

```sh
python3 tools/asset_inventory.py --contact-sheet
```

By default reports are written to `artifacts/asset-audit/`, which is intended for local generated output and should not be committed unless a specific report is requested.

## Asset hygiene

- Keep source artwork separate from generated previews.
- Prefer SVG for scalable interface icons where the runtime supports it; use raster formats for textures and device-specific artwork.
- Avoid duplicate images and oversized source exports in runtime bundles.
- Preserve licenses and attribution for third-party assets.
- Never bundle game cover art, ROM imagery, BIOS, firmware, personal screenshots or user data without a clear right to redistribute.
- A contact sheet is a review aid, not a replacement for checking the original image at native resolution.
