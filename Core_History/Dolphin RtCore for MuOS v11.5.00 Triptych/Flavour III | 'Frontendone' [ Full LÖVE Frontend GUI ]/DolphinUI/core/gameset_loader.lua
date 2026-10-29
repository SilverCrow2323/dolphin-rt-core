-- core/gameset_loader.lua — read data/gamesettings.json and deploy entries.
local M = {}
local JSON = require("core.json")
local sh   = require("core.sh")

local PATH = "data/gamesettings.json"
local _cache

function M.load()
    if _cache then return _cache end
    _cache = { games = {}, by_id = {} }
    local f = io.open(PATH, "r")
    if not f then return _cache end
    local txt = f:read("*a"); f:close()
    local ok, d = pcall(JSON.decode, txt)
    if not ok or type(d) ~= "table" or type(d.settings) ~= "table" then return _cache end
    for _, g in ipairs(d.settings) do
        local ids = g.game_ids or {}
        local configs = g.configs or {}
        local entry = { game = g.game, ids = ids, configs = configs, system = g.system }
        _cache.games[#_cache.games + 1] = entry
        for _, id in ipairs(ids) do
            local gid = type(id) == "table" and id.id or tostring(id)
            if gid and gid ~= "" then _cache.by_id[gid] = entry end
        end
    end
    return _cache
end

-- IDs for a game (accepts both string and table).
function M.ids_for(game_id)
    if type(game_id) == "string" then return { game_id } end
    return game_id or {}
end

-- Return the bundled entry for a game, or nil.
function M.for_game(game_id)
    local d = M.load()
    return d.by_id[game_id]
end

-- Deploy all bundled configs of an entry into workshop/gamesettings/<ID>/.
-- Returns the number of configs written.
function M.deploy(entry, game_id)
    if not entry then return 0 end
    local dir = "workshop/gamesettings/" .. game_id
    sh.mkdir_p(dir)
    local n = 0
    for _, cfg in ipairs(entry.configs) do
        local target = dir .. "/" .. cfg.filename
        local f = io.open(target, "r")
        if f then f:close()
        else
            local out = io.open(target, "w")
            if out then out:write(cfg.raw_content or ""); out:close(); n = n + 1 end
        end
    end
    -- write the metadata so the gameset_manager can see them
    local meta = dir .. "/rtgameset_data.ini"
    if not io.open(meta, "r") then
        local m = io.open(meta, "w")
        if m then
            m:write("[GameSettings]\n")
            m:write("GameName = " .. (entry.game or game_id) .. "\n")
            m:write("ActiveConfig = " .. (entry.configs[1] and entry.configs[1].filename or "base.ini") .. "\n")
            m:close()
        end
    end
    return n
end

return M