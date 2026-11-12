local catalogue = { settings = {} }
package.preload["core.json"] = function()
    return { decode = function() return catalogue end }
end
package.preload["core.sh"] = function()
    return { mkdir_p = function() return true end }
end

local original_open = io.open
io.open = function(path, mode)
    if path == "data/gamesettings.json" and mode == "r" then
        return { read = function() return "{}" end, close = function() end }
    end
    return original_open(path, mode)
end

package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path
local GL = require("core.gameset_loader")
assert(GL.for_game("GAM001") == nil, "empty initial catalogue should not match")
local generation = GL.generation
catalogue = {
    settings = {
        {
            game = "Test Game",
            game_ids = { { id = "GAM001", region = "NTSC" } },
            configs = { { filename = "GAM001_rtmuos.ini", raw_content = "[Core]" } },
        },
    },
}
assert(GL.for_game("GAM001") == nil, "cached catalogue should remain stable until invalidated")
GL.invalidate()
assert(GL.generation == generation + 1, "catalogue generation must advance")
local entry = GL.for_game("GAM001")
assert(entry and entry.game == "Test Game", "invalidated loader did not read new catalogue")
io.open = original_open
print("GameSettings catalogue invalidation: OK")
