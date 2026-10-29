-- core/gameset_manager.lua — GameSettings filesystem operations.
--
-- Layout managed:
--   workshop/gamesettings/<GAMEID>/
--     rtgameset_data.ini         (metadata: GameName, ActiveConfig, ...)
--     <name>.ini                 (0..N user configs)
--
-- Public API:
--   list_for(game_id) -> array { file, display, active }
--   count_for(game_id) -> int
--   active_for(game_id) -> string | nil
--   set_active(game_id, file)
--   clear_active(game_id)
--   add(game_id, filename)
--   delete(game_id, filename)
--   rename_display(game_id, filename, new_display)
--   scan_all() -> array { game_id, system, title, count, in_library }

local M = {}

local BASE = "workshop/gamesettings"
local LIB  = "workshop/gameslibrary"

local META_FILES = {
    ["rtgameset_data.ini"] = true,
    ["rtcheats_data.ini"]  = true,
}

local function shq(s)
    return "'" .. tostring(s or ""):gsub("'", "'\\''") .. "'"
end

local function read_meta(path)
    local f = io.open(path, "r")
    if not f then return {} end
    local out, section = {}, nil
    for line in f:lines() do
        local s = line:match("^%s*%[([^%]]+)%]")
        if s then section = s
        else
            local k, v = line:match("^%s*([^=]+)%s*=%s*(.*)$")
            if k and section then
                k = k:gsub("%s+$", "")
                v = v:gsub("^%s+", "")
                out[section] = out[section] or {}
                out[section][k] = v
            end
        end
    end
    f:close()
    return out
end

