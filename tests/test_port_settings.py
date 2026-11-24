#!/usr/bin/env python3
"""Contract tests for the KNULLI/ROCKNIX EmulationStation integration."""
from pathlib import Path
import re
import subprocess
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
K = ROOT / "dolphin-rtcore-k"
R = ROOT / "dolphin-rtcore-r"


def load_options(path):
    features = {}
    choices = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw or raw.startswith("#"):
            continue
        fields = raw.split("\t")
        if fields[0] == "F":
            _, group, key, label, description = fields
            if key in features:
                raise AssertionError(f"duplicate option key in {path}: {key}")
            features[key] = (group, label, description)
            choices[key] = []
        elif fields[0] == "C":
            _, key, value, label, override = fields
            if key not in features:
                raise AssertionError(f"choice references unknown option {key} in {path}")
            choices[key].append((value, label, override))
        else:
            raise AssertionError(f"unknown options.tsv row in {path}: {raw}")
    return features, choices


class PortSettingsContractTests(unittest.TestCase):
    def test_knulli_and_rocknix_expose_independent_main_menu_systems(self):
        expected = {"wii": ("wii", "@ROMS@/wii"), "gamecube": ("gamecube", "@ROMS@/gamecube")}
        for platform in (K, R):
            root = ET.parse(platform / "es" / "es_systems_rtcore.cfg.in").getroot()
            systems = {item.findtext("name"): item for item in root.findall("system")}
            self.assertEqual(set(systems), set(expected), platform.name)
            for name, (theme, rom_path) in expected.items():
                self.assertEqual(systems[name].findtext("theme"), theme)
                self.assertEqual(systems[name].findtext("path"), rom_path)
                self.assertEqual(systems[name].findtext("platform"), "wii" if name == "wii" else "gc")

    def test_knulli_and_rocknix_share_the_per_game_option_catalog(self):
        k_features, k_choices = load_options(K / "config" / "options.tsv")
        r_features, r_choices = load_options(R / "config" / "options.tsv")
        self.assertEqual(len(k_features), 23)
        self.assertEqual(len(r_features), 24)
        self.assertEqual(set(r_features) - set(k_features), {"rtc_platform"})
        self.assertEqual(k_features, {key: r_features[key] for key in k_features})
        for features, choices in ((k_features, k_choices), (r_features, r_choices)):
            self.assertTrue(all(choices[key] for key in features))
            for key, values in choices.items():
                ids = [item[0] for item in values]
                self.assertEqual(len(ids), len(set(ids)), key)
        self.assertEqual(
            {group for group, _, _ in k_features.values()},
            {"GAME", "CONTROLS", "GRAPHICS", "PERFORMANCE", "AUDIO"},
        )

    def test_knulli_installer_generates_the_menu_and_launcher_from_the_same_tsv(self):
        template = (K / "es" / "es_features_rtcore.cfg.in").read_text(encoding="utf-8")
        installer = (K / "install.sh").read_text(encoding="utf-8")
        launcher = (K / "bin" / "rtcore-k.sh").read_text(encoding="utf-8")
        self.assertIn("@SHARED_FEATURES@", template)
        self.assertIn('OPTIONS_TSV="$ROOT/config/options.tsv"', installer)
        self.assertIn('t="${t//@SHARED_FEATURES@/', installer)
        self.assertIn('OPTS_TSV="$ROOT/config/options.tsv"', launcher)
        self.assertIn('EXTRA+=(-C "$ov")', launcher)
        self.assertIn('submenu="%s"', installer)
        for group in ("GAME", "CONTROLS", "GRAPHICS", "PERFORMANCE", "AUDIO"):
            self.assertIn(group, (K / "config" / "options.tsv").read_text(encoding="utf-8"))

    def test_rocknix_options_are_grouped_and_platform_selector_is_separate(self):
        generator = (R / "tools" / "es-features.sh").read_text(encoding="utf-8")
        launcher = (R / "bin" / "rtcore-r.sh").read_text(encoding="utf-8")
        self.assertIn('submenu="%s"', generator)
        self.assertIn('OPTS_TSV="$ROOT/config/options.tsv"', launcher)
        self.assertIn('rtc_platform', (R / "config" / "options.tsv").read_text(encoding="utf-8"))
        self.assertIn('PLATFORM_WANT="$(opt rtc_platform auto)"', launcher)

    def test_persistent_art_book_next_logo_assets_and_installers_exist(self):
        self.assertTrue((K / "theme" / "logos" / "logo_wii.png").is_file())
        self.assertTrue((K / "theme" / "logos" / "logo_gamecube.png").is_file())
        for name in ("wii.svg", "gamecube.svg"):
            asset = R / "theme" / "logos" / name
            self.assertTrue(asset.is_file())
            self.assertIn("<svg", asset.read_text(encoding="utf-8"))
        self.assertIn("theme-customizations/art-book-next/logos", (K / "theme" / "install-theme.sh").read_text(encoding="utf-8"))
        self.assertIn("roms/rocknix/theme-customizations/art-book-next/logos", (R / "theme" / "install-theme.sh").read_text(encoding="utf-8"))
        self.assertIn("--userdata \"$UD\"", (K / "install.sh").read_text(encoding="utf-8"))
        self.assertIn("--userdata \"$UD\"", (R / "install.sh").read_text(encoding="utf-8"))

    def test_gui_placement_is_firmware_specific_and_not_a_false_launcher(self):
        k_ui = (K / "ui" / "README.md").read_text(encoding="utf-8")
        r_ui = (R / "ui" / "README.md").read_text(encoding="utf-8")
        self.assertIn("/userdata/roms/tools/", k_ui)
        self.assertIn("/storage/roms/ports/", r_ui)
        self.assertIn("not shipped", k_ui.lower())
        self.assertIn("not shipped", r_ui.lower())

    def test_modified_shell_entrypoints_parse(self):
        scripts = (
            K / "install.sh",
            K / "uninstall.sh",
            K / "bin" / "rtcore-k.sh",
            K / "theme" / "install-theme.sh",
            R / "install.sh",
            R / "uninstall.sh",
            R / "bin" / "rtcore-r.sh",
            R / "theme" / "install-theme.sh",
            R / "tools" / "es-features.sh",
        )
        for script in scripts:
            result = subprocess.run(
                ["bash", "-n", str(script)],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, f"{script}: {result.stderr}")


if __name__ == "__main__":
    unittest.main()
