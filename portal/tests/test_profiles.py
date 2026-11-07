import unittest

from helpers import fresh_home


class ProfilesTest(unittest.TestCase):
    def setUp(self):
        self.home, self.prof, self.core = fresh_home()
        self.cfg = self.core.load_config()
        (self.home / ".config" / "dolphin-emu").mkdir(parents=True)

    def dolphin(self, name):
        return self.home / ".config" / "dolphin-emu" / name

    def test_packaged_profiles_are_valid(self):
        for kind in self.prof.KINDS:
            names = self.prof.available(self.cfg, kind)
            self.assertIn("muos", names, kind)
            for n in names:
                items = self.prof.read(self.cfg, kind, n)
                keys = [k for k, _ in items]
                self.assertEqual(len(keys), len(set(keys)), f"duplicate keys in {kind}/{n}")
                self.assertTrue(any(k == "Device" for k in keys), f"{kind}/{n} has no Device")

    def test_gcpad_z_is_not_on_select(self):
        items = dict(self.prof.read(self.cfg, "GCPad", "muos"))
        self.assertNotEqual(items["Buttons/Z"], items["Buttons/B"])

    def test_hotkeys_never_use_bare_select_or_fullscreen(self):
        for n in ("muos", "muos-minimal"):
            for k, v in self.prof.read(self.cfg, "Hotkeys", n):
                if k == "Device":
                    continue
                self.assertNotEqual(k, "General/Toggle Fullscreen")
                self.assertTrue(v.startswith("MODE&"), f"{n}: {k} = {v} is not on the MODE layer")

    def test_apply_replaces_only_port_one_section(self):
        self.dolphin("GCPadNew.ini").write_text("[GCPad1]\nStale = 1\n[GCPad2]\nKeep = yes\n")
        self.prof.apply(self.cfg)
        text = self.dolphin("GCPadNew.ini").read_text()
        self.assertNotIn("Stale", text)
        self.assertIn("Keep = yes", text)
        self.assertIn("Buttons/A = SOUTH", text)
        self.assertIn("Source = 1", self.dolphin("WiimoteNew.ini").read_text())
        self.assertIn("SIDevice0 = 6", self.dolphin("Dolphin.ini").read_text())

    def test_switching_profile_leaves_no_stale_keys(self):
        self.prof.set_active(self.cfg, "Wiimote", "muos-nunchuk")
        self.prof.apply(self.cfg)
        self.assertIn("Nunchuk/Stick/Up", self.dolphin("WiimoteNew.ini").read_text())
        self.prof.set_active(self.cfg, "Wiimote", "muos")
        self.prof.apply(self.cfg)
        self.assertNotIn("Nunchuk", self.dolphin("WiimoteNew.ini").read_text())

    def test_set_value_validation(self):
        old = self.prof.set_value(self.cfg, "GCPad", "muos", "Buttons/Z", "TL")
        self.assertEqual(old, "THUMBR")
        self.assertEqual(dict(self.prof.read(self.cfg, "GCPad", "muos"))["Buttons/Z"], "TL")
        bad = [
            ("GCPad", "muos", "Evil/Key", "X"),                 # unknown key
            ("GCPad", "other", "Buttons/Z", "TL"),              # not a muos* profile
            ("GCPad", "muos", "Buttons/Z", "TL\nEvil = 1"),     # newline injection
            ("GCPad", "muos", "Buttons/Z", "$(rm -rf)"),        # shell metacharacters
            ("Nope", "muos", "Buttons/Z", "TL"),                # unknown kind
            ("GCPad", "../muos", "Buttons/Z", "TL"),            # path traversal
        ]
        for args in bad:
            with self.assertRaises(ValueError, msg=str(args)):
                self.prof.set_value(self.cfg, *args)

    def test_reset_restores_packaged_copy(self):
        self.prof.set_value(self.cfg, "GCPad", "muos", "Buttons/Z", "TL")
        self.prof.reset(self.cfg, "GCPad", "muos")
        self.assertEqual(dict(self.prof.read(self.cfg, "GCPad", "muos"))["Buttons/Z"], "THUMBR")

    def test_install_never_overwrites_edits(self):
        self.prof.install(self.cfg)
        self.prof.set_value(self.cfg, "GCPad", "muos", "Buttons/Z", "TL")
        self.prof.install(self.cfg)
        self.assertEqual(dict(self.prof.read(self.cfg, "GCPad", "muos"))["Buttons/Z"], "TL")

    def test_export_tsv(self):
        tsv = self.prof.export_tsv(self.cfg).splitlines()
        self.assertEqual(tsv[0], "# profiles.tsv v1")
        self.assertIn("@active\tGCPad\tmuos", tsv)
        rows = [l.split("\t") for l in tsv if not l.startswith(("#", "@"))]
        self.assertTrue(all(len(r) == 4 for r in rows))
        self.assertFalse(any(r[2] == "Device" for r in rows))

    def test_token(self):
        t = self.prof.new_token()
        self.assertEqual(len(t), 10)
        self.assertTrue(t.isalnum() and t == t.lower())
        cfg = {}
        self.assertTrue(self.prof.ensure_token(cfg))
        self.assertFalse(self.prof.ensure_token(cfg))


if __name__ == "__main__":
    unittest.main()
