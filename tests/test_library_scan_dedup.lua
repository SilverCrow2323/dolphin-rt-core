#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local tmp = os.tmpname() .. ".iso"
local f = assert(io.open(tmp, "wb"))
f:write("GZLE01", string.rep("x", 1024))
f:close()

local readlink_calls, find_calls = 0, 0
local old_popen = io.popen
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
        popen = function() error("blocking Shell.popen must not be used for ROM enumeration") end,
    }
end
package.preload["core.system_detect"] = function()
    return { from_id = function() return "GC" end }
end

io.popen = function(command, mode)
    if command:find("find ", 1, true) then
        find_calls = find_calls + 1
        local lines, index = { tmp, tmp:upper() }, 0
        return {
            read = function(_, kind)
                assert(kind == "*l", "scanner should consume find output line-by-line")
                index = index + 1
                return lines[index]
            end,
            close = function() return true end,
        }
    end
    return old_popen(command, mode)
end

local Library = require("core.library")
Library.scan_begin()
assert(find_calls == 0, "scan_begin must not execute a blocking find")
assert(readlink_calls == 2, "realpath should be resolved for roots only")
assert(Library.scanning, "scan remains active until the incremental steps run")
assert(Library.progress.total == 0, "no ROM entries are enumerated synchronously")
local done = Library.scan_step(1)
assert(done == true, "one fake scan slice should finish the two-line fixture")
assert(find_calls == 1, "case-insensitive duplicate roots must be traversed once")
assert(Library.progress.total == 1, "case-variant ROM paths must be queued once")
assert(#Library.games == 1 and Library.games[1].id == "GZLE01",
    "duplicate case-variant paths must produce exactly one library entry")
io.popen = old_popen
os.remove(tmp)
print("ROM scan incremental enumeration and path de-duplication: OK")
