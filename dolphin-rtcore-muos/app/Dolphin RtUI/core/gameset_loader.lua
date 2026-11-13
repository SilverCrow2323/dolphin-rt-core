-- core/gameset_loader.lua — read data/gamesettings.json and deploy entries.
local M = {}
local JSON = require("core.json")
local sh   = require("core.sh")

local PATH = sh.abs("data/gamesettings.json")
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
    if type(entry) ~= "table" or type(entry.configs) ~= "table" then
        return 0, 0
    end
    if type(game_id) ~= "string" or not game_id:match("^[A-Z0-9]+$") then
        return 0, #entry.configs
    end

    local dir = sh.workshop("gamesettings/" .. game_id)
    local made = sh.mkdir_p(dir)
    if made ~= true and made ~= 0 then return 0, #entry.configs end

    local n, failed = 0, 0
    for _, cfg in ipairs(entry.configs) do
        local filename = type(cfg) == "table" and cfg.filename or nil
        -- Bundled metadata can arrive from a downloaded JSON file. Restrict
        -- filenames to one INI basename; never allow a path to escape the ID.
        if type(filename) ~= "string"
           or not filename:match("^[%w_.%-]+%.ini$")
           or filename:find("..", 1, true)
           or filename:find("/", 1, true)
           or filename:find("\\", 1, true) then
            failed = failed + 1
        else
            local target = dir .. "/" .. filename
            local existing = io.open(target, "r")
            if existing then
                existing:close()
            else
                local out = io.open(target, "w")
                if out then
                    out:write(type(cfg.raw_content) == "string" and cfg.raw_content or "")
                    out:close()
                    n = n + 1
                else
                    failed = failed + 1
                end
            end
        end
    end

    -- Preserve an existing selection and close the probe handle correctly.
    local meta = dir .. "/rtgameset_data.ini"
    local existing_meta = io.open(meta, "r")
    if existing_meta then
        existing_meta:close()
    else
        local m = io.open(meta, "w")
        if m then
            local game_name = tostring(entry.game or game_id):gsub("[\r\n]", " ")
            local first_name = entry.configs[1] and entry.configs[1].filename or "base.ini"
            if type(first_name) ~= "string" or not first_name:match("^[%w_.%-]+%.ini$")
               or first_name:find("..", 1, true) or first_name:find("/", 1, true)
               or first_name:find("..", 1, true) or first_name:find("/", 1, true)
                first_name = "base.ini"
            end
            m:write("[GameSettings]\n")
            m:write("GameName = " .. game_name .. "\n")
            m:write("ActiveConfig = " .. first_name .. "\n")
            m:close()
        else
            failed = failed + 1
        end
    end
    return n, failed
end
return M