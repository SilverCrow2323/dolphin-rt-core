-- core/gameset_loader.lua — read data/gamesettings.json and deploy entries.
local M = {}
local JSON = require("core.json")
local sh   = require("core.sh")

local PATH = "data/gamesettings.json"
local _cache

function M.invalidate() _cache = nil end

function M.load(force)
    if force then _cache = nil end
    if _cache then return _cache end
    _cache = { games = {}, by_id = {}, version = 0, last_update = nil }
    local f = io.open(PATH, "r")
    if not f then return _cache end
    local txt = f:read("*a"); f:close()
    local ok, d = pcall(JSON.decode, txt)
    if not ok or type(d) ~= "table" or type(d.settings) ~= "table" then return _cache end
    _cache.version, _cache.last_update = tonumber(d.version) or 0, d.last_update
    for _, g in ipairs(d.settings) do
        local ids, configs = g.game_ids or {}, g.configs or {}
        local entry = { game = g.game, ids = ids, configs = configs, system = g.system }
        _cache.games[#_cache.games + 1] = entry
        for _, id in ipairs(ids) do
            local gid = type(id) == "table" and id.id or tostring(id)
            if type(gid) == "string" and gid:match("^[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$") then
                _cache.by_id[gid] = entry
            end
        end
    end
    return _cache
end

function M.ids_for(game_id)
    if type(game_id) == "string" then return { game_id } end
    return game_id or {}
end

function M.for_game(game_id) return M.load().by_id[game_id] end

function M.deploy(entry, game_id)
    if type(entry) ~= "table" or type(entry.configs) ~= "table"
       or type(game_id) ~= "string" or not game_id:match("^[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$") then
        return 0
    end
    local dir = "workshop/gamesettings/" .. game_id
    sh.mkdir_p(dir)
    local n, first = 0, nil
    for _, cfg in ipairs(entry.configs) do
        local filename = type(cfg.filename) == "string" and cfg.filename or ""
        if filename:match("^[%w_.%-]+%.ini$") and filename ~= "rtgameset_data.ini" then
            local target = dir .. "/" .. filename
            local f = io.open(target, "r")
            if f then f:close()
            else
                local out = io.open(target, "w")
                if out then
                    out:write(type(cfg.raw_content) == "string" and cfg.raw_content or "")
                    out:close()
                    n = n + 1
                end
            end
            first = first or filename
        end
    end
    local meta = dir .. "/rtgameset_data.ini"
    local f = io.open(meta, "r")
    if f then
        f:close()
    else
        local m = io.open(meta, "w")
        if m then
            m:write("[GameSettings]\n")
            m:write("GameName = " .. tostring(entry.game or game_id):gsub("[\r\n]", " ") .. "\n")
            m:write("ActiveConfig = " .. tostring(first or "base.ini") .. "\n")
            m:close()
        end
    end
    return n
end

return M
