#!/usr/bin/env python3
from pathlib import Path
import importlib.util
import tempfile

SCRIPT = Path(__file__).resolve().parents[1] / "dolphin-rtcore-muos/app/Dolphin RtUI/tools/rt_profile_merge.py"
SPEC = importlib.util.spec_from_file_location("rt_profile_merge", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(MODULE)


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def value(state, filename, section, key):
    _, flat = state[filename]
    return flat.get((section, key))


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rt-profile-merge-") as tmp:
        root = Path(tmp)
        workshop = root / "workshop"
        profiles = workshop / "rtcoreprofile"
        default = profiles / "Default"
        family = profiles / "RtPrime"
        tier = family / "std"
        custom = profiles / "Custom_One"

        write(default / "Dolphin.ini", """[Core]
CPUCore = 4
Overclock = 0.8

[General]
Layer = default
""")
        write(default / "GFX.ini", """[Settings]
DisableFog = True
""")
        write(family / "rtprofile_data.ini", """[Profile]
Name = RtPrime
""")
        write(family / "Dolphin.ini", """[Core]
Overclock = 1.0

[General]
FamilyEnabled = True
""")
        write(tier / "rtprofile_data.ini", """[Profile]
Name = RtPrime Std
""")
        write(tier / "Dolphin.ini", """[Core]
Overclock = 1.1
CPUThread = False
""")
        write(tier / "GFX.ini", """[Settings]
DisableFog = False
""")
        write(custom / "rtprofile_data.ini", """[Runtime]
RequiresBase = RtPrime/std
""")
        write(custom / "Dolphin.ini", """[Core]
CPUCore = 5
""")
        # The former workshop/base Dolphin.ini copy is deliberately different.
        write(workshop / "base" / "Dolphin.ini", """[Core]
CPUCore = 99
""")
        # GameSettings are a separate native GameINI projection, not a global profile patch.
        write(workshop / "gamesettings" / "GM8E01" / "Performance.ini", """[Core]
CPUCore = 9
""")
        write(workshop / "gamesettings" / "GM8E01" / "rtgameset_data.ini", """[GameSettings]
ActiveConfig = Performance.ini
""")

        layers = MODULE.resolve_profile_layers(default, tier)
        assert layers == [family.resolve(), tier.resolve()], layers

        merged = MODULE.merge_profile_layers(default, tier)
        assert value(merged, "Dolphin.ini", "Core", "CPUCore") == "4"
        assert value(merged, "Dolphin.ini", "Core", "Overclock") == "1.1"
        assert value(merged, "Dolphin.ini", "Core", "CPUThread") == "False"
        assert value(merged, "Dolphin.ini", "General", "Layer") == "default"
        assert value(merged, "Dolphin.ini", "General", "FamilyEnabled") == "True"
        assert value(merged, "GFX.ini", "Settings", "DisableFog") == "False"
        assert value(merged, "Dolphin.ini", "Core", "CPUCore") != "9"

        default_only = MODULE.merge_profile_layers(default, default)
        assert MODULE.resolve_profile_layers(default, default) == []
        assert value(default_only, "Dolphin.ini", "Core", "CPUCore") == "4"

        custom_layers = MODULE.resolve_profile_layers(default, custom)
        assert custom_layers == [family.resolve(), tier.resolve(), custom.resolve()], custom_layers
        custom_merged = MODULE.merge_profile_layers(default, custom)
        assert value(custom_merged, "Dolphin.ini", "Core", "CPUCore") == "5"
        assert value(custom_merged, "Dolphin.ini", "Core", "Overclock") == "1.1"

    print("rt_profile_merge profile-layer tests: OK")


if __name__ == "__main__":
    main()
