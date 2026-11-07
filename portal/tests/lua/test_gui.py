"""Headless smoke/fuzz test of the muOS GUI: runs the real Lua code against a mocked LÖVE API (needs `pip install lupa`)."""
import random
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

try:
    from lupa import lua51 as lupa_lua
except ImportError:                                     # pragma: no cover
    lupa_lua = None

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from helpers import ROOT, fresh_home                    # noqa: E402

MOCK = r'''
local noop = function() end
local font = { getWidth=function(self,s) return #tostring(s)*7 end, getHeight=function() return 14 end,
  getWrap=function(self,s,w) local per=math.max(1,math.floor(w/7)); local out={}; s=tostring(s)
    for i=1,#s,per do out[#out+1]=s:sub(i,i+per-1) end; return w,out end }
local img = { getDimensions=function() return 160,224 end, getWidth=function() return 160 end,
  getHeight=function() return 224 end, setFilter=noop }
love = { graphics = setmetatable({ newFont=function() return font end, getDimensions=function() return 640,480 end,
    newCanvas=function() return {} end, newImage=function() return img end },
    { __index = function() return noop end }),
  filesystem = { getSourceBaseDirectory=function() return BASE end, newFileData=function() return {} end },
  math = { triangulate=function() return {{0,0,1,0,1,1}} end,
    newRandomGenerator=function() return { random=function(self,a,b) if a then return math.random(a,b) end return math.random() end } end },
  mouse = { setVisible=noop }, keyboard = { isDown=function() return false end },
  joystick = { getJoysticks=function() return {} end }, timer = { sleep=noop, getTime=function() return os.clock() end },
  event = { quit=function() QUIT=(QUIT or 0)+1 end } }
os.execute = function(c) EXEC=(EXEC or 0)+1 end
package.path = BASE .. "/gui/?.lua;" .. package.path
dofile(BASE .. "/gui/main.lua")
love.load()
'''
PAD = {"l1": "leftshoulder", "r1": "rightshoulder", "select": "back", "up": "dpup", "down": "dpdown",
       "left": "dpleft", "right": "dpright"}
BTNS = ["up", "down", "left", "right", "a", "b", "x", "y", "l1", "r1", "l2", "r2", "select", "start"]


@unittest.skipIf(lupa_lua is None, "lupa not installed")
class GuiTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="spdw-gui-"))
        src = next(p for p in sorted((ROOT / "muos").iterdir()) if p.is_dir())   # "Dolphin RtStream" (was "DolphinStream")
        self.app = self.tmp / src.name
        shutil.copytree(src, self.app)
        rows = ["# kind\ttitle\tapp\tcover\tid"]
        for i in range(37):
            k = "gc" if i % 2 == 0 else "wii"
            rows.append(f"{k}\tGame {i} with a rather long title to test truncation\t{k.upper()} - Game {i}\tcovers/x{i}.png\tG{i:05d}")
        (self.app / "conf" / "library.tsv").write_text("\n".join(rows) + "\n")
        (self.app / "conf" / "last_stream.log").write_text("line1\nline2\n")
        home, prof, core = fresh_home()
        (self.app / "conf" / "profiles.tsv").write_text(prof.export_tsv(core.load_config()))
        self.lua = lupa_lua.LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().BASE = str(self.app)
        self.lua.execute(MOCK)
        self.love = self.lua.globals().love

    def press(self, name):
        self.lua.execute(f"love.gamepadpressed(nil, '{PAD.get(name, name)}')")
        self.love.update(0.016)
        self.love.draw()

    def frames(self, n, dt=0.016):
        for _ in range(n):
            self.love.update(dt)
            self.love.draw()

    def test_boot_animation_renders(self):
        self.frames(320)                                  # > 4.4 s of boot
        self.assertIsNone(self.lua.globals().QUIT)

    def test_controls_screen(self):
        self.frames(320)
        for b in ["start", "down", "down", "a"]:          # START > Controls
            self.press(b)
        for tab in range(3):
            for b in ["down", "down", "right", "left", "up", "y", "r2", "l2"]:
                self.press(b)
            self.press("r1")
        for b in ["select", "b", "b"]:
            self.press(b)
        self.frames(60, 0.3)

    def test_fuzz(self):
        random.seed(1234)
        self.frames(10)
        for i in range(2500):
            self.press(random.choice(BTNS))
            if i % 50 == 0:
                self.frames(3, 0.7)                       # let pollers and timers fire


if __name__ == "__main__":
    unittest.main()
