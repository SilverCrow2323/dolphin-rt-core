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


    def _make_valid_pack(self, root):
        root.mkdir()
        screens = ["library", "settings"]
        resolutions = ["640x480"]
        records = []
        for screen in screens:
            image_path = root / "640x480" / f"{screen}.png"
            image_path.parent.mkdir(exist_ok=True)
            data = studio.PNG_SIGNATURE + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 640, 480)
            image_path.write_bytes(data)
            records.append({
                "screen": screen, "resolution": "640x480",
                "path": f"640x480/{screen}.png", "bytes": len(data),
                "sha256": studio.sha256(image_path), "width": 640, "height": 480,
            })
        manifest = {"schema": 1, "screens": screens, "resolutions": resolutions, "images": records}
        (root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        for name in ("GALLERY.md", "README_GALLERY_SNIPPET.md", "RELEASE_NOTES_SNIPPET.md"):
            (root / name).write_text("review me", encoding="utf-8")
        return manifest

    def test_verify_pack_checks_complete_capture_matrix_and_hashes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "pack"
            self._make_valid_pack(root)
            self.assertEqual(studio.verify_pack(root), 2)

    def test_verify_pack_rejects_modified_png(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "pack"
            self._make_valid_pack(root)
            with (root / "640x480/library.png").open("ab") as stream:
                stream.write(b"tamper")
            with self.assertRaisesRegex(ValueError, "fingerprint mismatch"):
                studio.verify_pack(root)

    def test_verify_pack_rejects_manifest_path_traversal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "pack"
            manifest = self._make_valid_pack(root)
            manifest["images"][0]["path"] = "../../outside.png"
            (root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Unsafe screenshot path"):
                studio.verify_pack(root)

    def test_verify_pack_rejects_symlinked_png(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "pack"
            self._make_valid_pack(root)
            target = root / "640x480/library.png"
            outside = Path(tmp) / "outside.png"
            outside.write_bytes(target.read_bytes())
            target.unlink()
            target.symlink_to(outside)
            with self.assertRaisesRegex(ValueError, "symlink"):
                studio.verify_pack(root)

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
