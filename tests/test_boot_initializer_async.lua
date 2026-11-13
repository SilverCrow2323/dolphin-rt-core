package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

-- Boot initializer must advance ROM scanning incrementally, never via Library.scan().
local notifications = {}
package.preload["core.notification_hub"] = function()
    return { push = function(kind, title, message) notifications[#notifications + 1] = {kind, title, message} end }
end
package.preload["core.shell"] = function()
    return { shq = function(value) return "'" .. tostring(value) .. "'" end }
end
package.preload["core.settings"] = function()
    return { get = function() return false end }
end

local library = {
    games = {}, scanning = false, scan_owner = nil,
    begin_calls = 0, step_calls = 0, blocking_calls = 0,
}
function library.scan_begin(owner)
    library.begin_calls = library.begin_calls + 1
    assert(owner == "boot", "boot must identify its scan owner")
    library.scanning, library.scan_owner = true, owner
end
function library.scan_step(budget)
    assert(budget <= 0.01, "boot scan slice must stay frame-bounded")
    library.step_calls = library.step_calls + 1
    if library.step_calls == 1 then
        library.games = {{ id = "GZLE01", title = "Test Game", system = "GC" }}
        return false
    end
    library.scanning, library.scan_owner = false, nil
    return true
end
function library.scan()
    library.blocking_calls = library.blocking_calls + 1
    error("blocking Library.scan() must not be called by boot")
end
function library.scan_finish()
    library.scanning, library.scan_owner = false, nil
end
package.preload["core.library"] = function() return library end
package.preload["core.gamesettings_deployer"] = function()
    return { start = function() end, poll = function() return true, {deployed = 0} end }
end
package.preload["core.cheats_downloader"] = function()
    return { start_for = function() end, poll = function() return true end }
end
package.preload["core.rtid_builder"] = function()
    return { rebuild_all = function() return {built = 0, updated = 0, orphans = 0} end }
end

local Boot = require("core.boot_initializer")
Boot.start()
Boot.update(0.016) -- FAST_BOOT moves to scan_roms without network downloads.
assert(Boot.step() == "scan_roms")
assert(library.begin_calls == 0 and library.step_calls == 0)

Boot.update(0.016)
assert(library.begin_calls == 1 and library.step_calls == 1)
assert(Boot.step() == "scan_roms", "scan must remain active after the first slice")
assert(library.blocking_calls == 0)

Boot.update(0.016)
assert(library.step_calls == 2)
assert(Boot.step() == "wait_gamesets")
assert(Boot.snapshot().roms == 1)
assert(library.blocking_calls == 0)

Boot.update(0.016) -- wait_gamesets
Boot.update(0.016) -- download_cheats
Boot.update(0.016) -- wait_cheats
Boot.update(0.016) -- build_rtid
assert(Boot.is_done(), "boot initializer must finish after all mocked stages")
assert(library.blocking_calls == 0)
print("Boot ROM scan is incremental: all tests passed")
