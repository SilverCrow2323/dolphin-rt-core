import importlib.util
import json
import struct
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("screenshot_studio", ROOT / "tools" / "screenshot_studio.py")
studio = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(studio)


class ScreenshotStudioTests(unittest.TestCase):
    def test_resolution_parser_deduplicates_and_preserves_order(self):
        self.assertEqual(
            studio.parse_resolutions("640x480,720x480,640x480"),
            [(640, 480), (720, 480)],
        )

    def test_resolution_parser_rejects_malformed_and_oversized_values(self):
        for value in ("640x", "192x144", "4000x3000", ""):
            with self.subTest(value=value), self.assertRaises(ValueError):
                studio.parse_resolutions(value)

    def test_png_dimensions_accepts_valid_ihdr(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "valid.png"
            header = studio.PNG_SIGNATURE + b"\x00\x00\x00\x0dIHDR" + struct.pack(">II", 640, 480)
            path.write_bytes(header)
            self.assertEqual(studio.png_dimensions(path), (640, 480))

    def test_png_dimensions_rejects_invalid_signature(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "invalid.png"
            path.write_bytes(b"not-a-png" + bytes(32))
            with self.assertRaises(ValueError):
                studio.png_dimensions(path)

    def test_manifest_cleanup_ignores_paths_outside_output_root(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "gallery"
            root.mkdir()
            outside = Path(directory) / "private.png"
            outside.write_bytes(b"private")
            (root / "inside.png").write_bytes(b"generated")
            (root / "manifest.json").write_text(json.dumps({
                "images": [
                    {"path": "inside.png"},
                    {"path": "../private.png"},
                    {"path": str(outside)},
                ]
            }), encoding="utf-8")
            self.assertEqual(studio.previous_generated_paths(root), [root / "inside.png"])
            self.assertTrue(outside.exists())

    def test_dry_run_does_not_create_output_directory_or_launch_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "not-created"
            with mock.patch.object(studio, "discover_screens", return_value=["library", "settings"]), \
                 mock.patch.object(studio, "read_versions", return_value=("12.5.00", "3.7.0", "Arcade")), \
                 mock.patch.object(studio, "git_value", return_value="main"), \
                 mock.patch.object(studio, "repository_slug", return_value="SilverCrow2323/dolphin-rt-core"), \
                 mock.patch.object(studio, "run", side_effect=AssertionError("dry-run must not launch capture")):
                result = studio.main(["--dry-run", "--out-dir", str(output), "--resolutions", "640x480"])
            self.assertEqual(result, 0)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
