package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local calls = {}
local entries = {
    {
        game = "Game One",
        ids = {"GAAAA1", {id = "GBBBB1"}},
        configs = {{filename = "preset.ini", raw_content = "[Core]"}},
    },
    {
        game = "Second entry",
        ids = {{id = "GAAAA1"}, "GCCCC1", "../unsafe"},
        configs = {{filename = "preset.ini", raw_content = "[Core]"}},
    },
}
local Loader = {
    load = function() return {games = entries} end,
    deploy = function(entry, id)
        calls[#calls + 1] = {entry = entry, id = id}
        if id == "GCCCC1" then return 0, 1 end
        return 2, 0
    end,
}
package.preload["core.gameset_loader"] = function() return Loader end

local Deployer = require("core.gamesettings_deployer")
assert(Deployer.start())
local done, result = Deployer.poll()
assert(not done and result.processed == 1, "deployment must process one game ID per poll")
assert(calls[1].id == "GAAAA1")
done, result = Deployer.poll()
assert(not done and result.processed == 2)
assert(calls[2].id == "GBBBB1")
done, result = Deployer.poll()
assert(done and result.processed == 3)
assert(calls[3].id == "GCCCC1")
assert(result.total == 3, "duplicate and invalid IDs must be excluded")
assert(result.deployed == 4 and result.failed == 1)
assert(result.status == "partial")

Deployer.reset()
Loader.load = function() return {games = {}} end
assert(Deployer.start())
done, result = Deployer.poll()
assert(done and result.total == 0 and result.status == "complete")
print("Bundled GameSettings deployer: all tests passed")
