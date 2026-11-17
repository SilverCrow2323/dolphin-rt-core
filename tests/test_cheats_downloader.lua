package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local commands = {}
local launch_ok = true
package.preload["core.sh"] = function()
    return {
        abs = function(path) return "/app/" .. path end,
        shq = function(value) return "'" .. tostring(value):gsub("'", "'\\''") .. "'" end,
        run_async = function(command)
            commands[#commands + 1] = command
            return launch_ok
        end,
    }
end

local status_body
local real_io_open = io.open
io.open = function(path, mode)
    if path == "/app/data/rtcheats_sync.status" and mode == "r" then
        if not status_body then return nil end
        return {
            read = function(_, format)
                assert(format == "*a")
                return status_body
            end,
            close = function() end,
        }
    end
    return real_io_open(path, mode)
end

local Downloader = require("core.cheats_downloader")
assert(Downloader.start_for())
assert(#commands == 1)
assert(commands[1] == "cd '/app' && sh '/app/scripts/rtcheats_sync.sh'",
       "boot mode must delegate boost-only selection to the shell sync script")
assert(not Downloader.poll(), "missing status file must remain pending while the worker starts")

status_body = "state=running\nmsg=downloading GAAAA1\ndone=1\ntotal=3\ntime=123\n"
local done, status = Downloader.poll()
assert(not done and status.done == 1 and status.total == 3)
status_body = "state=ok\nmsg=done\ndone=3\ntotal=3\ntime=124\n"
done, status = Downloader.poll()
assert(done and status.state == "ok" and status.done == 3)
assert(Downloader.status().msg == "done")

Downloader.reset()
status_body = nil
assert(Downloader.start_for({"GAAAA1", "../../escape", {id = "GBBBB1"}, "GAAAA1"}))
assert(#commands == 2)
assert(commands[2]:find("'GAAAA1'", 1, true))
assert(commands[2]:find("'GBBBB1'", 1, true))
assert(not commands[2]:find("escape", 1, true),
       "invalid path-like IDs must be discarded")
status_body = "state=fail\nmsg=offline\ndone=0\ntotal=2\ntime=125\n"
done, status = Downloader.poll()
assert(done and status.state == "fail" and status.msg == "offline")

Downloader.reset()
launch_ok = false
assert(not Downloader.start_for({"GAAAA1"}))
done, status = Downloader.poll()
assert(done and status.state == "fail")
io.open = real_io_open
print("Boot cheat downloader adapter: all tests passed")
