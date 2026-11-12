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
    if not entry or type(entry.configs) ~= "table" then return 0 end
    if type(game_id) ~= "string" or not game_id:match("^[%w][%w][%w][%w][%w][%w]$") then return 0 end

    local dir = "workshop/gamesettings/" .. game_id
    sh.mkdir_p(dir)
    local n = 0
    for _, cfg in ipairs(entry.configs) do
        local filename = type(cfg.filename) == "string" and cfg.filename or ""
        -- The downloaded catalogue is data, never a path source.
        if filename:match("^[%w _%.%-]+%.ini$") and not filename:find("..", 1, true) then
            local target = dir .. "/" .. filename
            local f = io.open(target, "r")
            if f then
                f:close()
            else
                local out = io.open(target, "w")
                if out then
                    out:write(type(cfg.raw_content) == "string" and cfg.raw_content or "")
                    out:close()
                    n = n + 1
                end
            end
        end
    end

    -- Write metadata so gameset_manager can see the deployed presets.
    local meta = dir .. "/rtgameset_data.ini"
    local existing = io.open(meta, "r")
    if existing then
        existing:close()
    else
        local m = io.open(meta, "w")
        if m then
            local first = entry.configs[1]
            local active = first and first.filename or "base.ini"
            if not active:match("^[%w _%.%-]+%.ini$") or active:find("..", 1, true) then
                active = "base.ini"
            end
            m:write("[GameSettings]\n")
            m:write("GameName = " .. tostring(entry.game or game_id):gsub("[\r\n]", " ") .. "\n")
            m:write("ActiveConfig = " .. active .. "\n")
            m:close()
        end
    end
    return n
end
return M