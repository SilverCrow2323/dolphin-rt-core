-- frontend/import_manager.lua — import from games_data.json / muOS ext.
-- Writes to the multi-config rtgameset_data.ini format.
-- All shell args go through shq() (POSIX single-quote escaping).

local json  = require("json")
local State = require("state")

local M = {}

local EXT_DIR      = "/opt/muos/share/emulator/dolphin/Config"
local KNOWN_TYPES  = {
    compatibility = true,
    performance   = true,
    maxrintromping = true,
    default       = true,
}

local function shq(s)
    if s == nil then return "''" end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function safe_id(id)
    if type(id) ~= "string" then return nil end
    local s = id:gsub("[^%w_%-]", "")
    if s == "" then return nil end
    return s
end

-- ── Metadata writing (new format) ───────────────────────────
local function write_meta(game_id, fields, configs)
    local dir = "workshop/gamesettings/" .. game_id
    os.execute("mkdir -p " .. shq(dir))

    local f = io.open(dir .. "/rtgameset_data.ini", "w")
    if not f then return false end

    local function w(s) f:write(s .. "\n") end

    w("[GameSettings]")
    w("GameID       = " .. (fields.GameID or game_id))
    w("GameName     = " .. (fields.GameName or ""))
    w("System       = " .. (fields.System or "GC"))
    w("Region       = " .. (fields.Region or ""))
    w("ActiveConfig = " .. (fields.ActiveConfig or ""))
    w("Description  = " .. (fields.Description or ""))
    w("Author       = " .. (fields.Author or ""))
    w("Version      = " .. (fields.Version or "1.0.0"))
    w("")
    w("[Configs]")
    if type(configs) == "table" then
        for filename, label in pairs(configs) do
            w(filename .. " = " .. label)
        end
    end
    w("")
    w("[Origin]")
    w("Source       = " .. (fields.Source or ""))
    w("SourceURL    = " .. (fields.SourceURL or ""))
    w("")
    w("[UI]")
    w("Color        = " .. (fields.Color or "#4CC850"))
    w("Icon         = " .. (fields.Icon or "save"))
    f:close()
    return true
end

-- ── games_data.json scanning ────────────────────────────────
local function games_data_candidates()
    return {
        State.frontend_path("data/games_data.json"),
        State.path("frontend/data/games_data.json"),
        "data/games_data.json",
        "frontend/data/games_data.json",
    }
end

local function read_games_data()
    for _, p in ipairs(games_data_candidates()) do
        local f = io.open(p, "r")
        if f then
            local c = f:read("*a"); f:close()
            local ok, data = pcall(json.decode, c)
            if ok and type(data) == "table" then
                return data, p
            end
        end
    end
    return nil, nil
end

function M.scan_games_data()
    local out = {}
    local data = read_games_data()
    if not data then return out end
    local games = data.games or data
    if type(games) ~= "table" then return out end
    for _, game in ipairs(games) do
        local gi = game.game_info or {}
        local entries = game.entries or { game }
        for _, entry in ipairs(entries) do
            for _, s in ipairs(entry.custom_settings or {}) do
                table.insert(out, {
                    game_id      = gi.game_id or "",
                    game_name    = gi.game or "",
                    system       = gi.system or "",
                    region       = gi.region or "",
                    set_filename = s.set_filename or "",
                    set_name     = s.set_name or "",
                    set_note     = s.set_note or "",
                    set_url      = s.set_url or "",
                    set_type     = s.set_type or "Config",
                })
            end
        end
    end
    return out
end

