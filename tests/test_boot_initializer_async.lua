package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

-- Full boot pipeline: optional modules must load correctly and ROM scanning
-- must advance in bounded slices, without invoking the blocking Library.scan().
local notifications = {}
package.preload["core.notification_hub"] = function()
    return { push = function(kind, title, message)
        notifications[#notifications + 1] = {kind, title, message}
    end }
end
package.preload["core.shell"] = function()
    return { shq = function(value) return "'" .. tostring(value) .. "'" end }
end
package.preload["core.settings"] = function()
    return { get = function(key)
        if key == "auto_update_check" then return true end
        if key == "fast_boot" then return false end
        return nil
    end }
end

local updater = { checks = 0, polls = 0 }
function updater.check_async() updater.checks = updater.checks + 1 end
function updater.poll() updater.polls = updater.polls + 1; return true end
package.preload["core.app_updater"] = function() return updater end

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

local deployer = { starts = 0, polls = 0 }
function deployer.start() deployer.starts = deployer.starts + 1 end
function deployer.poll()
    deployer.polls = deployer.polls + 1
    return true, {deployed = 2}
end
package.preload["core.gamesettings_deployer"] = function() return deployer end

local cheats = { starts = 0, polls = 0, ids = nil }
function cheats.start_for(ids) cheats.starts = cheats.starts + 1; cheats.ids = ids end
function cheats.poll()
    cheats.polls = cheats.polls + 1
    return cheats.polls >= 2
end
package.preload["core.cheats_downloader"] = function() return cheats end

local builder = { calls = 0 }
function builder.rebuild_all()
    builder.calls = builder.calls + 1
    return {built = 7, updated = 3, orphans = 1}
end
package.preload["core.rtid_builder"] = function() return builder end

-- Simulate successful background downloads without network or shell side effects.
local old_execute = os.execute
local download_spawns = 0
os.execute = function(command)
    if tostring(command):find("setsid sh", 1, true) then
        download_spawns = download_spawns + 1
        if download_spawns == 3 then
            for _, key in ipairs({"games_data", "gamesettings_json", "rtcheats_db"}) do
                local marker = io.open("/tmp/rt_boot_" .. key .. ".done", "w")
                assert(marker, "boot marker must be writable")
                marker:close()
            end
        end
    end
    return 0
end

local marker_keys = {"games_data", "gamesettings_json", "rtcheats_db"}
local function cleanup()
    os.execute = old_execute
    for _, key in ipairs(marker_keys) do
        os.remove("/tmp/rt_boot_" .. key .. ".done")
        os.remove("/tmp/rt_boot_" .. key .. ".sh")
    end
end

local Boot = require("core.boot_initializer")
local ok, err = xpcall(function()
    Boot.start()
    Boot.update(0.016) -- update_check: optional updater must load and start.
    assert(Boot.step() == "wait_update")
    assert(updater.checks == 1, "app updater must be called")

    Boot.update(0.016) -- wait_update: all mocked downloads start.
    assert(Boot.step() == "download_data")
    assert(download_spawns == 3)

    Boot.update(0.016) -- download_data: deployer must load and start.
    assert(Boot.step() == "scan_roms")
    assert(deployer.starts == 1, "GameSettings deployer must be started")

    Boot.update(0.016) -- ROM scan slice 1.
    assert(library.begin_calls == 1 and library.step_calls == 1)
    assert(Boot.step() == "scan_roms", "scan must remain active after first slice")
    assert(library.blocking_calls == 0)

    Boot.update(0.016) -- ROM scan slice 2 completes.
    assert(library.step_calls == 2)
    assert(Boot.step() == "wait_gamesets")
    assert(Boot.snapshot().roms == 1)

    Boot.update(0.016) -- wait_gamesets.
    assert(deployer.polls == 1 and Boot.step() == "download_cheats")

    Boot.update(0.016) -- download_cheats: downloader must load and start.
    assert(cheats.starts == 1 and Boot.step() == "wait_cheats")
    assert(cheats.ids == nil, "boot must request only the performance-boost index set")

    Boot.update(0.016) -- first cheats poll.
    assert(Boot.step() == "wait_cheats")
    Boot.update(0.016) -- second cheats poll.
    assert(Boot.step() == "build_rtid")

    Boot.update(0.016) -- build_rtid: RTID builder must load and run.
    assert(builder.calls == 1)
    assert(Boot.is_done(), "full boot pipeline must complete")
    local snap = Boot.snapshot()
    assert(snap.roms == 1 and snap.gamesets.deployed == 2 and snap.cards == 7)
    assert(snap.update.status == "up_to_date")
    assert(snap.gamesets.status == "complete")
    assert(snap.cards_status == "complete")
    assert(snap.cheats.status == "complete")
    assert(library.blocking_calls == 0)
end, debug.traceback)
cleanup()
assert(ok, err)
print("Boot optional modules and incremental ROM scan: all tests passed")
