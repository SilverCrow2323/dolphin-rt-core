#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local tmp = os.tmpname() .. ".iso"
local f = assert(io.open(tmp, "wb"))
f:write("GZLE01", string.rep("x", 1024))
f:close()

local readlink_calls, find_calls = 0, 0
local old_execute = os.execute
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

os.execute = function(command)
    if command:find("setsid sh -c", 1, true) then
        find_calls = find_calls + 1
        local suffix = command:match("(rt_romscan_[%d_]+%.list)")
        assert(suffix, "background find must use a unique list file")
        local list_path = "/tmp/" .. suffix
        local done_path = list_path .. ".done"
        local out = assert(io.open(list_path, "w"))
        out:write(tmp, "\n", tmp:upper(), "\n")
        out:close()
        local marker = assert(io.open(done_path, "w"))
        marker:write("done\n")
        marker:close()
        return 0
    end
    return old_execute(command)
end

local Library = require("core.library")
Library.scan_begin()
assert(find_calls == 0, "scan_begin must not execute or wait for find")
assert(readlink_calls == 0, "ROM scan root de-duplication must not spawn readlink")
assert(Library.scanning, "scan remains active until incremental steps run")
assert(Library.progress.total == 0, "no ROM entries are enumerated synchronously")
local done = Library.scan_step(1)
assert(done == true, "the fake background result file should be consumed in one slice")
assert(find_calls == 1, "case-insensitive duplicate roots must be traversed once")
assert(Library.progress.total == 1, "case-variant ROM paths must be queued once")
assert(#Library.games == 1 and Library.games[1].id == "GZLE01",
    "duplicate case-variant paths must produce exactly one library entry")
os.execute = old_execute
os.remove(tmp)
print("ROM scan background enumeration and path de-duplication: OK")
