#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;dolphin-rtcore-muos/app/Dolphin RtUI/?/init.lua;" .. package.path

local Tools = require("core.folder_tools")

local function expect(ok, message)
    if not ok then error(message or "assertion failed", 2) end
end

expect(Tools.normalize_alias("GameCube Z") == "gamecubez", "alias normalisation")
expect(Tools.normalize_alias("Rt_GameCube-Z") == "rtgamecubez", "Rt alias normalisation")
expect(Tools.infer_system("Nintendo GameCube") == "GC", "GameCube inference")
expect(Tools.infer_system("GameCubeZ") == "GC", "GameCubeZ inference")
expect(Tools.infer_system("Nintendo Wii") == "Wii", "Wii inference")
expect(Tools.infer_system("WiiZ") == "Wii", "WiiZ inference")
expect(Tools.infer_system("PlayStation") == nil, "unknown system must remain unknown")

local hidden = Tools.skip_reasons(".hidden-roms", "/mnt/roms/.hidden-roms", { ".*", "_*" })
expect(#hidden == 1 and hidden[1] == ".*", "hidden-directory skip match")
local underscore = Tools.skip_reasons("_private", "/mnt/roms/_private", { ".*", "_*" })
expect(#underscore == 1 and underscore[1] == "_*", "underscore-directory skip match")
local normal = Tools.skip_reasons("GameCubeZ", "/mnt/roms/GameCubeZ", { ".*", "_*", "/img*" })
expect(#normal == 0, "GameCubeZ is not falsely reported as a skip.ini match")

local preview, err = Tools.preview({
    path = "/mnt/sdcard/roms/GameCubeZ",
    name = "GameCubeZ",
}, "GC")
expect(preview ~= nil, err or "preview must be generated")
expect(preview.target == "/mnt/sdcard/roms/RtGameCubeZ", "preview target path")
expect(preview.alias == "rtgamecubez", "preview alias key")
expect(preview.system == "GC", "preview platform")

local double_prefix = Tools.preview({
    path = "/mnt/sdcard/roms/RtGameCubeZ",
    name = "RtGameCubeZ",
}, "GC")
expect(double_prefix == nil, "already Rt-prefixed folders must not be prefixed again")

local rejected = Tools.preview({ path = "/mnt/roms/Wii" }, nil)
expect(rejected == nil, "ambiguous folders require explicit platform selection")
print("Registratore Z folder-tool tests: OK")
