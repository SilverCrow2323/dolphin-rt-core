package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local pushed = {}
package.preload["core.notification_hub"] = function()
    return { push = function(...) pushed[#pushed + 1] = { ... } end }
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
            assert(budget == 0.006, "boot scan should use a small frame budget")
            step_count = step_count + 1
            return step_count >= 2
        end,
        scan = function()
            blocking_calls = blocking_calls + 1
            error("blocking full-library scan must not be used during boot")
        end,
    }
end

local deployed_games
package.preload["core.gamesettings_deployer"] = function()
    return {
        start = function(list) deployed_games = list; return 1 end,
        poll = function() return true, { deployed = 0, matched = 1 } end,
    }
end

local B = require("core.boot_initializer")
B.start()
B.update(0.016) -- fast boot enters scan_roms
assert(B.step() == "scan_roms", "fast boot should start ROM scan")
B.update(0.016) -- scan_begin
assert(begin_count == 1 and step_count == 0, "scan must begin without processing every ROM")
B.update(0.016) -- first incremental slice
assert(B.step() == "scan_roms" and step_count == 1, "scan should yield between frames")
assert(blocking_calls == 0, "blocking scan was called")
B.update(0.016) -- second slice completes and schedules GameSettings
assert(B.step() == "wait_gamesets", "completed scan should advance boot")
assert(deployed_games == games and deployed_games[1].id == "GZLE01",
       "GameSettings deployer must receive the scanned library")
print("Boot incremental ROM scan: OK")
