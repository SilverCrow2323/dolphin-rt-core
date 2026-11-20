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
SITE = ROOT / "compatibility.html"
PORTAL_SITE = ROOT / "index.html"
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
        cls.portal_html = PORTAL_SITE.read_text(encoding="utf-8")
        cls.manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
        cls.games = json.loads((APP_DATA / "games_data.json").read_text(encoding="utf-8"))
        cls.runtime_games_path = ROOT / "data" / "games_data.json"
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
        self.assertEqual(self.manifest.get("name"), "Dolphin Rt:Core — Project Portal")
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
                ".nojekyll", "index.html", "compatibility.html", "quick-start.html",
                "profiles.html", "gamesettings.html", "docs.html", "manifest.json", "sw.js",
                "assets/site.css", "assets/site.js", "assets/editorial.css", "assets/magazine.js", "assets/spdw_symbol.png",
                "assets/dolphinrt_icon.png", "assets/dolphin_rtcore_title.png",
                "assets/gamecube.svg", "assets/wii.svg",
                "data/site-gamesettings-index.json", "data/site-profiles.json", "data/site-docs-index.json",
            }
            actual = {
                str(path.relative_to(output))
                for path in output.rglob("*")
                if path.is_file()
            }
            self.assertEqual(actual, expected)
            deployed_html = (output / "index.html").read_text(encoding="utf-8")
            self.assertIn('href="./quick-start.html"', deployed_html)
            self.assertIn('href="./compatibility.html"', deployed_html)
            self.assertIn('./assets/editorial.css', deployed_html)
            self.assertIn('./assets/magazine.js', deployed_html)
            self.assertIn("TOKYO UNDERGROUND SIGNAL", deployed_html)
            self.assertIn('id="magazineReader"', deployed_html)
            self.assertIn('data-mag-next', deployed_html)
            for page in ("quick-start.html", "profiles.html", "gamesettings.html", "docs.html"):
                self.assertTrue((output / page).is_file(), page)
            self.assertIn("1,907", deployed_html)
            catalog = json.loads((output / "data" / "site-gamesettings-index.json").read_text(encoding="utf-8"))
            self.assertEqual(catalog["count"], 1907)
            self.assertEqual(len(catalog["entries"]), 1907)
            self.assertTrue(all((ROOT / entry["path"]).is_file() for entry in catalog["entries"]))
            self.assertFalse(any(entry["filename"].lower() == "rtgameset_data.ini" for entry in catalog["entries"]))
            self.assertEqual(len(json.loads((output / "data" / "site-profiles.json").read_text(encoding="utf-8"))["profiles"]), 19)
            self.assertIn("profileDetailModal", (output / "profiles.html").read_text(encoding="utf-8"))
            self.assertIn("TOKYO 2099 EDITION", (output / "profiles.html").read_text(encoding="utf-8"))
            self.assertEqual(len(json.loads((output / "data" / "site-docs-index.json").read_text(encoding="utf-8"))["entries"]), 51)
            deployed_compatibility = (output / "compatibility.html").read_text(encoding="utf-8")
            self.assertIn("Compatibility Database", deployed_compatibility)
            self.assertIn('id="gameSettingsTab"', deployed_compatibility)
            self.assertIn('id="gamesettings"', deployed_compatibility)
            self.assertIn("data/site-gamesettings-index.json", deployed_compatibility)
            self.assertIn("openIniDetail(entry)", deployed_compatibility)
            self.assertIn('id="iniDetailModal"', deployed_compatibility)
            self.assertIn("syncModalScrollLock()", deployed_compatibility)
            self.assertIn('./assets/editorial.css', deployed_compatibility)
            legacy_gamesettings = (output / "gamesettings.html").read_text(encoding="utf-8")
            self.assertIn("compatibility.html#gamesettings", legacy_gamesettings)
            self.assertIn('id="reportBtn"', deployed_compatibility)
            self.assertNotIn("README.md", actual)
            self.assertFalse((output / "dolphin-rtcore-muos").exists())

    def test_inline_javascript_syntax_when_node_is_available(self):
        node = shutil.which("node")
        if not node:
            self.skipTest("Node.js is not installed on this host")
        parser = ScriptCollector()
        parser.feed(self.html)
        portal_parser = ScriptCollector()
        portal_parser.feed(self.portal_html)
        self.assertTrue(parser.scripts, "No inline compatibility application script found")
        self.assertTrue(portal_parser.scripts, "No inline project portal script found")
        page_scripts = [("compatibility", parser.scripts), ("portal", portal_parser.scripts)]
        for filename in ("quick-start.html", "profiles.html", "gamesettings.html"):
            page_parser = ScriptCollector()
            page_parser.feed((ROOT / filename).read_text(encoding="utf-8"))
            page_scripts.append((filename, page_parser.scripts))
        # Each HTML page is a separate browser document. Do not concatenate
        # independent page scripts into one global lexical scope.
        for page_name, scripts in page_scripts:
            with self.subTest(page=page_name), tempfile.NamedTemporaryFile("w", suffix=".js", encoding="utf-8") as tmp:
                tmp.write("\n".join(scripts))
                tmp.flush()
                result = subprocess.run([node, "--check", tmp.name], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        magazine_script = subprocess.run(
            [node, "--check", str(ROOT / "assets" / "magazine.js")],
            capture_output=True,
            text=True,
        )
        self.assertEqual(magazine_script.returncode, 0, magazine_script.stderr)

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



    def test_runtime_download_copy_matches_bundled_database(self):
        bundled = APP_DATA / "games_data.json"
        self.assertTrue(self.runtime_games_path.is_file())
        self.assertEqual(
            self.runtime_games_path.read_bytes(),
            bundled.read_bytes(),
            "data/games_data.json must match the bundled Rt:UI database byte-for-byte",
        )


    def test_schema_v2_catalogues_and_group_identity(self):
        self.assertEqual(self.games.get("schema_version"), 2)
        catalogues = self.games.get("catalogs", {})
        for key in ("devices", "muos_versions", "rtcore_versions", "core_profiles"):
            self.assertIsInstance(catalogues.get(key), list)
            self.assertTrue(catalogues[key])
            self.assertEqual(len(catalogues[key]), len(set(catalogues[key])))
        identities = set()
        report_count = 0
        for group in self.games["games"]:
            info = group["game_info"]
            identity = (info.get("game_id"), info.get("system"), info.get("region"))
            self.assertNotIn(identity, identities, f"duplicate game group: {identity}")
            identities.add(identity)
            self.assertRegex(info.get("game_id", ""), r"^[A-Z0-9]{6}$")
            self.assertIn(info.get("system"), ("GC", "Wii"))
            self.assertIn(info.get("region"), ("PAL", "NTSC", "NTSC-J"))
            for report in group["entries"]:
                report_count += 1
                for field in ("game_id", "system", "game", "region"):
                    self.assertEqual(report["game_info"].get(field), info.get(field), f"{identity}: inconsistent {field}")
                review = report["test_review"]
                self.assertIsInstance(review.get("rating"), int)
                self.assertGreaterEqual(review["rating"], 0)
                self.assertLessEqual(review["rating"], 5)
                self.assertIn(review.get("boot"), ("YES", "NO", "CRASH"))
                self.assertIn(review.get("playable"), ("YES", "YES WITH ISSUES", "NO"))
        self.assertEqual(report_count, 235)
        self.assertEqual(len(identities), len(self.games["games"]))
        all_reports = [entry for group in self.games["games"] for entry in group["entries"]]
        devices = {entry["test_environment"].get("device", "") for entry in all_reports}
        muos = {entry["test_environment"].get("muos_version", "") for entry in all_reports}
        releases = {entry["test_details"].get("rtcore_version", "") for entry in all_reports}
        profiles = {entry["test_details"].get("core_profile", "") for entry in all_reports}
        self.assertNotIn("RG 35XX H", devices)
        self.assertNotIn("RG35XXH", devices)
        self.assertNotIn("Funky Jacaranda", muos)
        self.assertNotIn("Funky Jakaranda", muos)
        self.assertIn("muOS Jacaranda (version not specified)", muos)
        self.assertNotIn("v11.0.00 (prerelease)", releases)
        self.assertNotIn("v10.6 (pre release)", releases)
        self.assertNotIn("standard", profiles)
        self.assertNotIn("SpeedHack / Default", profiles)
        reported_values = {
            "devices": devices,
            "muos_versions": muos,
            "rtcore_versions": releases,
            "core_profiles": profiles,
        }
        for key, values in reported_values.items():
            missing = {value for value in values if value} - set(catalogues[key])
            self.assertFalse(
                missing,
                f"{key} catalogue omits values used by reports: {sorted(missing)}",
            )
        self.assertIn("Standard", catalogues["core_profiles"])

    def test_canonical_database_normalizer_is_idempotent(self):
        normalizer = ROOT / "tools" / "normalize_games_data.py"
        self.assertTrue(normalizer.is_file())
        result = subprocess.run(
            ["python3", str(normalizer), "--check"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Canonical compatibility data", result.stdout)

    def test_schema_document_matches_dataset(self):
        schema_path = ROOT / "docs" / "schemas" / "games_data.schema.json"
        self.assertTrue(schema_path.is_file())
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        self.assertEqual(schema.get("$schema"), "https://json-schema.org/draft/2020-12/schema")
        self.assertEqual(schema.get("properties", {}).get("schema_version", {}).get("const"), 2)
        self.assertIn("catalogs", schema.get("properties", {}))
        self.assertIn("gameGroup", schema.get("$defs", {}))
        self.assertIn("report", schema.get("$defs", {}))

    def test_issue_templates_are_complete_and_linked(self):
        templates = ROOT / ".github" / "ISSUE_TEMPLATE"
        report = templates / "compatibility-test-report.md"
        bug = templates / "bug_report.yml"
        feature = templates / "feature_request.yml"
        config = templates / "config.yml"
        for path in (report, bug, feature, config):
            self.assertTrue(path.is_file(), str(path))
        report_text = report.read_text(encoding="utf-8")
        bug_text = bug.read_text(encoding="utf-8")
        feature_text = feature.read_text(encoding="utf-8")
        config_text = config.read_text(encoding="utf-8")
        self.assertIn('labels: ["test-report"]', report_text)
        self.assertIn("Machine-readable report", report_text)
        self.assertIn("ROMs, BIOS files, firmware images", report_text)
        self.assertIn("Steps to reproduce", bug_text)
        self.assertIn("Expected behaviour", bug_text)
        self.assertIn("Actual behaviour", bug_text)
        self.assertIn("Acceptance criteria", feature_text)
        self.assertIn("blank_issues_enabled: false", config_text)
        self.assertIn("silvercrow2323.github.io/dolphin-rt-core", config_text)

    def test_report_form_uses_shared_catalogues_and_structured_payload(self):
        for field_id in (
            "rptDevice", "rptMuos", "rptVersion", "rptProfile", "rptDolphinVersion",
            "rptGraphicsBackend", "rptDuration", "rptTestScene", "rptAudio",
            "rptGraphics", "rptInput", "rptStability",
        ):
            self.assertIn('id="' + field_id + '"', self.html)
        self.assertIn("state.catalogs=_gamesCache.catalogs||{}", self.html)
        self.assertIn("populateReportCatalogs()", self.html)
        self.assertIn("URLSearchParams({template:'compatibility-test-report.md'", self.html)
        self.assertIn("test_duration_minutes", self.html)
        self.assertIn("dolphin_version", self.html)
        self.assertIn("fps:hasFps?", self.html)
        self.assertIn("issueUrl.length>7800", self.html)
        self.assertNotIn('id="rptDevices"', self.html)
        self.assertNotIn('id="rptProfiles"', self.html)
        self.assertIn("Never attach ROMs, BIOS, firmware", self.html)

    def test_pwa_cache_is_bumped_for_new_website_shell(self):
        worker = (ROOT / "sw.js").read_text(encoding="utf-8")
        self.assertIn("rtcore-site-v4", worker)
        self.assertIn("'./assets/magazine.js'", worker)
        for page in ("index.html", "compatibility.html", "quick-start.html", "profiles.html", "gamesettings.html", "docs.html"):
            self.assertIn("'./" + page + "'", worker)
        self.assertIn("'./data/site-gamesettings-index.json'", worker)
        self.assertIn("'./data/site-docs-index.json'", worker)
        self.assertIn("raw.githubusercontent.com", worker)
        self.assertNotIn("rtcore-db-v3", worker)

    def test_project_portal_is_the_public_homepage(self):
        self.assertIn("Dolphin Rt:Core — Tokyo 2099 Field Journal", self.portal_html)
        self.assertIn('id="magazineReader"', self.portal_html)
        self.assertIn('class="mag-page cover-page"', self.portal_html)
        self.assertIn('id="magNext"', self.portal_html)
        self.assertIn('id="downloads"', self.portal_html)
        self.assertIn('href="./quick-start.html"', self.portal_html)
        self.assertIn('href="./profiles.html"', self.portal_html)
        self.assertIn('href="./compatibility.html#gamesettings"', self.portal_html)
        self.assertIn('href="./docs.html"', self.portal_html)
        self.assertIn('href="./compatibility.html"', self.portal_html)
        self.assertIn("LATEST STABLE RELEASE", self.portal_html)
        self.assertIn("H700 FIELD ENGINEERING", self.portal_html)
        self.assertIn("ONE ENGINE. MULTIPLE FIRMWARE LAYERS.", self.portal_html)

    def test_portal_uses_live_release_assets_and_explains_package_boundary(self):
        self.assertIn("Dolphin_RtCore_v12_0_0_Andromeda.muxupd", self.portal_html)
        self.assertIn("SPDW_Stream_Portal-4.2.1-x86_64.AppImage", self.portal_html)
        self.assertIn("spdw-stream-portal-4.2.1-1.noarch.rpm", self.portal_html)
        self.assertIn("does not include the Dolphin emulator executable", self.portal_html)
        self.assertIn("releases/latest", (ROOT / "assets" / "site.js").read_text(encoding="utf-8"))
        self.assertIn("data-release-asset", self.portal_html)

    def test_release_feed_updates_every_duplicate_version_and_date_label(self):
        script = (ROOT / "assets" / "site.js").read_text(encoding="utf-8")
        self.assertIn("$$('[data-latest-release]')", script)
        self.assertIn("$$('[data-release-date]')", script)
        self.assertNotIn("const nodes=$('[data-latest-release]')", script)
        self.assertNotIn("const dates=$('[data-release-date]')", script)
        self.assertIn("nodes.map", script)
        self.assertIn("nodes.forEach", script)
        self.assertIn("dates.forEach", script)
        self.assertGreaterEqual(self.portal_html.count("data-latest-release"), 2)
        self.assertGreaterEqual(self.portal_html.count("data-release-date"), 2)

    def test_compatibility_page_returns_to_project_portal(self):
        self.assertIn('href="./"', self.html)
        self.assertIn("Project Portal", self.html)
        self.assertIn("Compatibility Database", self.html)


if __name__ == "__main__":
    unittest.main()


    def test_product_hub_navigation_is_keyboard_and_screen_reader_accessible(self):
        for filename in ("index.html", "quick-start.html", "profiles.html", "gamesettings.html", "docs.html"):
            source = (ROOT / filename).read_text(encoding="utf-8")
            self.assertIn('class="skip-link" href="#main-content"', source, filename)
            self.assertIn('id="main-content" tabindex="-1"', source, filename)
            self.assertIn('aria-controls="site-drawer" aria-expanded="false"', source, filename)
            self.assertIn('role="dialog" aria-modal="true"', source, filename)
            self.assertIn('aria-hidden="true" inert', source, filename)
        stylesheet = (ROOT / "assets" / "site.css").read_text(encoding="utf-8")
        script = (ROOT / "assets" / "site.js").read_text(encoding="utf-8")
        self.assertIn(":focus-visible", stylesheet)
        self.assertIn(".skip-link:focus-visible", stylesheet)
        self.assertIn("visibility:hidden", stylesheet)
        self.assertIn("e.key!=='Tab'", script)
        self.assertIn("toggleAttribute('inert',!open)", script)
        self.assertIn("drawerOpener.focus()", script)
        self.assertIn("aria-current","".join((ROOT / filename).read_text(encoding="utf-8") for filename in ("index.html", "quick-start.html", "profiles.html", "gamesettings.html", "docs.html")) + script)

    def test_product_hub_has_real_navigation_and_motion_system(self):
        for filename in ("index.html", "quick-start.html", "profiles.html", "gamesettings.html", "docs.html"):
            source = (ROOT / filename).read_text(encoding="utf-8")
            self.assertIn("./assets/site.css", source, filename)
            self.assertIn("./assets/site.js", source, filename)
            self.assertIn("data-open-drawer", source, filename)
            self.assertIn("prefers-reduced-motion", (ROOT / "assets" / "site.css").read_text(encoding="utf-8"))
        self.assertIn("IntersectionObserver", (ROOT / "assets" / "site.js").read_text(encoding="utf-8"))
        self.assertIn("Rt:System Status Center", (ROOT / "quick-start.html").read_text(encoding="utf-8"))
        self.assertIn("SDL/0/muOS-Keys", (ROOT / "quick-start.html").read_text(encoding="utf-8"))
        self.assertIn("Video_Hacks", (ROOT / "profiles.html").read_text(encoding="utf-8"))
        self.assertIn("GameSettings Library", (ROOT / "gamesettings.html").read_text(encoding="utf-8"))

    def test_all_modal_backdrops_close_only_when_the_backdrop_is_clicked(self):
        for modal, closer in (
            ("gameModal", "closeGameModal"),
            ("reportModal", "closeReportModal"),
            ("gsModal", "closeGameSettings"),
        ):
            expected = f"$('{modal}').addEventListener('click',e=>{{if(e.target===e.currentTarget){closer}();}});"
            self.assertIn(expected, self.html)

        self.assertIn(
            "document.getElementById('iniDetailModal').addEventListener('click',event=>{if(event.target===event.currentTarget)closeIniDetail();});",
            self.html,
        )
        self.assertIn(
            "document.addEventListener('keydown',e=>{if(e.key!=='Escape')return;if($('iniDetailModal')?.classList.contains('show'))return;if($('gsModal').classList.contains('show'))closeGameSettings();else if($('reportModal').classList.contains('show'))closeReportModal();else if($('gameModal').classList.contains('show'))closeGameModal();});",
            self.html,
        )
        self.assertIn(
            "document.addEventListener('keydown',event=>{if(event.key==='Escape'&&document.getElementById('iniDetailModal').classList.contains('show'))closeIniDetail();});",
            self.html,
        )
        self.assertLess(
            self.html.index("if($('iniDetailModal')?.classList.contains('show'))return;"),
            self.html.index("if($('gsModal').classList.contains('show'))closeGameSettings();"),
        )
        self.assertNotIn(
            "document.addEventListener('keydown',event=>{if(event.key==='Escape'&&document.getElementById('iniDetailModal').classList.contains('show'))closeIniDetail();});",
            self.html[self.html.index("document.addEventListener('keydown',event=>{if(event.key==='Escape'&&document.getElementById('iniDetailModal').classList.contains('show'))closeIniDetail();});")+1:],
        )
        profiles = (ROOT / "profiles.html").read_text(encoding="utf-8")
        self.assertIn(
            "document.getElementById('profileDetailModal').addEventListener('click',e=>{if(e.target===e.currentTarget)close()});",
            profiles,
        )


    def test_profile_and_ini_detail_dialogs_have_accessible_focus_management(self):
        profiles = (ROOT / "profiles.html").read_text(encoding="utf-8")
        compatibility = (ROOT / "compatibility.html").read_text(encoding="utf-8")
        site_js = (ROOT / "assets" / "site.js").read_text(encoding="utf-8")

        self.assertIn('aria-labelledby="profileDetailTitle"', profiles)
        self.assertIn('aria-describedby="profileDetailDescription"', profiles)
        self.assertIn('id="profileDetailTitle"', profiles)
        self.assertIn('id="profileDetailDescription"', profiles)
        self.assertIn('returnFocus=trigger||document.activeElement', profiles)
        self.assertIn('if(target&&target.isConnected)target.focus()', profiles)

        self.assertIn('aria-labelledby="iniDetailTitle"', compatibility)
        self.assertIn('aria-describedby="iniDetailMeta"', compatibility)
        self.assertIn('modal._returnFocus=document.activeElement', compatibility)
        self.assertIn('if(target&&target.isConnected)target.focus()', compatibility)

        self.assertIn("event.key!=='Tab'", site_js)
        self.assertIn("$$('.detail-overlay.show')", site_js)
        self.assertIn('document.activeElement===last', site_js)
        self.assertIn('document.activeElement===first', site_js)
