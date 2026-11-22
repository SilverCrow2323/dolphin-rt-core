#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;dolphin-rtcore-muos/app/Dolphin RtUI/?/init.lua;" .. package.path

local GM = require("core.gameset_manager")
local id = "ZZTEST1"
local dir = "workshop/gamesettings/" .. id

local function write(path, content)
    local f = assert(io.open(path, "w"))
    f:write(content)
    f:close()
end

local function expect(ok, message)
    if not ok then error(message or "assertion failed", 2) end
end

os.execute("rm -rf " .. string.format("%q", dir))
os.execute("mkdir -p " .. string.format("%q", dir))
write(dir .. "/Preset.ini", "[Core]\nCPUThread = False\n")
write(dir .. "/rtgameset_data.ini", "[GameSettings]\nGameName = Test game\nActiveConfig = Preset.ini\n")

expect(GM.active_for(id) == "Preset.ini", "ActiveConfig must be the canonical selected config")
local items = GM.list_for(id)
expect(#items == 1 and items[1].file == "Preset.ini" and items[1].active,
    "GameSettings browser must mark the canonical ActiveConfig")

GM.clear_active(id)
expect(GM.active_for(id) == nil, "clear_active must disable GameSettings")
expect(GM.has_active_record(id), "Disabled must remain an explicit canonical selector")
GM.set_active(id, "Preset.ini")
expect(GM.active_for(id) == "Preset.ini", "set_active must persist a valid file")
expect(GM.has_active_record(id), "enabled selection must have canonical metadata")

write(dir .. "/rtgameset_data.ini", "[GameSettings]\nActiveConfig = ../escape.ini\n")
expect(GM.active_for(id) == nil, "ActiveConfig must reject paths outside the GameID folder")

write(dir .. "/rtgameset_data.ini", "[GameSettings]\nActiveConfig = Missing.ini\n")
expect(GM.active_for(id) == nil, "missing active config must not be reported as selected")
expect(GM.has_active_record(id), "invalid but present selector is still canonical metadata")

local fresh_id = "ZZTEST2"
local fresh_dir = "workshop/gamesettings/" .. fresh_id
os.execute("rm -rf " .. string.format("%q", fresh_dir))
expect(GM.clear_active(fresh_id), "disabling a game with no prior folder must persist")
expect(GM.has_active_record(fresh_id), "new game Disabled must create canonical metadata")
expect(GM.active_for(fresh_id) == nil, "new game Disabled must not select a preset")

os.execute("rm -rf " .. string.format("%q", dir))
os.execute("rm -rf " .. string.format("%q", fresh_dir))
print("GameSettings ActiveConfig tests: OK")
