#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local FS = require("core.fs")
local JSON = require("core.json")
local saved
local persisted
FS.read = function() return saved and JSON.encode(saved) or nil end
FS.mkdir_p = function() end
FS.atomic_write = function(_, content) persisted = content; return true end

local AppInput = require("core.app_input")
local function expect(value, message)
    if not value then error(message or "assertion failed", 2) end
end

AppInput.init()
local pad = AppInput.pad_map()
expect(pad.A == 1 and pad.B == 0, "SDL defaults must keep A=1 and B=0")
expect(pad.X == 2 and pad.Y == 3, "SDL face-button defaults must match Dolphin Button IDs")
expect(pad.L1 == 4 and pad.R1 == 5, "shoulder defaults must match Dolphin SDL IDs")
expect(pad.SELECT == 6 and pad.START == 7 and pad.MENU == 8,
    "system controls must match Dolphin SDL IDs")
expect(pad.L2 == 9 and pad.R2 == 12 and pad.L3 == 11, "trigger/stick defaults must match Dolphin SDL IDs")
expect(AppInput.from_raw(1) == "A" and AppInput.from_raw(0) == "B",
    "raw SDL buttons must resolve to the matching logical face buttons")

-- The mistaken joydev defaults must migrate back to the SDL profile defaults.
saved = { active_device = "RG35XX H", pad = {
    A=0, B=1, X=2, Y=3, L1=4, R1=5, L2=6, R2=7,
    SELECT=8, START=9, MENU=10, L3=11, R3=12,
} }
AppInput.init()
pad = AppInput.pad_map()
expect(pad.A == 1 and pad.B == 0 and pad.L2 == 9 and pad.R2 == 12,
    "mistaken joydev defaults must be replaced with the SDL defaults")
expect(pad.SELECT == 6 and pad.START == 7 and pad.MENU == 8,
    "system buttons must be migrated back to SDL IDs")
expect(AppInput.active_device() == "RG35XX H",
    "device selection must survive the default-map migration")

-- Real user remaps differ from both built-in maps and must be retained.
saved = { pad = { A=12, B=0, X=2, Y=3, L1=4, R1=5, L2=10,
    R2=12, SELECT=6, START=7, MENU=8 } }
AppInput.init()
pad = AppInput.pad_map()
expect(pad.A == 12 and pad.L2 == 10,
    "custom values must be preserved during migration")

print("AppInput SDL mapping tests: PASS")
