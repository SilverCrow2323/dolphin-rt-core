-- Regression coverage for ROM root normalization and combined GC/Wii scans.
local JSON = require("core.json")
local seed = JSON.encode({
    rom_paths = {
        {path = "/mnt/mmc/ROMS/GameCube/", system = "GC"},
        {path = "/mnt/MMC/roms/gamecube", system = "Wii"},
        {path = "/mnt/mmc/ROMS/Wii", system = "Wii"},
    }
})
local persisted
package.loaded["core.fs"] = {
    read = function() return seed end,
    mkdir_p = function() end,
    atomic_write = function(_, content) persisted = content; return true end,
}
package.loaded["core.settings"] = nil
local Settings = require("core.settings")
Settings.init()
local roots = Settings.get("rom_paths")
assert(#roots == 2, "case/trailing-slash duplicate roots collapse to one row")
assert(roots[1].path == "/mnt/mmc/ROMS/GameCube", "first registered spelling is preserved sans trailing slash")
assert(roots[1].system == "Both", "GC and Wii registrations merge into Both")
assert(roots[2].system == "Wii", "unrelated Wii root remains Wii")
assert(type(persisted) == "string", "legacy normalization is persisted")

Settings.set("rom_paths", {{path = "/mnt/sdcard/ROMs", system = "GC"}})
local added, status = Settings.add_rom_path("/mnt/SDCARD/roms/", "Wii")
assert(added and status == "updated", "adding the other system upgrades the same root")
assert(#Settings.get("rom_paths") == 1, "upgrading a root never adds a duplicate row")
assert(Settings.get("rom_paths")[1].system == "Both", "upgraded root scans both systems")
local duplicate = Settings.add_rom_path("/mnt/sdcard//ROMS", "GC")
assert(not duplicate, "same normalized root and already-covered system is ignored")

local captured
package.loaded["core.shell"] = {
    shq = function(value) return "'" .. tostring(value) .. "'" end,
    popen = function(command) captured = command; return "/roms/sample.iso\n" end,
}
package.loaded["core.system_detect"] = {
    from_id = function(id) return id and id:sub(1, 1) == "R" and "Wii" or "GC" end,
    from_rom = function(rom) return rom and rom.path and rom.path:match("%.wbfs$") and "Wii" or "GC" end,
}
package.loaded["core.library"] = nil
local Library = require("core.library")
assert(Library._path_key("/mnt/MMC//ROMS/Game.iso/") == "/mnt/mmc/roms/game.iso",
       "scanner identity key ignores case and redundant separators")
local files = Library._find_files("/roms", "Both", 4)
assert(#files == 1 and files[1] == "/roms/sample.iso", "combined scanner returns discovered files")
for _, ext in ipairs({"iso", "gcm", "rvz", "gcz", "ciso", "wbfs", "wia"}) do
    assert(captured:find("-iname '*." .. ext .. "'", 1, true),
           "combined scan includes ." .. ext)
end
print("ROM root normalization and combined GC/Wii scan tests passed")
