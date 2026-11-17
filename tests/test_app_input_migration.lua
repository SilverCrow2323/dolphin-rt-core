#!/usr/bin/env luajit
-- App Pad persistence migration: keep SDL IDs separate from Linux joydev indices.
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local FS = require("core.fs")
local JSON = require("core.json")
local saved, persisted

FS.read = function()
    return saved and JSON.encode(saved) or nil
end
FS.mkdir_p = function() end
FS.atomic_write = function(_, content)
    persisted = content
    return true
end

local AppInput = require("core.app_input")
local function expect(value, message)
    if not value then error(message or "assertion failed", 2) end
end

-- New installs retain the zero-based SDL values used by Dolphin Button n.
saved, persisted = nil, nil
AppInput.init()
local pad = AppInput.pad_map()
expect(pad.A == 1 and pad.B == 0 and pad.X == 2 and pad.Y == 3,
    "face buttons must use SDL IDs")
expect(pad.L1 == 4 and pad.R1 == 5 and pad.L2 == 9 and pad.R2 == 12,
    "shoulder/trigger buttons must use SDL IDs")
expect(pad.SELECT == 6 and pad.START == 7 and pad.MENU == 8 and pad.L3 == 11,
    "system and stick buttons must use SDL IDs")
expect(pad.R3 == nil, "R3 must stay unset until mapped")
expect(AppInput.from_gamepad("leftstick") == "L3", "SDL leftstick must map to L3")
expect(AppInput.from_gamepad("rightstick") == "R3", "SDL rightstick must map to R3")

-- A complete persisted copy of the known mistaken joydev layout is repaired.
saved = {
    active_device = "RG35XX H",
    pad = {
        A=0, B=1, X=2, Y=3, L1=4, R1=5, L2=6, R2=7,
        SELECT=8, START=9, MENU=10, L3=11, R3=12,
    },
}
persisted = nil
AppInput.init()
pad = AppInput.pad_map()
expect(pad.A == 1 and pad.B == 0 and pad.L2 == 9 and pad.R2 == 12,
    "the full mistaken joydev signature must be migrated to SDL defaults")
expect(pad.SELECT == 6 and pad.START == 7 and pad.MENU == 8,
    "system controls must be restored to SDL IDs")
expect(pad.R3 == nil, "legacy joydev R3 index must not become an SDL default")
expect(AppInput.active_device() == "RG35XX H", "device selection must survive migration")
expect(type(persisted) == "string", "migration must persist the corrected map")
local stored = JSON.decode(persisted)
expect(stored.pad.A == 1 and stored.pad.SELECT == 6 and stored.pad.R3 == nil,
    "persisted preferences must contain the corrected SDL map")

-- A partial or custom mapping is ambiguous; never overwrite it heuristically.
saved = { pad = { A = 0 } }
persisted = nil
AppInput.init()
expect(AppInput.pad_map().A == 0, "a partial custom remap must be preserved")
expect(persisted == nil, "ambiguous partial data must not be rewritten")

saved = { pad = {
    A=12, B=1, X=2, Y=3, L1=4, R1=5, L2=10, R2=7,
    SELECT=8, START=9, MENU=10, L3=11,
} }
persisted = nil
AppInput.init()
expect(AppInput.pad_map().A == 12 and AppInput.pad_map().L2 == 10,
    "custom values must survive a near-match to the mistaken defaults")
expect(persisted == nil, "custom near-match must not trigger migration")

-- A previously correct persisted SDL map loads unchanged.
saved = { active_device = "known-pad", pad = {
    A=1, B=0, X=2, Y=3, L1=4, R1=5, L2=9, R2=12,
    SELECT=6, START=7, MENU=8, L3=11,
} }
persisted = nil
AppInput.init()
expect(AppInput.pad_map().A == 1 and AppInput.pad_map().SELECT == 6,
    "existing correct SDL preferences must remain unchanged")
expect(persisted == nil, "correct SDL preferences must not be rewritten")
expect(AppInput.active_device() == "known-pad", "active device must remain selected")

-- R3 is a supported logical action and can be assigned explicitly.
expect(AppInput.set_pad("R3", 13), "R3 should be available as a remappable action")
expect(AppInput.pad_map().R3 == 13, "R3 remap must be stored")
expect(not AppInput.set_pad("UNKNOWN", 99), "unknown actions must be rejected")

print("AppInput SDL migration tests: PASS")
