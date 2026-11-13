#!/usr/bin/env python3
"""Regression tests for the Rt:Stream local PC Companion."""
import ast
import importlib.util
import pathlib
import sys
import types
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / "pc-stream/usr/lib/spdw-stream-portal"
WEB = APP / "web"

class WebPortalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.backend = (APP / "web_portal.py").read_text(encoding="utf-8")
        cls.html = (WEB / "index.html").read_text(encoding="utf-8")
        cls.js = (WEB / "app.js").read_text(encoding="utf-8")
        cls.css = (WEB / "app.css").read_text(encoding="utf-8")
        cls.ci = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        fake_core = types.ModuleType("spdw_stream_core")
        fake_profiles = types.ModuleType("profiles")
        with patch.dict(sys.modules, {"spdw_stream_core": fake_core, "profiles": fake_profiles}):
            spec = importlib.util.spec_from_file_location("rtstream_web_portal_tested", APP / "web_portal.py")
            cls.portal = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cls.portal)

    def test_python_syntax(self):
        ast.parse(self.backend)

    def test_localhost_only_and_session_token(self):
        self.assertIn('ThreadingHTTPServer(("127.0.0.1"', self.backend)
        self.assertIn("secrets.token_urlsafe", self.backend)
        self.assertIn("X-RtStream-Token", self.backend)

    def test_sftp_uses_strict_known_hosts(self):
        self.assertIn("-oStrictHostKeyChecking=yes", self.backend)
        self.assertNotIn("StrictHostKeyChecking=no", self.backend)

    def test_sftp_has_test_browse_upload_download_and_delete(self):
        for op in ("sftp-test", "sftp-list", "sftp-upload", "sftp-download", "sftp-delete"):
            self.assertIn('op == "' + op + '"', self.backend)

    def test_rom_upload_is_limited_to_configured_pc_library_roots(self):
        self.assertIn("ROM must be inside a configured library folder.", self.backend)

    def test_transfer_supports_resume_and_progress_jobs(self):
        self.assertIn('"put " + ("-a " if resume else "")', self.backend)
        self.assertIn('"get " + ("-a " if resume else "")', self.backend)
        self.assertIn("progress_known", self.backend)
        self.assertIn('path == "/api/jobs"', self.backend)

    def test_existing_remote_file_requires_resume_or_overwrite(self):
        self.assertIn("Target already exists. Choose Resume or confirm overwrite.", self.backend)

    def test_discovery_uses_known_neighbors_and_tailscale_peers(self):
        self.assertIn('["ip", "-j", "neigh", "show"]', self.backend)
        self.assertIn('["tailscale", "status", "--json"]', self.backend)
        self.assertIn("never sweep subnets", self.backend)

    def test_compatibility_uses_canonical_dataset(self):
        self.assertIn("/data/games_data.json", self.backend)
        self.assertIn('"schema_version"', self.backend) 
        self.assertIn("refresh-compatibility", self.backend)

    def test_profile_and_stream_settings_endpoints(self):
        for item in ("set-profile", "apply-profiles", "save-stream-settings"):
            self.assertIn(item, self.backend)

    def test_host_header_and_origin_are_exactly_local(self):
        self.assertTrue(self.portal.local_host_allowed("127.0.0.1:8766"))
        self.assertTrue(self.portal.local_host_allowed("localhost:8766"))
        self.assertFalse(self.portal.local_host_allowed("localhost.attacker.invalid:8766"))
        self.assertTrue(self.portal.local_origin_allowed("http://localhost:8766"))
        self.assertFalse(self.portal.local_origin_allowed("http://localhost.attacker.invalid:8766"))
        self.assertFalse(self.portal.local_origin_allowed("https://localhost:8766"))
        self.assertFalse(self.portal.local_origin_allowed("http://user@localhost:8766"))

    def test_muos_ci_archive_is_explicitly_ui_only_and_generated_in_runner_temp(self):
        self.assertIn("DOLPHIN_UI_ONLY=1", self.ci)
        self.assertIn("muos-ui-only", self.ci)
        self.assertIn("muxupd-ui-only-validation", self.ci)
        self.assertNotIn("verify-muxupd.sh dist/*.muxupd", self.ci)

    def test_sftp_test_checks_configured_rom_directory(self):
        cfg = {"device": {"rom_path": "/mnt/roms"}}
        with patch.object(self.portal.core, "load_config", return_value=cfg, create=True):
            with patch.object(self.portal, "sftp_canonical_directory", return_value="/mnt/roms") as resolve:
                result = self.portal.action({"action": "sftp-test"})
        self.assertEqual(result["rom_path"], "/mnt/roms")
        self.assertIn("Connected", result["message"])
        resolve.assert_called_once_with(cfg, "/mnt/roms")

    def test_remote_root_rejects_filesystem_root(self):
        with self.assertRaisesRegex(ValueError, "filesystem root is not allowed"):
            self.portal._remote_root({"device": {"rom_path": "/"}})

    def test_remote_path_rejects_traversal(self):
        self.assertEqual(self.portal.remote_path("/mnt/roms/GC/Game.iso"), "/mnt/roms/GC/Game.iso")
        with self.assertRaises(ValueError):
            self.portal.remote_path("/mnt/roms/../etc/passwd")

    def test_sftp_canonical_directory_uses_portable_cd_pwd(self):
        cfg = {"device": {"rom_path": "/mnt/roms"}}
        with patch.object(self.portal, "sftp_command", return_value="Remote working directory: /mnt/roms/GC") as run:
            self.assertEqual(
                self.portal.sftp_canonical_directory(cfg, "/mnt/roms/GC"),
                "/mnt/roms/GC",
            )
        self.assertEqual(run.call_args.args[1], ['cd "/mnt/roms/GC"', "pwd"])

    def test_sftp_canonical_root_allows_device_root_symlink(self):
        cfg = {"device": {"rom_path": "/mnt/roms"}}
        with patch.object(self.portal, "sftp_command", side_effect=[
            "Remote working directory: /data/games",
            "Remote working directory: /data/games/GC",
        ]):
            self.assertEqual(
                self.portal.confined_remote_directory(cfg, "/mnt/roms/GC"),
                ("/data/games", "/data/games/GC"),
            )

    def test_sftp_rejects_directory_symlink_escape_outside_rom_root(self):
        cfg = {"device": {"rom_path": "/mnt/roms"}}
        with patch.object(self.portal, "sftp_command", side_effect=[
            "Remote working directory: /mnt/roms",
            "Remote working directory: /etc",
        ]):
            with self.assertRaisesRegex(ValueError, "escapes the configured ROM directory"):
                self.portal.confined_remote_directory(cfg, "/mnt/roms/GC/outside")

    def test_sftp_rejects_file_symlink_entries(self):
        cfg = {"device": {"rom_path": "/mnt/roms"}}
        with patch.object(self.portal, "sftp_command", side_effect=[
            "Remote working directory: /mnt/roms",
            "Remote working directory: /mnt/roms",
            "lrwxrwxrwx 1 owner group 11 Jan 1 12:00 Game.iso -> /etc/passwd",
        ]):
            with self.assertRaisesRegex(ValueError, "Symbolic links are not allowed"):
                self.portal.confined_remote_file(cfg, "/mnt/roms/Game.iso")

    def test_sftp_confined_regular_file_path(self):
        cfg = {"device": {"rom_path": "/mnt/roms"}}
        with patch.object(self.portal, "sftp_command", side_effect=[
            "Remote working directory: /mnt/roms",
            "Remote working directory: /mnt/roms/GC",
            "-rw-r--r-- 1 owner group 12345 Jan 1 12:00 Game.iso",
        ]):
            root, path, entry = self.portal.confined_remote_file(cfg, "/mnt/roms/GC/Game.iso")
        self.assertEqual(root, "/mnt/roms")
        self.assertEqual(path, "/mnt/roms/GC/Game.iso")
        self.assertEqual(entry["type"], "file")

    def test_remote_rom_extension_is_checked_before_canonical_confinement(self):
        cfg = {"device": {"rom_path": "/mnt/roms"}}
        self.assertEqual(
            self.portal._validate_remote_rom(cfg, "/data/games/GC/Game.iso"),
            "/data/games/GC/Game.iso",
        )
        with self.assertRaises(ValueError):
            self.portal._validate_remote_rom(cfg, "/data/games/GC/not-a-rom.txt")

    def test_remote_root_prefix_boundary(self):
        self.assertTrue(self.portal.within_remote("/mnt/roms", "/mnt/roms/GC/game.iso"))
        self.assertFalse(self.portal.within_remote("/mnt/roms", "/mnt/roms-backup/game.iso"))

    def test_remote_listing_preserves_spaces_and_types(self):
        raw = (
            "-rw-r--r-- 1 owner group 12345 Jan 1 12:00 Super Mario Sunshine.iso\n"
            "drwxr-xr-x 2 owner group 4096 Jan 1 12:00 GameCube Collection\n"
            "-rw-r--r-- 1 owner group 8 Jan 1 12:00 .hidden"
        )
        rows = self.portal._parse_sftp_listing(raw, "/roms")
        self.assertEqual(rows[0]["name"], "GameCube Collection")
        file_row = next(x for x in rows if x["name"] == "Super Mario Sunshine.iso")
        self.assertEqual(file_row["path"], "/roms/Super Mario Sunshine.iso")
        self.assertEqual(file_row["size"], 12345)
        self.assertEqual(file_row["type"], "file")

    def test_ui_has_all_core_sections(self):
        for section in ("overview", "library", "device", "streaming", "system"):
            self.assertIn('id="' + section + '"', self.html)

    def test_ui_exposes_remote_browser_discovery_and_transfer_queue(self):
        for element in ("discovery-results", "remote-entries", "jobs", "local", "upload"):
            self.assertIn('id="' + element + '"', self.html)

    def test_ui_exposes_compatibility_and_profiles(self):
        for element in ("refresh-compat", "profile-gcpad", "profile-wiimote", "profile-hotkeys", "save-stream-settings"):
            self.assertIn('id="' + element + '"', self.html)
        self.assertIn("Rt:Core", self.html)

    def test_ui_documents_separate_streaming_and_file_channels(self):
        self.assertIn("Sunshine handles video and input", self.html)
        self.assertIn("SFTP is a third, optional channel", self.html)

    def test_responsive_ui_and_authenticated_frontend(self):
        self.assertIn("@media(max-width:720px)", self.css)
        self.assertIn("X-RtStream-Token", self.js)
        self.assertIn("setInterval(refreshJobs", self.js)

    def test_static_routes_are_allowlisted(self):
        self.assertIn('path not in ("/", "/app.css", "/app.js")', self.backend)

if __name__ == "__main__":
    unittest.main()