function M.import_games_data_set(item)
    local id = safe_id(item.game_id)
    if not id then return false, "invalid game id" end

    local dir = "workshop/gamesettings/" .. id
    os.execute("mkdir -p " .. shq(dir))

    -- Filename: <GAMEID>.ini.<label>
    local label_src = item.set_name or "imported"
    local label_clean = label_src:gsub("[^%w_%-]", "_"):gsub("_+", "_")
    if label_clean == "" then label_clean = "imported" end
    local filename = id .. ".ini." .. label_clean
    local ini_path = dir .. "/" .. filename

    -- Fetch remote config if URL is present
    if item.set_url and item.set_url:match("^https?://") then
        local tmp = "/tmp/import_" .. id .. ".ini"
        -- Still synchronous (the caller shows an overlay first), but the
        -- worst case is now ~30 s instead of a 40 s double timeout.
        os.execute(string.format(
            '(curl -fsSL --connect-timeout 5 --max-time 25 -o %s %s 2>/dev/null || ' ..
            'wget -q --timeout=5 --tries=1 -O %s %s 2>/dev/null)',
            shq(tmp), shq(item.set_url), shq(tmp), shq(item.set_url)))
        local f = io.open(tmp, "r")
        if f then
            local size = f:seek("end"); f:close()
            if size and size > 0 then
                os.execute("cp " .. shq(tmp) .. " " .. shq(ini_path))
                os.remove(tmp)
            else
                os.remove(tmp)
                local ph = io.open(ini_path, "w")
                if ph then
                    ph:write("; Imported from games_data.json (remote fetch failed)\n")
                    ph:write("; " .. (item.set_note or "") .. "\n")
                    ph:close()
                end
            end
        else
            local ph = io.open(ini_path, "w")
            if ph then
                ph:write("; Imported from games_data.json\n")
                ph:write("; " .. (item.set_note or "") .. "\n")
                ph:close()
            end
        end
    else
        local ph = io.open(ini_path, "w")
        if ph then
            ph:write("; Imported from games_data.json\n")
            ph:write("; " .. (item.set_note or "") .. "\n")
            ph:close()
        end
    end

    -- Read existing metadata to preserve any manual configs already present
    local existing_active = nil
    local existing_configs = {}
    do
        local ok, PMerger = pcall(require, "profile_merger")
        if ok and PMerger then
            local parsed = PMerger.parse_ini(dir .. "/rtgameset_data.ini")
            if parsed and parsed.data then
                if parsed.data.Configs then
                    for k, v in pairs(parsed.data.Configs) do
                        existing_configs[k] = v
                    end
                end
                if parsed.data.GameSettings and parsed.data.GameSettings.ActiveConfig then
                    existing_active = parsed.data.GameSettings.ActiveConfig
                end
            end
        end
    end

    -- Merge new config into existing set
    existing_configs[filename] = item.set_name or label_clean

    -- If no active yet, promote the first config
    local active = existing_active or filename

    -- Write metadata
    write_meta(id, {
        GameID       = id,
        GameName     = item.game_name or "",
        System       = item.system or "GC",
        Region       = item.region or "",
        ActiveConfig = active,
        Description  = item.set_name or "Imported",
        Author       = "games_data.json",
        Version      = "1.0.0",
        Source       = "games_data.json",
        SourceURL    = item.set_url or "",
    }, existing_configs)

    return true
end

-- ── ext-dolphin scanning ────────────────────────────────────
function M.scan_ext_dolphin()
    local out = {}
    local dirs = { EXT_DIR, State.path("frontend/dolphin-emu/Config") }
    for _, dir in ipairs(dirs) do
        local h = io.popen('ls -1 ' .. shq(dir) .. ' 2>/dev/null')
        if h then
            local seen = {}
            for line in h:lines() do
                local base, suffix = line:match("^(.+)%.([^.]+)$")
                if base and suffix and KNOWN_TYPES[suffix] then
                    local key = base .. "." .. suffix
                    if not seen[key] then
                        seen[key] = true
                        table.insert(out, {
                            base   = base,
                            suffix = suffix,
                            file   = line,
                            path   = dir .. "/" .. line,
                        })
                    end
                end
            end
            h:close()
        end
        if #out > 0 then break end
    end
    return out
end

function M.import_ext_profile(entry, profile_name)
    local base = entry.base
    if not (base == "Dolphin.ini" or base == "GFX.ini") then
        return false, "Only Dolphin.ini and GFX.ini can be imported"
    end

    local f = io.open(entry.path, "r")
    if not f then return false, "Cannot read source" end
    f:close()

    local raw = profile_name or (entry.base:gsub("%.ini$", "") .. "_" .. entry.suffix)
    local name = raw:gsub("[^%w_%-%s]", ""):gsub("%s+", "_")
    if name == "" then return false, "invalid profile name" end

    local dir = "workshop/rtcoreprofile/" .. name
    os.execute("mkdir -p " .. shq(dir))

    os.execute("cp " .. shq(entry.path) .. " " .. shq(dir .. "/" .. entry.base))

    local mf = io.open(dir .. "/rtprofile_data.ini", "w")
    if mf then
        mf:write("[Profile]\n")
        mf:write("Name = " .. name .. "\n")
        mf:write("Type = Custom\n")
        mf:write("Description = Imported from muOS ext-dolphin (" .. entry.suffix .. ")\n")
        mf:write("Author = muOS\n")
        mf:write("Version = 1.0.0\n")
        mf:write("Date = " .. os.date("%Y-%m-%d") .. "\n\n")
        mf:write("[UI]\n")
        mf:write("Color = #4FA8C7\n")
        mf:write("BorderStyle = cut-right\n")
        mf:write("Icon = balanced\n")
        mf:write("Order = 200\n")
        mf:write("Tags = imported, ext\n\n")
        mf:write("[Runtime]\n")
        mf:write("RequiresBase = Default\n")
        mf:write("Locked = False\n")
        mf:close()
    end
    return true
end

return M
