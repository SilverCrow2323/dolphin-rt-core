-- frontend/cheats_manager.lua
-- Gecko cheat management per game.
-- .cheats files live in workshop/cheats/<GAMEID>.cheats
-- At launch, enabled cheats are merged into
-- dolphin-emu/Config/GameSettings/<GAMEID>.ini

local sh = require("sh")

local M = {}

local CHEATS_DIR   = "workshop/cheats"
local GAMESET_DIR  = "dolphin-emu/Config/GameSettings"
local DOLPHIN_INI  = "dolphin-emu/Config/Dolphin.ini"

-- ── Parsing file .cheats ─────────────────────────────────────
local function parse_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a"); f:close()

    local data = {
        path    = path,
        cheats  = {},   -- name -> { righe del blocco }
        order   = {},   -- ordine di apparizione
        enabled = {},   -- name -> true/false
    }

    local section = nil
    local current = nil
    for line in text:gmatch("[^\r\n]+") do
        local sec = line:match("^%s*%[([^%]]+)%]")
        if sec then
            section = sec
            current = nil
        elseif section == "Gecko" then
            local name = line:match("^%s*%$(.+)%s*$")
            if name then
                current = name
                data.cheats[name] = {}
                table.insert(data.order, name)
            elseif current then
                table.insert(data.cheats[current], line)
            end
        elseif section == "Gecko_Enabled" then
            local name = line:match("^%s*%$(.+)%s*$")
            if name then data.enabled[name] = true end
        end
    end
    return data
end

local function write_file(data)
    local f = io.open(data.path, "w")
    if not f then return false end

    f:write("[Gecko]\n")
    for _, name in ipairs(data.order) do
        f:write("$" .. name .. "\n")
        for _, l in ipairs(data.cheats[name]) do
            f:write(l .. "\n")
        end
    end

    f:write("\n[Gecko_Enabled]\n")
    for _, name in ipairs(data.order) do
        if data.enabled[name] then
            f:write("$" .. name .. "\n")
        end
    end
    f:close()
    return true
end

-- ── API pubblica ─────────────────────────────────────────────
function M.list_games()
    local out = {}
    local h = io.popen('ls -1 ' .. sh.shq(CHEATS_DIR) .. ' 2>/dev/null')
    if not h then return out end
    for line in h:lines() do
        local id = line:match("^([A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])%.cheats$")
        if id then table.insert(out, id) end
    end
    h:close()
    table.sort(out)
    return out
end

function M.get_cheats(game_id)
    local path = CHEATS_DIR .. "/" .. game_id .. ".cheats"
    local data = parse_file(path)
    if not data then return {} end
    local out = {}
    for _, name in ipairs(data.order) do
        table.insert(out, {
            name    = name,
            enabled = data.enabled[name] == true,
        })
    end
    return out
end

function M.toggle(game_id, cheat_name, enabled)
    local path = CHEATS_DIR .. "/" .. game_id .. ".cheats"
    local data = parse_file(path)
    if not data then return false end
    data.enabled[cheat_name] = enabled and true or false
    return write_file(data)
end

function M.has_cheats(game_id)
    local path = CHEATS_DIR .. "/" .. game_id .. ".cheats"
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

-- ── EnableCheats in Dolphin.ini ──────────────────────────────
function M.set_enable_cheats(on)
    local f = io.open(DOLPHIN_INI, "r")
    if not f then return false end
    local lines = {}
    local in_core = false
    local done = false
    for line in f:lines() do
        local sec = line:match("^%s*%[([^%]]+)%]")
        if sec then in_core = (sec == "Core") end
        if in_core and line:match("^%s*EnableCheats%s*=") then
            line = "EnableCheats = " .. (on and "True" or "False")
            done = true
        end
        table.insert(lines, line)
    end
    f:close()
    if not done then
        -- inserisci dopo [Core] se non esiste
        for i, l in ipairs(lines) do
            if l:match("^%s*%[Core%]") then
                table.insert(lines, i + 1,
                    "EnableCheats = " .. (on and "True" or "False"))
                done = true
                break
            end
        end
    end
    if not done then return false end
    return sh.atomic_write(DOLPHIN_INI, table.concat(lines, "\n") .. "\n")
end

-- ── Apply al GameSettings ────────────────────────────────────
function M.apply(game_id)
    local path = CHEATS_DIR .. "/" .. game_id .. ".cheats"
    local data = parse_file(path)
    if not data then return false end

    -- Check if at least one cheat is enabled
    local has_enabled = false
    for _, name in ipairs(data.order) do
        if data.enabled[name] then has_enabled = true; break end
    end

    local target = GAMESET_DIR .. "/" .. game_id .. ".ini"
    local lines = {}
    local f = io.open(target, "r")
    if f then
        for line in f:lines() do table.insert(lines, line) end
        f:close()
    end

    -- Remove old [Gecko] and [Gecko_Enabled] sections
    local out = {}
    local skip = false
    for _, line in ipairs(lines) do
        local sec = line:match("^%s*%[([^%]]+)%]")
        if sec then
            skip = (sec == "Gecko" or sec == "Gecko_Enabled")
        end
        if not skip then table.insert(out, line) end
    end

    -- Add new sections only if enabled cheats exist
    if has_enabled then
        table.insert(out, "")
        table.insert(out, "[Gecko]")
        for _, name in ipairs(data.order) do
            table.insert(out, "$" .. name)
            for _, l in ipairs(data.cheats[name]) do
                table.insert(out, l)
            end
        end
        table.insert(out, "")
        table.insert(out, "[Gecko_Enabled]")
        for _, name in ipairs(data.order) do
            if data.enabled[name] then
                table.insert(out, "$" .. name)
            end
        end
        M.set_enable_cheats(true)
    end

    -- Ensure the directory exists
    os.execute("mkdir -p " .. sh.shq(GAMESET_DIR))
    return sh.atomic_write(target, table.concat(out, "\n") .. "\n")
end

return M