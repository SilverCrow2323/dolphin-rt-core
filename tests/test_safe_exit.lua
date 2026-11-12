#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;dolphin-rtcore-muos/app/Dolphin RtUI/?/init.lua;" .. package.path

local SafeExit = require("core.safe_exit")
local original = SafeExit.PATH
local path = os.tmpname()
os.remove(path)
SafeExit.PATH = path

local function expect(ok, message)
    if not ok then error(message or "assertion failed", 2) end
end

expect(#SafeExit.load_raw() == 2 and SafeExit.load_raw()[1] == 8 and SafeExit.load_raw()[2] == 9,
    "missing config must default to START + SELECT joydev indices")
local default_names = SafeExit.default_names()
expect(default_names[1] == "SELECT" and default_names[2] == "START", "default names must be START + SELECT")

local ok, saved = SafeExit.save_names({ "MENU" })
expect(ok and saved == "MENU", "single MENU must be accepted")
local raw = SafeExit.load_raw()
expect(#raw == 1 and raw[1] == 10, "M must persist as joydev button 10")

ok, saved = SafeExit.save_names({ "START", "SELECT" })
expect(ok, "two-button combination must be accepted")
raw = SafeExit.load_raw()
expect(#raw == 2 and raw[1] == 8 and raw[2] == 9, "START + SELECT must persist as joydev indices 8 + 9")
local names = SafeExit.load_names()
expect(names[1] == "SELECT" and names[2] == "START", "combo labels must round-trip")

ok = SafeExit.save_names({ "START" })
expect(not ok, "single START must be rejected; only MENU may be a single-button exit")
ok = SafeExit.save_names({ "MENU", "SELECT", "START", "L1", "R1" })
expect(not ok, "more than four buttons must be rejected")
ok = SafeExit.save_names({ "NOT_A_BUTTON", "START" })
expect(not ok, "unknown logical buttons must be rejected")

ok = SafeExit.reset()
expect(ok, "reset must succeed")
raw = SafeExit.load_raw()
expect(#raw == 1 and raw[1] == 8 and raw[2] == 9, "reset must restore START + SELECT")

os.remove(path)
SafeExit.PATH = original
print("Safe Exit tests: OK")
