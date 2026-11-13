#!/usr/bin/env python3
from pathlib import Path
import subprocess
import sys
import tempfile

SCRIPT = (
    Path(__file__).resolve().parents[1]
    / "dolphin-rtcore-muos/app/Dolphin RtUI/tools/project_gamesettings.py"
)


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rt-gamesettings-project-") as tmp:
        root = Path(tmp)
        source = root / "workshop" / "gamesettings" / "GM8E01" / "Arcade.ini"
        previous = root / "user" / "GameSettings" / "GM8E01.ini"
        output = root / "user" / "GameSettings" / "GM8E01.ini.rt-tmp"

        source.parent.mkdir(parents=True)
        previous.parent.mkdir(parents=True)
        source.write_text(
            """[Core]
CPUThread = False
Overclock = 0.9

[Gecko]
$Workshop Manual Code
12345678 00000000

[Video_Settings]
AspectRatio = 2
""",
            encoding="utf-8",
        )
        previous.write_text(
            """[Core]
CPUThread = True
Overclock = 1.2
RuntimeOnly = MustNotLeak

[Gecko]
$[Rt] Active Speed Patch
04000000 12345678
04000000 87654321
$Workshop Manual Code
99999999 00000001
$Old Manual Runtime Code
11111111 22222222

[Gecko_Enabled]
$[Rt] Active Speed Patch

[ActionReplay]
$[Rt] Active AR Patch
ABCDEF01 00000001

[ActionReplay_Enabled]
$[Rt] Active AR Patch
""",
            encoding="utf-8",
        )

        subprocess.run(
            [sys.executable, str(SCRIPT), str(source), str(previous), str(output)],
            check=True,
        )
        result = output.read_text(encoding="utf-8")

        assert "CPUThread = False" in result
        assert "Overclock = 0.9" in result
        assert "RuntimeOnly = MustNotLeak" not in result
        assert "$Workshop Manual Code" in result
        assert "$Old Manual Runtime Code" in result
        assert "$Workshop Manual Code" in result
        assert result.count("$Workshop Manual Code") == 1
        assert "$[Rt] Active Speed Patch" in result
        assert "04000000 12345678" in result and "04000000 87654321" in result
        assert "$[Rt] Active AR Patch" in result
        assert "AspectRatio = 2" in result

        # A new launch with no generated Rt blocks must not retain previous ones.
        previous.write_text("[Core]\nCPUThread = True\n", encoding="utf-8")
        subprocess.run(
            [sys.executable, str(SCRIPT), str(source), str(previous), str(output)],
            check=True,
        )
        clean = output.read_text(encoding="utf-8")
        assert "$[Rt] Active Speed Patch" not in clean
        assert "$[Rt] Active AR Patch" not in clean

    print("GameSettings projection and Rt cheat preservation tests: OK")


if __name__ == "__main__":
    main()
