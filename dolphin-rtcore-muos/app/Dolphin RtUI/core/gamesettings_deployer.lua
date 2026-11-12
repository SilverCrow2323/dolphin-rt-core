-- Deploy GameSettings database presets for GameIDs discovered in the local ROM library.
-- This module is intentionally synchronous: the DB is local JSON and only missing
-- files are written. It never overwrites user-edited configs.
local GL = require("core.gameset_loader")
local M = { running = false, result = { deployed = 0, matched = 0, skipped = 0 } }

function M.start(games)
    M.running = true
    M.result = { deployed = 0, matched = 0, skipped = 0 }
    GL.invalidate()
    local seen = {}
    for _, game in ipairs(games or {}) do
        local id = type(game) == "table" and game.id or nil
        if type(id) == "string" and id:match("^[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$") and not seen[id] then
            seen[id] = true
            local entry = GL.for_game(id)
            if entry then
                M.result.matched = M.result.matched + 1
                M.result.deployed = M.result.deployed + GL.deploy(entry, id)
            else
                M.result.skipped = M.result.skipped + 1
            end
        end
    end
    M.running = false
    return M.result
end

function M.poll()
    return not M.running, M.result
end

return M
