#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local tmp = os.tmpname() .. ".iso"
local f = assert(io.open(tmp, "wb"))
f:write("GZLE01", string.rep("x", 128))
f:close()

local readlink_calls, find_calls = 0, 0
package.preload["core.settings"] = function()
    return { get = function(key)
        if key == "rom_paths" then
            return {
                { path = "/fake/roms", system = "GC" },
                { path = "/FAKE/ROMS", system = "Wii" },
            }
        end
        if key == "scan_depth" then return 8 end
    end }
end
package.preload["core.fs"] = function()
    return { is_dir = function() return true end }
end
package.preload["core.shell"] = function()
    return {
        shq = function(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end,
        first = function(command)
            if command:find("readlink%-f") then
                readlink_calls = readlink_calls + 1
                return "/fake/roms"
            end
            return nil
        end,
        popen = function(command)
            if command:find("find ", 1, true) then
                find_calls = find_calls + 1
                return tmp .. "\n" .. tmp:upper() .. "\n"
            end
            return ""
        end,
    }
end
package.preload["core.system_detect"] = function()
    return { from_id = function() return "GC" end }
end

local Library = require("core.library")
Library.scan_begin()
assert(find_calls == 1, "case-insensitive duplicate roots must be traversed once")
assert(readlink_calls <= 2, "realpath should be resolved for roots only, never per ROM")
assert(Library.progress.total == 1, "case-insensitive duplicate ROM paths must be queued once")
Library.scan_step(1)
assert(#Library.games == 1 and Library.games[1].id == "GZLE01",
    "duplicate case-variant paths must produce exactly one library entry")
os.remove(tmp)
print("ROM scan path de-duplication and process budget: OK")