local function write_meta(path, meta)
    local f = io.open(path, "w")
    if not f then return false end
    local secs = { "GameSettings", "Cheats" }
    for _, sec in ipairs(secs) do
        if meta[sec] then
            f:write("[" .. sec .. "]\n")
            local keys = {}
            for k in pairs(meta[sec]) do keys[#keys+1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do
                f:write(k .. " = " .. tostring(meta[sec][k]) .. "\n")
            end
            f:write("\n")
        end
    end
    f:close()
    return true
end

local function dir_exists(p)
    local h = io.popen("[ -d " .. shq(p) .. " ] && echo 1 2>/dev/null")
    if not h then return false end
    local r = (h:read("*a") or ""):gsub("%s+", "")
    h:close()
    return r == "1"
end

local function system_for(id)
    if not id or #id ~= 6 then return "GC" end
    return id:sub(1,1):match("[RSWH]") and "Wii" or "GC"
end

-- ── Public: per-game listing ───────────────────────────────
function M.list_for(game_id)
    local out = {}
    if not game_id or game_id == "" then return out end
    local dir = BASE .. "/" .. game_id
    if not dir_exists(dir) then return out end

    local meta = read_meta(dir .. "/rtgameset_data.ini")
    local active = meta.GameSettings and meta.GameSettings.ActiveConfig or nil

    local h = io.popen("ls -1 " .. shq(dir) .. "/*.ini 2>/dev/null")
    if h then
        for line in h:lines() do
            local fn = line:match("([^/]+)$")
            if fn and not META_FILES[fn] then
                out[#out+1] = {
                    file    = fn,
                    display = fn:gsub("%.ini$", ""),
                    active  = (fn == active),
                }
            end
        end
        h:close()
    end
    table.sort(out, function(a,b)
        if a.active ~= b.active then return a.active end
        return a.file:lower() < b.file:lower()
    end)
    return out
end

function M.count_for(game_id)
    return #M.list_for(game_id)
end

function M.active_for(game_id)
    local dir = BASE .. "/" .. game_id
    if not dir_exists(dir) then return nil end
    local meta = read_meta(dir .. "/rtgameset_data.ini")
    return meta.GameSettings and meta.GameSettings.ActiveConfig or nil
end

-- ── Public: mutations ──────────────────────────────────────
function M.ensure_dir(game_id)
    local dir = BASE .. "/" .. game_id
    os.execute("mkdir -p " .. shq(dir))
    return dir
end

function M.set_active(game_id, filename)
    local dir = M.ensure_dir(game_id)
    local meta = read_meta(dir .. "/rtgameset_data.ini")
    meta.GameSettings = meta.GameSettings or {}
    meta.GameSettings.ActiveConfig = filename or ""
    write_meta(dir .. "/rtgameset_data.ini", meta)
    return true
end

function M.clear_active(game_id)
    local dir = BASE .. "/" .. game_id
    if not dir_exists(dir) then return true end
    local meta = read_meta(dir .. "/rtgameset_data.ini")
    meta.GameSettings = meta.GameSettings or {}
    meta.GameSettings.ActiveConfig = ""
    write_meta(dir .. "/rtgameset_data.ini", meta)
    return true
end

function M.add(game_id, filename)
    filename = filename or (game_id .. "_new.ini")
    if not filename:match("%.ini$") then filename = filename .. ".ini" end
    local dir = M.ensure_dir(game_id)
    local path = dir .. "/" .. filename
    local f = io.open(path, "r")
    if f then f:close(); return false, "file exists" end
    f = io.open(path, "w")
    if not f then return false, "cannot write" end
    f:write("# Dolphin Rt:Core - GameSettings for " .. game_id .. "\n")
    f:write("# Game ID: " .. game_id .. "\n\n")
    f:write("# Add your overrides here. Namespaced sections:\n")
    f:write("#   [Core] [DSP] [Interface]  (bare)\n")
    f:write("#   [Video_Settings] [Video_Hacks] [Video_Enhancements]\n\n")
    f:close()
    -- ensure metadata exists
    if not io.open(dir .. "/rtgameset_data.ini", "r") then
        local meta = { GameSettings = { GameName = game_id, ActiveConfig = "" } }
        write_meta(dir .. "/rtgameset_data.ini", meta)
    end
    return true
end

function M.delete(game_id, filename)
    if not game_id or not filename then return false end
    local path = BASE .. "/" .. game_id .. "/" .. filename
    os.remove(path)
    -- Clear active if it was the deleted file
    if M.active_for(game_id) == filename then M.clear_active(game_id) end
    return true
end

function M.rename_display(game_id, filename, new_display)
    -- Renames the file (keeping .ini) and, if it was active, updates meta.
    new_display = (new_display or ""):gsub("[^%w%-%._ ]", "")
    if new_display == "" then return false end
    if not new_display:match("%.ini$") then new_display = new_display .. ".ini" end
    if new_display == filename then return true end
    local src = BASE .. "/" .. game_id .. "/" .. filename
    local dst = BASE .. "/" .. game_id .. "/" .. new_display
    local ok = os.rename(src, dst)
    if not ok then return false end
    if M.active_for(game_id) == filename then M.set_active(game_id, new_display) end
    return true
end

-- ── Public: full scan for the browser ──────────────────────
function M.scan_all()
    local out, seen = {}, {}

    -- 1. Every folder in workshop/gamesettings/
    local h = io.popen("ls -1d " .. shq(BASE) .. "/*/ 2>/dev/null")
    if h then
        for line in h:lines() do
            local id = line:match("([^/]+)/?$")
            if id and #id >= 4 and id:sub(1,1) ~= "." then
                if not seen[id] then
                    seen[id] = true
                    local meta = read_meta(BASE .. "/" .. id .. "/rtgameset_data.ini")
                    out[#out+1] = {
                        game_id  = id,
                        system   = system_for(id),
                        title    = (meta.GameSettings and meta.GameSettings.GameName) or "",
                        count    = M.count_for(id),
                        in_library = false,
                    }
                end
            end
        end
        h:close()
    end

    -- 2. Every game id present in the library (rtid cards)
    local h2 = io.popen("ls -1 " .. shq(LIB) .. "/rtid_*.ini 2>/dev/null")
    if h2 then
        for line in h2:lines() do
            local id = line:match("rtid_([A-Z0-9]+)%.ini$")
            if id then
                if seen[id] then
                    -- already added: mark in_library
                    for _, e in ipairs(out) do
                        if e.game_id == id then e.in_library = true end
                    end
                else
                    seen[id] = true
                    out[#out+1] = {
                        game_id  = id,
                        system   = system_for(id),
                        title    = "",
                        count    = 0,
                        in_library = true,
                    }
                end
            end
        end
        h2:close()
    end

    table.sort(out, function(a, b)
        if a.system ~= b.system then return a.system < b.system end
        return a.game_id < b.game_id
    end)
    return out
end

return M
