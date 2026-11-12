#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;dolphin-rtcore-muos/app/Dolphin RtUI/?/init.lua;" .. package.path

local AI = require("core.app_input")
AI.init()
local SafeExit = require("core.safe_exit")
local original = SafeExit.PATH
local path = os.tmpname()
os.remove(path)
SafeExit.PATH = path

local function expect(ok, message)
    if not ok then error(message or "assertion failed", 2) end
end

local ok, saved = SafeExit.save_names({ "MENU" })
expect(ok and saved == "MENU", "single MENU must be accepted")
local raw = SafeExit.load_raw()
expect(#raw == 1 and raw[1] == 8, "default M must persist as joydev button 8")

ok, saved = SafeExit.save_names({ "START", "SELECT" })
expect(ok, "two-button combination must be accepted")
raw = SafeExit.load_raw()
expect(#raw == 2 and raw[1] == 6 and raw[2] == 7, "combo must persist as sorted raw button indices")
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
expect(#raw == 1 and raw[1] == 8, "reset must restore M")

os.remove(path)
SafeExit.PATH = original
print("Safe Exit tests: OK")
