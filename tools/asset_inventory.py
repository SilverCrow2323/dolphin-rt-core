#!/usr/bin/env python3
"""Inventory raster/vector assets without modifying repository files."""
from __future__ import annotations
import argparse, csv, hashlib, json, os
from pathlib import Path

EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".tif", ".tiff", ".svg", ".ico"}
SKIP_PARTS = {".git", ".venv", "node_modules", "__pycache__", "dist", "build", "artifacts"}

def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def dimensions(path: Path):
    try:
        from PIL import Image
        with Image.open(path) as image:
            return image.width, image.height, getattr(image, "n_frames", 1)
    except ImportError:
        return None, None, None
    except Exception:
        return None, None, None

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument("--contact-sheet", action="store_true", help="Create a thumbnail sheet (requires Pillow)")
    args = parser.parse_args()
    root = args.root.resolve()
    output = (args.output_dir or root / "artifacts" / "asset-audit").resolve()
    rows = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in EXTENSIONS:
            continue
        rel = path.relative_to(root)
        if any(part in SKIP_PARTS for part in rel.parts) or output == path or output in path.parents:
            continue
        width, height, frames = dimensions(path)
        rows.append({
            "path": rel.as_posix(), "format": path.suffix.lower().lstrip("."),
            "width": width, "height": height, "frames": frames,
            "bytes": path.stat().st_size, "sha256": sha256(path),
        })
    output.mkdir(parents=True, exist_ok=True)
    (output / "assets.json").write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
    with (output / "assets.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]) if rows else
                                ["path", "format", "width", "height", "frames", "bytes", "sha256"])
        writer.writeheader()
        writer.writerows(rows)
    if args.contact_sheet:
        try:
            from PIL import Image, ImageDraw
        except ImportError:
            parser.error("--contact-sheet requires Pillow: python3 -m pip install pillow")
        entries = [r for r in rows if r["format"] != "svg"]
        thumb_w, thumb_h, label_h, cols = 180, 135, 38, 4
        thumbs = []
        for row in entries:
            source = root / row["path"]
            try:
                with Image.open(source) as image:
                    image.seek(0); image.thumbnail((thumb_w - 12, thumb_h - 12))
                    tile = Image.new("RGB", (thumb_w, thumb_h + label_h), "white")
                    tile.paste(image.convert("RGB"), ((thumb_w-image.width)//2, (thumb_h-image.height)//2))
                    ImageDraw.Draw(tile).text((6, thumb_h + 4), row["path"][:28], fill="black")
                    thumbs.append(tile)
            except Exception:
                continue
        sheet = Image.new("RGB", (cols * thumb_w, max(1, (len(thumbs)+cols-1)//cols) * (thumb_h+label_h)), "#30343b")
        for index, tile in enumerate(thumbs):
            sheet.paste(tile, ((index % cols)*thumb_w, (index // cols)*(thumb_h+label_h)))
        sheet.save(output / "contact-sheet.jpg", quality=88)
    print(f"Indexed {len(rows)} assets. Reports: {output}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
