#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local pushed = {}
package.preload["core.notification_hub"] = function()
    return { push = function(kind, title, message)
        pushed[#pushed + 1] = { kind = kind, title = title, message = message }
    end }
end
package.preload["core.shell"] = function()
    return { shq = function(s) return "'" .. tostring(s) .. "'" end }
end
package.preload["core.settings"] = function()
    return {
        get = function(key)
            if key == "fast_boot" then return true end
            if key == "rom_discovery_done" then return true end
            return nil
        end,
    }
end

local begin_count, step_count, blocking_calls = 0, 0, 0
local games = { { id = "GZLE01", title = "Wind Waker" } }
package.preload["core.library"] = function()
    return {
        games = games,
        scan_begin = function() begin_count = begin_count + 1 end,
        scan_step = function(budget)
            assert(budget == 0.006, "boot scan should use a small wall-clock frame budget")
            step_count = step_count + 1
            return step_count >= 2
        end,
        scan = function()
            blocking_calls = blocking_calls + 1
            error("blocking Library.scan() must not be used during boot")
        end,
    }
end

local started_for
package.preload["core.cheats_downloader"] = function()
    return {
        start_for = function(ids) started_for = ids; return true end,
        poll = function() return true end,
    }
end
package.preload["core.rtid_builder"] = function()
    return { rebuild_all = function()
        return { built = 1, updated = 1, orphans = 0 }
    end }
end

local B = require("core.boot_initializer")
B.start()
B.update(0.016) -- fast boot enters scan_roms
assert(B.step() == "scan_roms", "fast boot should start ROM scan")
B.update(0.016) -- scan_begin
assert(begin_count == 1 and step_count == 0, "scan must begin without processing every ROM")
B.update(0.016) -- first incremental slice
assert(B.step() == "scan_roms" and step_count == 1, "scan should yield between frames")
assert(blocking_calls == 0, "blocking Library.scan() was called")
B.update(0.016) -- second slice completes; background work is next
assert(B.step() == "download_cheats", "completed scan should move to cheat refresh")
B.update(0.016) -- start cheat refresh
assert(B.step() == "wait_cheats", "cheat refresh should be polled asynchronously")
assert(started_for == games or (started_for and started_for[1] == "GZLE01"),
    "cheat downloader receives scanned game IDs")
B.update(0.016) -- completed
assert(B.step() == "build_rtid", "completed cheat job advances to card rebuild")
B.update(0.016)
assert(B.is_done(), "boot must complete after card rebuild")
for _, item in ipairs(pushed) do
    assert(item.message ~= "Timed out", "boot must not emit the old global timeout notification")
end
print("Boot pipeline is incremental and cannot fail on the obsolete global timeout: OK")
