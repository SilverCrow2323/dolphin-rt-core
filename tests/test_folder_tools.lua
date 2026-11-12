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
expect(Tools.infer_system("gc") == "GC", "gc exact match")
expect(Tools.infer_system("NGC") == "GC", "ngc exact match")
expect(Tools.infer_system("GameCube") == "GC", "gamecube exact match")
expect(Tools.infer_system("Game Cube") == "GC", "game cube spaced exact match")
expect(Tools.infer_system("Wii") == "Wii", "wii exact match")
expect(Tools.infer_system("GameCubeZ") == nil, "GameCubeZ must not be renamed")
expect(Tools.infer_system("Game-Cube") == nil, "punctuation variants must not be renamed")
expect(Tools.infer_system("gc extra") == nil, "suffix text must not be renamed")
expect(Tools.infer_system("Nintendo GameCube") == nil, "prefixed labels must not be renamed")
expect(Tools.infer_system("WiiZ") == nil, "WiiZ must not be renamed")
expect(Tools.infer_system("Nintendo Wii") == nil, "prefixed Wii labels must not be renamed")
expect(Tools.infer_system("Game-Cube") == nil, "hyphenated near-match must not be renamed")
expect(Tools.infer_system("Game_Cube") == nil, "underscored near-match must not be renamed")
expect(Tools.infer_system("GC") == "GC", "mixed-case GC must match")
expect(Tools.infer_system("NgC") == "GC", "mixed-case NGC must match")
expect(Tools.infer_system("GaMeCuBe") == "GC", "mixed-case GameCube must match")
expect(Tools.infer_system("GaMe CuBe") == "GC", "mixed-case spaced Game Cube must match")
expect(Tools.infer_system("wIi") == "Wii", "mixed-case Wii must match")
expect(Tools.infer_system("game  cube") == nil, "extra spaces must not match")
expect(Tools.infer_system(" gc") == nil, "leading spaces must not match")
expect(Tools.infer_system("game-cube") == nil, "punctuation variants must not match")
expect(Tools.infer_system("PlayStation") == nil, "unknown system must remain unknown")

local hidden = Tools.skip_reasons(".hidden-roms", "/mnt/roms/.hidden-roms", { ".*", "_*" })
expect(#hidden == 1 and hidden[1] == ".*", "hidden-directory skip match")
local underscore = Tools.skip_reasons("_private", "/mnt/roms/_private", { ".*", "_*" })
expect(#underscore == 1 and underscore[1] == "_*", "underscore-directory skip match")
local normal = Tools.skip_reasons("GameCube", "/mnt/roms/GameCube", { ".*", "_*", "/img*", "*.ips*", "neogeo.zip" }, "/mnt/roms")
expect(#normal == 0, "GameCube is not falsely reported as a skip.ini match")

local img_root = Tools.skip_reasons("img-assets", "/mnt/roms/img-assets", { ".*", "_*", "/img*", "*.ips*" }, "/mnt/roms")
expect(#img_root == 1 and img_root[1] == "/img*", "root-level img path rule")

local img_nested = Tools.skip_reasons("img-assets", "/mnt/roms/art/img-assets", { "/img*" }, "/mnt/roms")
expect(#img_nested == 0, "root-only /img* rule must not match a nested artwork folder")

local file_pattern = Tools.skip_reasons("game.ips", "/mnt/roms/game.ips", { "*.ips*" }, "/mnt/roms")
expect(#file_pattern == 0, "file extension skip patterns must not be reported as folder bans")

local preview, err = Tools.preview({
    path = "/mnt/sdcard/roms/Game Cube",
    name = "Game Cube",
    has_roms = true,
}, "GC")
expect(preview ~= nil, err or "preview must be generated")
expect(preview.target == "/mnt/sdcard/roms/RtGC", "GC folders receive canonical RtGC name")
expect(preview.alias == "rtgc", "GC alias key")
expect(preview.system == "GC", "preview platform")

local wii_preview, wii_err = Tools.preview({
    path = "/mnt/sdcard/roms/wii",
    name = "wii",
    has_roms = true,
}, nil)
expect(wii_preview ~= nil, wii_err or "Wii exact match preview")
expect(wii_preview.target == "/mnt/sdcard/roms/RtWii", "Wii folders receive canonical RtWii name")
expect(wii_preview.alias == "rtwii", "Wii alias key")

local unsupported = Tools.preview({
    path = "/mnt/sdcard/roms/GameCubeZ",
    name = "GameCubeZ",
    has_roms = true,
}, "GC")
expect(unsupported == nil, "near-match directory must never be renamed")

local missing_disc = Tools.preview({
    path = "/mnt/sdcard/roms/gc",
    name = "gc",
    has_roms = false,
}, "GC")
expect(missing_disc == nil, "folder without a disc image must not be renamed")

-- muOS Content Explorer skips symbolic-link directory entries. FolderWaker
-- must reject them instead of offering a misleading rename/alias operation.
local link_root = "/tmp/folderwaker-symlink-test-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000, 999999))
local link_source = link_root .. "/GameCube-real"
local link_alias = link_root .. "/GameCube"
local setup_rc = os.execute("mkdir -p " .. Shell.shq(link_source) .. " && ln -s GameCubeZ-real " .. Shell.shq(link_alias))
expect(setup_rc == 0 or setup_rc == true, "create symlink fixture")
Settings.data = { rom_paths = {} }
local link_item, link_err = Tools.inspect(link_alias)
expect(link_item == nil and tostring(link_err):find("symbolic%-link") ~= nil,
    "FolderWaker must explain that muOS skips symbolic-link folders")
local link_ok, link_commit_err = Tools.rename_register({
    path = link_alias, has_roms = true, is_scan_root = false,
}, "GC")
expect(link_ok == false and tostring(link_commit_err):find("symbolic%-link") ~= nil,
    "FolderWaker must not register a symlink alias as a ROM directory")
os.execute("rm -rf " .. Shell.shq(link_root))

-- Manual folder selection must diagnose the exact selected path, not only
-- folders found by the automatic candidate-name scan.
Settings.data = { rom_paths = {} }
Settings.rom_root_candidates = function() return { "/mnt/roms" } end
FS.is_dir = function(path) return path == "/mnt/roms" or path == "/mnt/roms/GameCube" end
Shell.first = function(command)
    if command:find("find ", 1, true) then return "/mnt/roms/GameCube/game.rvz" end
    return nil
end
local inspected, inspect_err = Tools.inspect("/mnt/roms/GameCube")
expect(inspected ~= nil, inspect_err or "manual folder inspection")
expect(inspected.inferred_system == "GC", "manual folder system inference")
expect(inspected.has_roms == true, "manual folder disc image probe")
expect(inspected.status == "content-explorer-blocked", "manual folder is marked as Content Explorer blocked")
expect(inspected.content_explorer_blocked == true, "blocked marker is retained")
local roots = Tools.root_report()
expect(#roots == 1 and roots[1].path == "/mnt/roms", "root report lists the configured scan root")
expect(roots[1].accessible == true and roots[1].has_roms == true, "root report exposes mount and ROM visibility")
FS.is_dir, Shell.first = original.is_dir, original.first
Settings.rom_root_candidates, Settings.data = original.roots, original.data

print("FolderWaker folder-tool tests: OK")
