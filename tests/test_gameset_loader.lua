package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local root = "/tmp/rtcore-gameset-loader-test"
os.execute("rm -rf '" .. root .. "'")
os.execute("mkdir -p '" .. root .. "/data'")

local fixture = {
    settings = {
        {
            game = "Game One\nInjected",
            game_ids = {{id = "GAAAA1", region = "NTSC"}},
            system = "GC",
            configs = {
                {filename = "../../escape.ini", raw_content = "bad"},
                {filename = "GAAAA1_rtmuos.ini", raw_content = "[Core]\nCPUCore = 4\n"},
            },
        },
    },
}
package.preload["core.json"] = function()
    return {decode = function() return fixture end}
end
package.preload["core.sh"] = function()
    return {
        abs = function(path) return root .. "/" .. path end,
        workshop = function(path) return root .. "/workshop/" .. path end,
        mkdir_p = function(path)
            local ok = os.execute("mkdir -p '" .. path .. "'")
            return ok == true or ok == 0
        end,
    }
end

local source = io.open(root .. "/data/gamesettings.json", "w")
source:write("{}")
source:close()

local Loader = require("core.gameset_loader")
local data = Loader.load()
assert(#data.games == 1)
assert(data.by_id.GAAAA1 == data.games[1])
assert(Loader.for_game("GAAAA1") == data.games[1])

local written, failed = Loader.deploy(data.games[1], "GAAAA1")
assert(written == 1 and failed == 1,
       "valid preset should be deployed and path traversal rejected")
local preset = io.open(root .. "/workshop/gamesettings/GAAAA1/GAAAA1_rtmuos.ini", "r")
assert(preset, "bundled GameSettings file must be written")
local body = preset:read("*a")
preset:close()
assert(body:match("CPUCore = 4"))

local meta = io.open(root .. "/workshop/gamesettings/GAAAA1/rtgameset_data.ini", "r")
assert(meta, "GameSettings metadata must be created")
local meta_body = meta:read("*a")
meta:close()
assert(meta_body:match("GameName = Game One Injected"),
       "metadata game names must not inject new INI lines")
assert(meta_body:match("ActiveConfig = base%.ini"),
       "invalid first preset filenames must not become active paths")

-- Existing user presets are not overwritten by a bundled refresh.
local out = io.open(root .. "/workshop/gamesettings/GAAAA1/GAAAA1_rtmuos.ini", "w")
out:write("user changes")
out:close()
written, failed = Loader.deploy(data.games[1], "GAAAA1")
assert(written == 0 and failed == 1)
preset = io.open(root .. "/workshop/gamesettings/GAAAA1/GAAAA1_rtmuos.ini", "r")
body = preset:read("*a")
preset:close()
assert(body == "user changes")

local invalid_written, invalid_failed = Loader.deploy(data.games[1], "../escape")
assert(invalid_written == 0 and invalid_failed == 2,
       "game IDs must not traverse outside the GameSettings directory")
os.execute("rm -rf '" .. root .. "'")
print("Bundled GameSettings loader: all tests passed")
