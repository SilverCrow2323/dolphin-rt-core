"""Shared test helpers: every test runs against a throw-away HOME so the real Dolphin config is never touched."""
import importlib
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PORTAL = ROOT / "pc" / "portal"


def fresh_home():
    """Point HOME at a temp dir and (re)import the modules that read it at import time."""
    home = tempfile.mkdtemp(prefix="spdw-test-")
    os.environ["HOME"] = home
    os.environ.pop("XDG_CONFIG_HOME", None)
    if str(PORTAL) not in sys.path:
        sys.path.insert(0, str(PORTAL))
    for m in ("profiles", "spdw_stream_core"):
        sys.modules.pop(m, None)
    prof = importlib.import_module("profiles")
    core = importlib.import_module("spdw_stream_core")
    return Path(home), prof, core
