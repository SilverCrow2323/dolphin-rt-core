-- Run with: luajit tests/test_gamesettings_deployer.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local deployed = {}
local entries = {
    GZLE01 = { name = "Game A", count = 2 },
    GZLP01 = { name = "Game B", count = 1 },
}
local invalidated = 0
package.preload["core.gameset_loader"] = function()
    return {
        invalidate = function() invalidated = invalidated + 1 end,
        for_game = function(id) return entries[id] end,
        deploy = function(entry, id) deployed[id] = (deployed[id] or 0) + entry.count; return entry.count end,
    }
end

local DEP = require("core.gamesettings_deployer")
local result = DEP.start({
    { id = "GZLE01" },
    { id = "GZLE01" }, -- duplicate image / same GameID
    { id = "GZLP01" },
    { id = "GZJP01" }, -- valid GameID, absent from the database
    { id = "bad" },
    {},
})
assert(invalidated == 1, "database cache must be refreshed before deployment")
assert(result.matched == 2, "only database-backed GameIDs are matched")
assert(result.deployed == 3, "all missing preset files are counted")
assert(result.skipped == 1, "unknown valid GameIDs are reported as skipped")
assert(deployed.GZLE01 == 2 and deployed.GZLP01 == 1, "each GameID is deployed exactly once")
local done, final = DEP.poll()
assert(done and final == result, "synchronous deployer must report completion and final counts")
print("GameSettings auto-deployer tests: OK")
