from __future__ import annotations

import csv
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
INVENTORY = REPO / "tools" / "asset_inventory.py"


class AssetInventoryTests(unittest.TestCase):
    def test_manifest_and_csv_are_reproducible(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "fixture"
            (root / "assets").mkdir(parents=True)
            sample = b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"></svg>'
            (root / "assets" / "mark.svg").write_bytes(sample)
            (root / "assets" / "ignore.txt").write_text("not an image", encoding="utf-8")
            output = Path(tmp) / "report"

            subprocess.run(
                [sys.executable, str(INVENTORY), "--root", str(root),
                 "--output-dir", str(output)],
                check=True, capture_output=True, text=True,
            )

            manifest = json.loads((output / "assets.json").read_text(encoding="utf-8"))
            self.assertEqual(len(manifest), 1)
            self.assertEqual(manifest[0]["path"], "assets/mark.svg")
            self.assertEqual(manifest[0]["sha256"], hashlib.sha256(sample).hexdigest())
            self.assertEqual(manifest[0]["bytes"], len(sample))

            with (output / "assets.csv").open(newline="", encoding="utf-8") as stream:
                rows = list(csv.DictReader(stream))
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["path"], "assets/mark.svg")

    def test_empty_repository_still_has_headers(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "empty"
            root.mkdir()
            output = Path(tmp) / "report"
            subprocess.run(
                [sys.executable, str(INVENTORY), "--root", str(root),
                 "--output-dir", str(output)],
                check=True, capture_output=True, text=True,
            )
            self.assertEqual(json.loads((output / "assets.json").read_text()), [])
            with (output / "assets.csv").open(newline="", encoding="utf-8") as stream:
                self.assertEqual(list(csv.DictReader(stream)), [])


if __name__ == "__main__":
    unittest.main()
