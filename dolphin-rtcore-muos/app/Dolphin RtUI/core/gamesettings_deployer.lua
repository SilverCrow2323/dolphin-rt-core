-- core/gamesettings_deployer.lua — deploy bundled presets only for games
-- that are actually present in the scanned local library.
local M = {}
local Loader = require("core.gameset_loader")

local queue, index, deployed, started = {}, 1, 0, false

function M.start(games)
    queue, index, deployed, started = {}, 1, 0, true
    for _, game in ipairs(games or {}) do
        local id = game and game.id
        if type(id) == "string" and id:match("^[%w][%w][%w][%w][%w][%w]$") then
            local entry = Loader.for_game(id)
            if entry then queue[#queue + 1] = { id = id, entry = entry } end
        end
    end
    return #queue
end

-- Incremental: one matching game per poll, so boot remains responsive.
function M.poll()
    if not started then return true, { deployed = deployed, matched = 0 } end
    local item = queue[index]
    if item then
        local ok, n = pcall(Loader.deploy, item.entry, item.id)
        if ok then deployed = deployed + (tonumber(n) or 0) end
        index = index + 1
    end
    local done = index > #queue
    if done then started = false end
    return done, { deployed = deployed, matched = #queue, processed = index - 1 }
end

function M.reset()
    queue, index, deployed, started = {}, 1, 0, false
end

return M
