#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;dolphin-rtcore-muos/app/Dolphin RtUI/?/init.lua;" .. package.path

local Settings = require("core.settings")
local FS = require("core.fs")
local Shell = require("core.shell")

local original = {
    atomic_write = FS.atomic_write,
    first = Shell.first,
    roots = Settings.rom_root_candidates,
    data = Settings.data,
}

FS.atomic_write = function() return true end
Settings.rom_root_candidates = function() return { "/fake/roms", "/fake/ROMS" } end
Shell.first = function(command)
    local lower = command:lower()
    if lower:find("readlink%-f") then
        if lower:find("/fake/roms", 1, true) then return "/fake/roms" end
        if lower:find("/mnt/sdcard/roms", 1, true) then return "/mnt/sdcard/roms" end
    end
    return nil
end

-- No boot scan or compatibility call may silently register a ROM path.
Settings.data = { rom_paths = {}, rom_discovery_done = false }
assert(Settings.auto_discover_rom_paths() == 0, "legacy discovery entry point is a no-op")
assert(#Settings.get("rom_paths") == 0, "no roots are auto-registered")
assert(Settings.get("rom_discovery_done") == false, "automatic discovery does not mark setup complete")

-- The user's Add GC / Add Wii actions register a directory only once,
-- regardless of case or selected console.
assert(Settings.add_rom_path("/fake/ROMS", "GC") == true, "first explicit path add")
assert(Settings.add_rom_path("/fake/roms", "Wii") == false, "same path is not added twice")
assert(#Settings.get("rom_paths") == 1, "one record per canonical directory")
assert(Settings.get("rom_paths")[1].system == "Both", "mixed-system choice remains a single shared path")
assert(Settings.get("rom_discovery_done") == true, "explicit selection completes first-run setup")

-- Migrate old installations that saved the same directory once per system
-- and/or with a different path case into one canonical record.
Settings.data = {
    rom_paths = {
        { path = "/mnt/sdcard/ROMS", system = "GC" },
        { path = "/mnt/sdcard/roms", system = "Wii" },
    },
    rom_discovery_done = true,
}
assert(Settings.normalize_rom_paths() == true, "legacy duplicate paths are collapsed")
assert(#Settings.get("rom_paths") == 1, "one legacy directory remains")
assert(Settings.get("rom_paths")[1].system == "Both", "legacy system hints merge")

FS.atomic_write = original.atomic_write
Shell.first = original.first
Settings.rom_root_candidates = original.roots
Settings.data = original.data
print("ROM path selection and de-duplication tests: OK")
