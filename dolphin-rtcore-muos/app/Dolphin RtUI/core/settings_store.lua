-- core/settings_store.lua — Persistenza generica chiave/valore.
-- Usato da minoru/voice.lua e da altre parti per leggere/scrivere
-- preferenze senza duplicare la logica JSON + atomic_write.
--
-- API:
--   M.init([path])         → carica
--   M.get(section, key, default)
--   M.set(section, key, value)
--   M.flush()
--   M.reset()
--   M.path()               → path file corrente
--
-- Path default: data/settings_store.json

local JSON = require("core.json")
local FS   = require("core.fs")

local M = {}
local DEFAULT_PATH = "data/settings_store.json"
local path = DEFAULT_PATH
local data = {}
local dirty = false

local function ensure()
    if type(data) ~= "table" then data = {} end
end

function M.init(p)
    path = p or DEFAULT_PATH
    data = {}
    dirty = false
    local raw = FS.read(path)
    if raw then
        local ok, decoded = pcall(JSON.decode, raw)
        if ok and type(decoded) == "table" then
            data = decoded
        end
    end
    ensure()
end

function M.get(section, key, default)
    ensure()
    if not section then return default end
    local s = data[section]
    if type(s) ~= "table" then return default end
    if key == nil then return s end
    local v = s[key]
    if v == nil then return default end
    return v
end

function M.set(section, key, value)
    ensure()
    if not section or key == nil then return false end
    data[section] = data[section] or {}
    if data[section][key] ~= value then
        data[section][key] = value
        dirty = true
    end
    return true
end

function M.flush()
    if not dirty then return true end
    FS.mkdir_p((path:match("^(.*)/[^/]+$") or "data"))
    local ok = FS.atomic_write(path, JSON.encode(data))
    if ok then dirty = false end
    return ok
end

function M.reset()
    data = {}
    dirty = true
    return M.flush()
end

function M.path() return path end

-- Auto-flush su require successivo
return setmetatable(M, {
    __call = function(_, ...) return M.get(...) end
})
