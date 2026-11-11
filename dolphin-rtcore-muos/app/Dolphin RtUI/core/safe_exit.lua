-- Safe Exit combo persistence.
-- The watcher consumes raw joydev button indices, not SDL logical names.
local FS = require("core.fs")
local AI = require("core.app_input")

local M = {}
M.PATH = "data/safe_exit.conf"
local DEFAULT = { "MENU" }
local MAX_BUTTONS = 4

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function current_pad()
    return (AI.pad_map and AI.pad_map()) or {}
end

local function unique_names(names)
    local out, seen = {}, {}
    if type(names) ~= "table" then return nil, "combo must be a list" end
    for _, name in ipairs(names) do
        if type(name) ~= "string" then return nil, "invalid button name" end
        name = name:upper()
        if not seen[name] then
            seen[name] = true
            out[#out + 1] = name
        end
    end
    if #out < 1 or #out > MAX_BUTTONS then
        return nil, "choose between 1 and 4 buttons"
    end
    if #out == 1 and out[1] ~= "MENU" then
        return nil, "a single-button exit is allowed only for M / MENU"
    end
    return out
end

local function labels(raw)
    local reverse = {}
    for logical, index in pairs(current_pad()) do
        if type(index) == "number" then reverse[index] = logical end
    end
    local out = {}
    for _, index in ipairs(raw) do out[#out + 1] = reverse[index] or ("Button " .. index) end
    return out
end

function M.default_names()
    return { "MENU" }
end

function M.load_raw()
    local raw = FS.read(M.PATH)
    local out, seen = {}, {}
    if raw then
        for token in raw:gmatch("[^,%s]+") do
            local n = tonumber(token)
            if n and n % 1 == 0 and n >= 0 and n <= 255 and not seen[n] then
                seen[n] = true
                out[#out + 1] = n
            end
        end
    end
    if #out == 0 then
        local menu = current_pad().MENU
        out[1] = (type(menu) == "number") and menu or 8
    end
    table.sort(out)
    return out
end

function M.load_names()
    return labels(M.load_raw())
end

function M.save_names(names)
    local clean, err = unique_names(names)
    if not clean then return false, err end

    local pad = current_pad()
    local raw, seen = {}, {}
    for _, name in ipairs(clean) do
        local index = pad[name]
        if type(index) ~= "number" or index % 1 ~= 0 or index < 0 or index > 255 then
            return false, "button " .. name .. " has no joypad index"
        end
        if seen[index] then return false, "two logical buttons map to the same hardware input" end
        seen[index] = true
        raw[#raw + 1] = index
    end
    table.sort(raw)
    FS.mkdir_p("data")
    local text = table.concat(raw, ",") .. "\n"
    if not FS.atomic_write(M.PATH, text) then return false, "could not write " .. M.PATH end
    return true, table.concat(clean, " + ")
end

function M.reset()
    return M.save_names(DEFAULT)
end

function M.describe()
    return table.concat(M.load_names(), " + ")
end

return M
