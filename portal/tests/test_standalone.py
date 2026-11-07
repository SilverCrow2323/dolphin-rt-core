import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from helpers import ROOT

SCRIPT = ROOT / "pc" / "standalone" / "spdw_stream_sync.py"


class StandaloneTest(unittest.TestCase):
    def test_scan_ids_and_sunshine_apps(self):
        tmp = Path(tempfile.mkdtemp())
        (tmp / "gc").mkdir()
        (tmp / "wii").mkdir()
        (tmp / "gc" / "Melee (Europe).iso").write_bytes(b"GALE01" + b"\0" * 100)
        (tmp / "wii" / "Wii Sports.rvz").write_bytes(b"RVZ\x01" + b"\0" * 0x54 + b"RSPP01")
        (tmp / "wii" / "Kart.wbfs").write_bytes(b"\0" * 0x200 + b"RMCP01")
        apps = tmp / "apps.json"
        subprocess.run([sys.executable, str(SCRIPT), "--gc", str(tmp / "gc"), "--wii", str(tmp / "wii"),
                        "--out", str(tmp / "out"), "--sunshine", str(apps), "--offline"],
                       check=True, capture_output=True)
        rows = [l.split("\t") for l in (tmp / "out" / "library.tsv").read_text().splitlines() if not l.startswith("#")]
        ids = {r[1]: r[4] for r in rows}
        self.assertEqual(ids["Melee"], "GALE01")
        self.assertEqual(ids["Wii Sports"], "RSPP01")
        self.assertEqual(ids["Kart"], "RMCP01")
        data = json.loads(apps.read_text())
        cmd = data["apps"][0]["cmd"]
        self.assertIn("Dolphin.Display.Fullscreen=True", cmd)
        self.assertIn("-b -e", cmd)
        self.assertTrue(any("display-mode.sh" in p["do"] for p in data["apps"][0]["prep-cmd"]))


if __name__ == "__main__":
    unittest.main()
