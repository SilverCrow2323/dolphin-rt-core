from __future__ import annotations

import json
import struct
import tempfile
import unittest
from pathlib import Path

from tools import screenshot_studio as studio


class ScreenshotStudioTests(unittest.TestCase):
    def test_parse_resolutions_preserves_order_and_removes_duplicates(self):
        self.assertEqual(
            studio.parse_resolutions("640x480, 720x480,640X480"),
            [(640, 480), (720, 480)],
        )

    def test_parse_resolutions_rejects_bad_or_unsupported_sizes(self):
        for value in ("640x", "640x480;720x480", "100x100", "5000x480", ""):
            with self.subTest(value=value), self.assertRaises(ValueError):
                studio.parse_resolutions(value)

    def test_png_dimensions_reads_png_ihdr(self):
        header = studio.PNG_SIGNATURE + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 640, 480)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "shot.png"
            path.write_bytes(header)
            self.assertEqual(studio.png_dimensions(path), (640, 480))

    def test_png_dimensions_rejects_non_png(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.png"
            path.write_bytes(b"not a png")
            with self.assertRaises(ValueError):
                studio.png_dimensions(path)

    def test_manifest_cleanup_only_returns_paths_inside_output_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "captures"
            root.mkdir()
            (root / "640x480").mkdir()
            image = root / "640x480" / "library.png"
            image.write_bytes(b"image")
            (root / "manifest.json").write_text(
                json.dumps({"images": [{"path": "640x480/library.png"}, {"path": "../../outside.png"}]}),
                encoding="utf-8",
            )
            self.assertEqual(studio.previous_generated_paths(root), [image.resolve()])

    def test_gallery_and_snippets_reference_generated_images(self):
        records = [
            {"screen": "library", "resolution": "640x480"},
            {"screen": "settings", "resolution": "640x480"},
        ]
        gallery = studio.build_gallery(
            "12.5.00", "3.7.0", "Arcade", ["library", "settings"],
            [(640, 480)], "2026-11-23T00:00:00Z", "deadbeef", "Xvfb",
        )
        self.assertIn("![Game Library — Rt:UI 3.7.0](640x480/library.png)", gallery)
        readme = studio.build_readme_snippet("GALLERY.md", "https://example.invalid/screens", records)
        self.assertIn("https://example.invalid/screens/640x480/library.png", readme)
        notes = studio.build_release_snippet("GALLERY.md", "https://example.invalid/screens", records)
        self.assertIn("Interface tour", notes)
        self.assertIn("https://example.invalid/screens/640x480/library.png", notes)


if __name__ == "__main__":
    unittest.main()
