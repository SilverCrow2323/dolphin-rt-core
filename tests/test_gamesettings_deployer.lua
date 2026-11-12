package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local deployed = {}
package.preload["core.gameset_loader"] = function()
    return {
        for_game = function(id)
            if id == "GAM001" then return { game = "Test Game", configs = {} } end
            return nil
        end,
        deploy = function(entry, id)
            deployed[#deployed + 1] = id
            return 2
        end,
    }
end

local D = require("core.gamesettings_deployer")
local matched = D.start({
    { id = "GAM001" },
    { id = "GAM001" }, -- duplicate disc / same GameID
    { id = "MISS01" }, -- not in bundled database
    { id = "bad" },
})
assert(matched == 1, "only one unique matching GameID should be queued")
local done, result = D.poll()
assert(done == true, "single queued item should complete in one incremental poll")
assert(result.matched == 1 and result.processed == 1, "queue accounting is incorrect")
assert(result.deployed == 2 and deployed[1] == "GAM001", "preset deployment did not run")

D.start({})
done, result = D.poll()
assert(done == true and result.matched == 0, "empty library should complete safely")
print("GameSettings deployer: OK")
