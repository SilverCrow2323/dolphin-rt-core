#!/usr/bin/env python3
"""Static contract tests for the Rt:Stream local web companion."""
import ast
import pathlib
import unittest

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

    def test_python_syntax(self):
        ast.parse(self.backend)

    def test_localhost_only(self):
        self.assertIn('ThreadingHTTPServer(("127.0.0.1"', self.backend)

    def test_mutations_require_session_token(self):
        self.assertIn('X-RtStream-Token', self.backend)
        self.assertIn('secrets.token_urlsafe', self.backend)

    def test_sftp_keeps_host_key_verification(self):
        self.assertIn('-oStrictHostKeyChecking=yes', self.backend)
        self.assertNotIn('StrictHostKeyChecking=no', self.backend)

    def test_sftp_test_browse_upload(self):
        for op in ('sftp-test', 'sftp-list', 'sftp-upload'):
            self.assertIn(op, self.backend)

    def test_upload_is_limited_to_configured_rom_folders(self):
        self.assertIn('ROM must be inside a configured library folder.', self.backend)

    def test_existing_remote_rom_requires_explicit_overwrite(self):
        self.assertIn("Target already exists. Confirm overwrite to replace it.", self.backend)

    def test_sftp_does_not_store_passwords(self):
        self.assertNotIn('password', self.backend.lower())

    def test_ui_has_core_sections(self):
        for section in ('overview', 'library', 'device', 'streaming', 'system'):
            self.assertIn('id="'+section+'"', self.html)

    def test_library_sources_are_editable(self):
        self.assertIn('save-sources', self.backend)
        self.assertIn('gc_paths', self.backend)
        self.assertIn('id="gcpaths"', self.html)
        self.assertIn('id="wiipaths"', self.html)

    def test_separate_stream_and_file_channels(self):
        self.assertIn('Sunshine transports video and input', self.html)
        self.assertIn('SFTP are separate', self.html)

    def test_responsive_and_authenticated_frontend(self):
        self.assertIn('@media(max-width:720px)', self.css)
        self.assertIn('X-RtStream-Token', self.js)

    def test_static_asset_routes_are_allowlisted(self):
        self.assertIn('("/","/app.css","/app.js")', self.backend)

if __name__ == "__main__":
    unittest.main()
