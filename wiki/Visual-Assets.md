# Visual Assets

## Inventory

From the repository root:

```sh
python3 tools/asset_inventory.py
python3 tools/asset_inventory.py --contact-sheet
```

The tool writes JSON and CSV manifests containing asset path, type, file size and SHA-256. Pillow adds raster dimensions/frame counts and enables the optional contact sheet. Reports live below `artifacts/asset-audit/` and are ignored by Git by default.

## Capture and ownership

- Keep editable/source artwork separate from generated exports.
- Preserve license and attribution files next to third-party assets.
- Prefer vector icons where the target runtime supports them; use raster art for textures and device-specific imagery.
- Do not introduce duplicate exports, unused fonts or oversized files without a reason.
- Do not bundle ROMs, BIOS, firmware, game cover art or copyrighted artwork without redistribution rights.
- Do not store screenshots containing private user data or secrets.

The manifest is an audit aid; review each asset at native resolution before changing or deleting it.
