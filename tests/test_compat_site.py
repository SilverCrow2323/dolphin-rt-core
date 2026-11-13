from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
import unittest
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "index.html"
APP_DATA = ROOT / "dolphin-rtcore-muos" / "app" / "Dolphin RtUI" / "data"


class ScriptCollector(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.inside = False
        self.external = False
        self.current: list[str] = []
        self.scripts: list[str] = []

    def handle_starttag(self, tag: str, attrs) -> None:
        if tag.lower() == "script":
            self.external = "src" in dict(attrs)
            self.inside = not self.external
            self.current = []

    def handle_data(self, data: str) -> None:
        if self.inside:
            self.current.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "script" and self.inside:
            self.scripts.append("".join(self.current))
            self.inside = False
            self.current = []


class CompatibilitySiteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.html = SITE.read_text(encoding="utf-8")
        cls.manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
        cls.games = json.loads((APP_DATA / "games_data.json").read_text(encoding="utf-8"))
        cls.settings = json.loads((APP_DATA / "gamesettings.json").read_text(encoding="utf-8"))

    def test_website_reads_current_repository_data_files(self):
        self.assertIn("dolphin-rtcore-muos/app/Dolphin%20RtUI/data/games_data.json", self.html)
        self.assertIn("dolphin-rtcore-muos/app/Dolphin%20RtUI/data/gamesettings.json", self.html)
        self.assertNotIn("Dolphin-Core-for-MuOS", self.html)
        self.assertIn("dolphin-rt-core/issues/new", self.html)

    def test_compatibility_json_contract(self):
        self.assertIsInstance(self.games, dict)
        self.assertIsInstance(self.games.get("games"), list)
        self.assertGreater(len(self.games["games"]), 0)
        self.assertIsInstance(self.settings, dict)
        self.assertIsInstance(self.settings.get("settings"), list)
        for group in self.games["games"]:
            self.assertIsInstance(group, dict)
            self.assertIsInstance(group.get("game_info"), dict)
            self.assertIsInstance(group.get("entries"), list)
            for report in group["entries"]:
                for section in ("game_info", "test_review", "test_details", "test_environment"):
                    self.assertIsInstance(report.get(section), dict, f"missing {section} in {group['game_info'].get('game')}")
                self.assertIn(report["game_info"].get("system"), ("GC", "Wii"))

    def test_manifest_icons_are_local_and_present(self):
        self.assertEqual(self.manifest.get("start_url"), "./")
        self.assertEqual(self.manifest.get("scope"), "./")
        for icon in self.manifest.get("icons", []):
            path = icon["src"]
            self.assertTrue(path.startswith("./assets/"), path)
            self.assertTrue((ROOT / path.removeprefix("./")).is_file(), path)

    def test_share_and_retry_controls_are_present(self):
        self.assertIn('id="retryDataBtn"', self.html)
        self.assertIn('id="shareViewBtn"', self.html)
        for key in ("system", "q", "region", "boot", "rating", "sort", "device", "muos"):
            self.assertIn("params.set('"+key+"'", self.html)
            self.assertIn("params.get('"+key+"'", self.html)

    def test_device_and_firmware_filters_are_data_driven(self):
        self.assertIn('id="deviceFilter"', self.html)
        self.assertIn('id="muosFilter"', self.html)
        self.assertIn("populateEnvironmentFilters()", self.html)
        self.assertIn("test_environment?.device", self.html)
        self.assertIn("test_environment?.muos_version", self.html)
        environments = [
            entry.get("test_environment", {})
            for group in self.games["games"]
            for entry in group.get("entries", [])
        ]
        self.assertTrue(any(item.get("device") for item in environments))
        self.assertTrue(any(item.get("muos_version") for item in environments))

    def test_project_pages_build_is_minimal_and_complete(self):
        builder = ROOT / "tools" / "build-compat-site.sh"
        self.assertTrue(builder.is_file())
        with tempfile.TemporaryDirectory(prefix="rtcore-pages-") as tmp:
            output = Path(tmp) / "site"
            result = subprocess.run(
                ["bash", str(builder), str(output)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            expected = {
                ".nojekyll",
                "index.html",
                "manifest.json",
                "sw.js",
                "assets/spdw_symbol.png",
                "assets/gamecube.svg",
                "assets/wii.svg",
            }
            actual = {
                str(path.relative_to(output))
                for path in output.rglob("*")
                if path.is_file()
            }
            self.assertEqual(actual, expected)
            deployed_html = (output / "index.html").read_text(encoding="utf-8")
            self.assertIn('href="./"', deployed_html)
            self.assertNotIn("README.md", actual)
            self.assertFalse((output / "dolphin-rtcore-muos").exists())

    def test_inline_javascript_syntax_when_node_is_available(self):
        node = shutil.which("node")
        if not node:
            self.skipTest("Node.js is not installed on this host")
        parser = ScriptCollector()
        parser.feed(self.html)
        self.assertTrue(parser.scripts, "No inline application script found")
        with tempfile.NamedTemporaryFile("w", suffix=".js", encoding="utf-8") as tmp:
            tmp.write("\n".join(parser.scripts))
            tmp.flush()
            result = subprocess.run([node, "--check", tmp.name], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_wiki_navigation_references_resolve(self):
        wiki = ROOT / "wiki"
        pages = {path.stem for path in wiki.glob("*.md")}
        self.assertIn("Home", pages)
        self.assertIn("_Sidebar", pages)
        self.assertIn("_Footer", pages)
        self.assertGreaterEqual(len(pages), 15)
        for path in wiki.glob("*.md"):
            references = re.findall(r"\[\[([A-Za-z0-9_-]+)\]\]", path.read_text(encoding="utf-8"))
            for target in references:
                self.assertIn(target, pages, f"{path.name} links to missing Wiki page {target}")



    def test_metadata_labels_are_canonical_without_inventing_missing_values(self):
        reports = [
            report
            for group in self.games["games"]
            for report in group["entries"]
        ]
        self.assertGreater(len(reports), 0)
        for report in reports:
            env = report["test_environment"]
            details = report["test_details"]
            device = env.get("device", "")
            muos = env.get("muos_version", "")
            core = details.get("rtcore_version", "")
            profile = details.get("core_profile", "")
            self.assertNotEqual(device, "Unknown Device")
            self.assertNotIn(device, {"RG35XX H", "RG 35XX H", "RG35XXH", "RG34XX SP", "RG-34XX SP"})
            self.assertNotIn(muos, {"Funky Jacaranda", "Funky Jakaranda", "Jacaranda", "2601.1 Funky Jacaranda", "2601.0 Jacaranda"})
            self.assertFalse(muos and not muos.startswith("muOS "))
            self.assertFalse(core and not core.startswith("Dolphin Rt:Core "))
            self.assertNotIn(profile, {"SpeedHack", "standard", "SpeedHack / Default", "All profiles", "All profiles (tested multiple)"})
        # Historic placeholders are empty, not assigned to a guessed device or firmware.
        unknown_devices = sum(not r["test_environment"].get("device") for r in reports)
        unknown_firmware = sum(not r["test_environment"].get("muos_version") for r in reports)
        self.assertGreater(unknown_devices, 0)
        self.assertGreater(unknown_firmware, 0)

    def test_atlas_sections_and_dynamic_catalogs_are_present(self):
        for section in ("catalog", "environment", "core-reference", "methodology", "contribute", "faq"):
            self.assertIn('id="' + section + '"', self.html)
        for element in (
            "portalReports", "portalDeviceKnown", "portalFirmwareKnown",
            "portalCoreKnown", "portalProfileKnown", "portalDeviceGrid",
            "portalFirmwareGrid", "portalCoreGrid", "portalProfileGrid",
        ):
            self.assertIn('id="' + element + '"', self.html)
        self.assertIn("function renderPortalSummary()", self.html)
        self.assertIn("renderPortalSummary();", self.html)
        self.assertIn("Compatibility Atlas", self.html)

    def test_report_form_uses_canonical_metadata_vocabulary(self):
        for value in (
            "muOS 2606.0 · Andromeda",
            "muOS 2601.1 · Funky Jacaranda",
            "Anbernic RG35XX H",
            "Anbernic RG34XX SP",
            "Dolphin Rt:Core 12.5.00 · Arcade",
            "Dolphin Rt:Core 12.0.0 · Kanzentai",
            'data-p="Speedhacks"',
            'data-p="All profiles tested"',
        ):
            self.assertIn(value, self.html)
        self.assertNotIn('data-p="Speed Hack"', self.html)
        self.assertNotIn("<option>2601.1 Funky Jacaranda</option>", self.html)

    def test_pwa_cache_is_bumped_for_atlas_release(self):
        self.assertEqual(self.manifest.get("name"), "Dolphin Rt:Core Compatibility Atlas")
        sw = (ROOT / "sw.js").read_text(encoding="utf-8")
        self.assertIn("rtcore-atlas-v3", sw)
        self.assertNotIn("rtcore-db-v2", sw)

if __name__ == "__main__":
    unittest.main()
