#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;dolphin-rtcore-muos/app/Dolphin RtUI/?/init.lua;" .. package.path

local Tools = require("core.folder_tools")
local FS = require("core.fs")
local Shell = require("core.shell")
local Settings = require("core.settings")

local original = {
    is_dir = FS.is_dir,
    first = Shell.first,
    roots = Settings.rom_root_candidates,
    data = Settings.data,
}

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
local normal = Tools.skip_reasons("GameCubeZ", "/mnt/roms/GameCubeZ", { ".*", "_*", "/img*", "*.ips*", "neogeo.zip" }, "/mnt/roms")
expect(#normal == 0, "GameCubeZ is not falsely reported as a skip.ini match")

local img_root = Tools.skip_reasons("img-assets", "/mnt/roms/img-assets", { ".*", "_*", "/img*", "*.ips*" }, "/mnt/roms")
expect(#img_root == 1 and img_root[1] == "/img*", "root-level img path rule")

local img_nested = Tools.skip_reasons("img-assets", "/mnt/roms/art/img-assets", { "/img*" }, "/mnt/roms")
expect(#img_nested == 0, "root-only /img* rule must not match a nested artwork folder")

local file_pattern = Tools.skip_reasons("game.ips", "/mnt/roms/game.ips", { "*.ips*" }, "/mnt/roms")
expect(#file_pattern == 0, "file extension skip patterns must not be reported as folder bans")

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

-- Manual folder selection must diagnose the exact selected path, not only
-- folders found by the automatic candidate-name scan.
Settings.data = { rom_paths = {} }
Settings.rom_root_candidates = function() return { "/mnt/roms" } end
FS.is_dir = function(path) return path == "/mnt/roms" or path == "/mnt/roms/GameCubeZ" end
Shell.first = function(command)
    if command:find("find ", 1, true) then return "/mnt/roms/GameCubeZ/game.rvz" end
    return nil
end
local inspected, inspect_err = Tools.inspect("/mnt/roms/GameCubeZ")
expect(inspected ~= nil, inspect_err or "manual folder inspection")
expect(inspected.inferred_system == "GC", "manual folder system inference")
expect(inspected.has_roms == true, "manual folder disc image probe")
expect(inspected.status == "unmapped", "manual folder reports missing assignment separately")
local roots = Tools.root_report()
expect(#roots == 1 and roots[1].path == "/mnt/roms", "root report lists the configured scan root")
expect(roots[1].accessible == true and roots[1].has_roms == true, "root report exposes mount and ROM visibility")
FS.is_dir, Shell.first = original.is_dir, original.first
Settings.rom_root_candidates, Settings.data = original.roots, original.data

print("Registratore Z folder-tool tests: OK")
