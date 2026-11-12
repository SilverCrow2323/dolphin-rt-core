#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;dolphin-rtcore-muos/app/Dolphin RtUI/?/init.lua;" .. package.path

local Settings = require("core.settings")
local FS = require("core.fs")
local Shell = require("core.shell")

local original = {
    is_dir = FS.is_dir, mkdir_p = FS.mkdir_p, atomic_write = FS.atomic_write,
    first = Shell.first, roots = Settings.rom_root_candidates,
}

local existing_is_dir = false
local existing_has_rom = false
FS.is_dir = function(path)
    return path == "/fake/roms" or (path == "/existing" and existing_is_dir)
end
FS.mkdir_p = function() return true end
FS.atomic_write = function() return true end
Settings.rom_root_candidates = function() return { "/fake/roms", "/fake/roms" } end
Shell.first = function(command)
    if command:find("readlink%-f") then
        if command:find("/existing", 1, true) then return "/existing" end
        return "/fake/roms"
    end
    if command:find("find ", 1, true) then
        if command:find("/existing", 1, true) then
            return existing_has_rom and "/existing/Manual Game.iso" or nil
        end
        if command:find("/fake/roms", 1, true) then return "/fake/roms/Test Game.iso" end
    end
    return nil
end

Settings.data = { rom_paths = {}, rom_discovery_done = false }
local count = Settings.auto_discover_rom_paths()
assert(count == 1, "duplicate root candidates must be collapsed")
assert(#Settings.get("rom_paths") == 2, "mixed root must be registered for both platform scanners")
assert(Settings.get("rom_paths")[1].path == "/fake/roms", "canonical root path")
assert(Settings.get("rom_paths")[1].system == "GC", "GC scanner registration")
assert(Settings.get("rom_paths")[2].system == "Wii", "Wii scanner registration")
assert(Settings.get("rom_discovery_done") == true, "successful scan should mark first-run discovery complete")
assert(Settings.auto_discover_rom_paths() == 0, "subsequent discovery must be idempotent")
assert(#Settings.get("rom_paths") == 2, "idempotent run must not duplicate configured roots")

-- A stale legacy path must not suppress discovery, even when an older
-- release already marked the first-run scan complete.
Settings.data = { rom_paths = { { path = "/existing", system = "GC" } }, rom_discovery_done = true }
existing_is_dir, existing_has_rom = false, false
count = Settings.auto_discover_rom_paths()
assert(count == 1, "stale configured paths must trigger real ROM-root discovery")
assert(Settings.get("rom_discovery_done") == true, "successful recovery marks discovery complete")
assert(#Settings.get("rom_paths") == 3, "stale manual path is preserved and the discovered root is registered for both systems")
assert(Settings.get("rom_paths")[2].path == "/fake/roms", "discovered root is appended after preserved user path")

-- A valid manually selected folder is respected; do not add a broader root.
Settings.data = { rom_paths = { { path = "/existing", system = "GC" } }, rom_discovery_done = false }
existing_is_dir, existing_has_rom = true, true
count = Settings.auto_discover_rom_paths()
assert(count == 0, "valid manual configuration must not be overwritten or broadened")
assert(#Settings.get("rom_paths") == 1, "valid manual folder remains the only configured path")
assert(Settings.get("rom_discovery_done") == true, "valid manual configuration marks discovery handled")

Settings.data = { rom_paths = {}, rom_discovery_done = false }
FS.is_dir = function() return false end
assert(Settings.auto_discover_rom_paths() == 0, "no mounted roots should return zero")
assert(Settings.get("rom_discovery_done") == false, "failed discovery stays retryable")

FS.is_dir, FS.mkdir_p, FS.atomic_write = original.is_dir, original.mkdir_p, original.atomic_write
Shell.first = original.first
Settings.rom_root_candidates = original.roots
print("ROM auto-discovery tests: OK")
