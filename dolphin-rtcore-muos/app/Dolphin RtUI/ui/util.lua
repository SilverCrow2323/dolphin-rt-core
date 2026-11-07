-- ui/util.lua — tiny helpers shared by the screens (no drawing here).
local Ini = require("core.ini_edit")
local U = {}

-- Memo TTL: cache del risultato per N secondi (default 1.5).
local _memo = {}
local function _memo_now()
    if love and love.timer and love.timer.getTime then return love.timer.getTime() end
    return os.time()
end
function U.memo(key, ttl, fn)
    local now = _memo_now()
    local e = _memo[key]
    if e and (now - e.t) < (ttl or 1.5) then return e.v end
    local v = fn()
    _memo[key] = { v = v, t = now }
    return v
end
function U.memo_reset(key)
    if key then _memo[key] = nil else _memo = {} end
end

function U.ls(dir, dirs_only)
    local out = {}
    local p = io.popen("ls -1 " .. "'" .. dir:gsub("'", "'\\''") .. "'" .. " 2>/dev/null")
    if not p then return out end
    for l in p:lines() do
        if l ~= "" and l:sub(1, 1) ~= "." then out[#out + 1] = l end
    end
    p:close()
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

function U.exists(p) local f = io.open(p, "r"); if f then f:close(); return true end return false end

-- rtid card of a game (workshop/gameslibrary/rtid_<ID>.ini), cached
local cards = {}
function U.card_path(game)
    if not game or not game.id then return nil end
    return "workshop/gameslibrary/rtid_" .. tostring(game.id) .. ".ini"
end
function U.card(game)
    if not game or not game.id then return { path = nil, lines = {} } end
    local c = cards[game.id]
    if c then return c end
    local path = U.card_path(game)
    if not path then return { path = nil, lines = {} } end
    c = { path = path, lines = Ini.read_lines(path) or {} }
    cards[game.id] = c
    return c
end
function U.card_get(game, section, key)
    local v = Ini.get(U.card(game).lines, section, key)
    if v == nil or v == "" then return nil end
    return v
end
function U.card_set(game, section, key, value)
    local c = U.card(game)
    if #c.lines == 0 then
        c.lines = { "[GAME]", "ID = " .. game.id, "Title = " .. (game.title or game.id),
                    "System = " .. (game.system or ""), "" }
    end
    Ini.set(c.lines, section, key, value or "")
    Ini.write_lines(c.path, c.lines)
end
function U.card_reset() cards = {} end

-- Peso leggibile. Base 1024 (come `du -h` / file manager di muOS).
--   sconosciuto / illeggibile -> "—"   (prima: "0 KB", sembrava un file vuoto)
--   < 1 MB   -> "512 KB"      < 100 MB -> "12.4 MB"
--   < 1 GB   -> "743 MB"      >= 1 GB  -> "1.36 GB"
-- math.floor ovunque: string.format("%d", 1.5) esplode su Lua 5.3+.
function U.human_size(b)
    b = tonumber(b)
    if not b or b <= 0 then return "\226\128\148" end
    if b >= 1073741824 then return ("%.2f GB"):format(b / 1073741824) end
    if b >= 104857600  then return ("%d MB"):format(math.floor(b / 1048576 + 0.5)) end
    if b >= 1048576    then return ("%.1f MB"):format(b / 1048576) end
    return ("%d KB"):format(math.max(1, math.floor(b / 1024 + 0.5)))
end



-- ── pulizia titoli: toglie (PAL) (NTSC) (Europe) (Rev 1) ecc. ──
local TITLE_TAGS = {
    "pal", "ntsc", "ntsc%-u", "ntsc%-j", "ntsc%-k", "ntsc%-tw",
    "usa", "europe", "japan", "korea", "taiwan", "australia",
    "germany", "france", "italy", "spain", "netherlands",
    "en", "fr", "de", "es", "it", "ja", "ko", "zh", "ru", "nl",
    "beta", "proto", "prototype", "demo", "sample",
}
function U.clean_title(s)
    if not s or s == "" then return "" end
    local t = tostring(s)
    t = t:gsub("%s*%b()", function(m)
        local inner = m:sub(2, -2)
        local low = inner:lower():gsub("%s+$", "")
        for _, tag in ipairs(TITLE_TAGS) do
            if low == tag then return "" end
        end
        if low:match("^v%d+%.%d+") then return "" end
        if low:match("^rev%s*%w+") then return "" end
        return m
    end)
    t = t:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return t
end

function U.is_wii(g) return tostring(g and g.system or ""):lower() == "wii" end
function U.sys_label(g) return tostring(g and g.system or "GC"):upper() end

-- Rt:CORE families (RtBoost/RtPrime/RtPure...) are the ONLY profiles with
-- LITE / STANDARD / MAX tiers: their folder has lite/ std/ max/ inside.
local fam_cache = {}
function U.is_family(name)
    name = tostring(name or "")
    local v = fam_cache[name]
    if v == nil then
        v = false
        for _, t in ipairs({ "lite", "std", "max" }) do
            if U.exists("workshop/rtcoreprofile/" .. name .. "/" .. t .. "/Dolphin.ini") then v = true end
        end
        fam_cache[name] = v
    end
    return v
end

-- ── graphic mods ────────────────────────────────────────────
local EMU = (require("core.paths").root_emu)
function U.mods_installed()
    return U.memo("mods_installed", 2.0, function()
        local seen, out = {}, {}
        local base = require("core.mods").LOAD
        for _, d in ipairs({ base .. "/GraphicMods", base .. "/GraphicMods.off" }) do
            for _, n in ipairs(U.ls(d)) do if not seen[n] then seen[n] = true; out[#out + 1] = n end end
        end
        table.sort(out, function(a, b) return a:lower() < b:lower() end)
        return out
    end)
end
-- selected mods of a game: list of names, nil = none
function U.mods_selected(game)
    local v = U.card_get(game, "MODS", "Selected")
    local set, n = {}, 0
    if v then for name in v:gmatch("[^,]+") do set[name] = true; n = n + 1 end end
    return set, n
end
function U.mods_save(game, set)
    local names = {}
    for name in pairs(set) do names[#names + 1] = name end
    table.sort(names)
    U.card_set(game, "MODS", "Selected", table.concat(names, ","))
    U.card_set(game, "MODS", "GraphicMods", tostring(#names))
end

-- ── Mod Vault (Textures / WiiSDSync / Riivolution / DynamicInputTextures) ──
-- Salviamo le voci SPENTE per categoria: [MODS] <Cat>Off = a|b|c
-- (default = nessuna spenta = tutto cio' che e' applicabile al gioco e' attivo).
function U.vault_off(game, cat_id)
    if cat_id == "GraphicMods" then            -- legacy: salvato come elenco dei SELEZIONATI
        local sel = U.mods_selected(game)
        local set = {}
        for _, n in ipairs(U.mods_installed()) do if not sel[n] then set[n] = true end end
        return set
    end
    local v = U.card_get(game, "MODS", cat_id .. "Off")
    local set = {}
    if v then for name in v:gmatch("[^|]+") do set[name] = true end end
    return set
end
function U.vault_set_off(game, cat_id, set)
    if cat_id == "GraphicMods" then
        local sel = {}
        for _, n in ipairs(U.mods_installed()) do if not set[n] then sel[n] = true end end
        return U.mods_save(game, sel)
    end
    local names = {}
    for name in pairs(set) do names[#names + 1] = name end
    table.sort(names)
    U.card_set(game, "MODS", cat_id .. "Off", table.concat(names, "|"))
end
-- titoli equivalenti del gioco per il matching per nome
function U.vault_titles(game)
    local out, seen = {}, {}
    local function add(t)
        if type(t) == "string" and t ~= "" and not seen[t] then seen[t] = true; out[#out + 1] = t end
    end
    add(game.title); add(U.clean_title(game.title))
    local f = (game.file or ""):gsub("%.[^%.]+$", "")
    add(f); add(U.clean_title(f))
    local ok, C = pcall(require, "core.compatibility")
    if ok and C and C.lookup then
        local ok2, grp, approx = pcall(C.lookup, game)
        if ok2 and grp and not approx then add(grp.title) end
    end
    return out
end
-- (attive, totali) su tutte le categorie, per il badge in Game options
function U.vault_counts(game)
    if not game or not game.id then return 0, 0 end
    local r = U.memo("vault_counts:" .. game.id, 1.5, function()
        local Mods = require("core.mods")
        local on, total = 0, 0
        local titles = U.vault_titles(game)
        for _, cat in ipairs(Mods.CATS) do
            local off = U.vault_off(game, cat.id)
            for _, e in ipairs(Mods.for_game(cat, game, titles)) do
                total = total + 1
                if not off[e.name] then on = on + 1 end
            end
        end
        return { on, total }
    end)
    return r[1], r[2]
end

-- "Cheats enabled" non e' piu' un'opzione: i cheat sono attivi se almeno uno
-- del database e' acceso per il gioco.
function U.cheats_active(game)
    local ok, C = pcall(require, "core.rtcheats")
    if not ok or not C or not game or not game.id then return false end
    local ok2, list = pcall(C.load_for, game.id)
    if not ok2 or type(list) ~= "table" then return false end
    for _, e in ipairs(list) do if e.enabled then return true end end
    return false
end

-- ── titles (wiitdb: "ID = Title") ───────────────────────────
local titles
function U.titles()
    if titles then return titles end
    titles = {}
    local f = io.open("data/wiitdb.txt", "r")
    if f then
        for l in f:lines() do
            local id, t = l:match("^(%w+)%s*=%s*(.-)%s*$")
            if id and t and not l:match("^TITLES") then
                -- the UI font has no CJK/symbol glyphs: keep the Latin part only
                t = t:gsub("[\226-\244][\128-\191]*", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                -- titles that were mostly CJK/symbols fall back to the id
                if #(t:gsub("[^%w]", "")) >= 3 then titles[id] = t end
            end
        end
        f:close()
    end
    return titles
end
-- title for a database id that may be 3/4/6 chars long
local prefix_title
function U.title_for(id)
    local T = U.titles()
    if T[id] then return T[id], true end
    if not prefix_title then
        prefix_title = {}
        for full, t in pairs(T) do
            for _, n in ipairs({ 3, 4 }) do
                local p = full:sub(1, n)
                if not prefix_title[p] or t < prefix_title[p] then prefix_title[p] = t end
            end
        end
    end
    return prefix_title[id], false
end

function U.yes(v) v = tostring(v or ""):lower(); return v == "yes" or v == "true" or v == "1" or v == "on" end

-- one place that launches a game. Passes the full option set explicitly (the
-- same shape the 1.x launch screen used), writes what it does to
-- data/logs/ui.log, and tells the user when something stops the launch.
local function ulog(msg)
    pcall(function()
        local f = io.open("data/logs/ui.log", "a")
        if f then f:write(os.date("%H:%M:%S "), msg, "\n"); f:close() end
    end)
end

function U.launch(g)
    if not g then return end
    local Notify = require("ui.notify")
    local Settings = require("core.settings")
    local card = function(k, d) return U.card_get(g, "LAUNCH", k) or d end
    local opts = {
        profile    = card("RtProfile", "Default"),
        variant    = nil,                               -- set below: families only
        controller = card("Controller", "Default"),
        hotkeys    = card("Hotkeys", "Default"),
        gamesettings = (function()
            local v = card("GameSettings", "")
            if v == "" or v == "Disabled" then return nil end
            return v
        end)(),
        cheats     = U.cheats_active(g),
        mods       = nil,                               -- set below
        show_fps   = U.yes(card("OverlayFPS", "no")),
        show_vps   = U.yes(card("OverlayVPS", "no")),
        show_speed = U.yes(card("OverlaySpeed", "no")),
        show_osd   = card("OverlayOSD", "yes") ~= "no",
        safe_exit  = U.yes(card("SafeExit", "yes")),
        return_to  = "library",
        orient     = Settings.get("orient") or "upright",
    }
    if U.is_family(opts.profile) then opts.variant = card("RtProfileVariant", "std") end
    local _, nmods = U.mods_selected(g)
    if nmods > 0 then opts.mods = U.card_get(g, "MODS", "Selected") else opts.mods = "none" end
    -- GameSettings: unica fonte di verità. Scrive sia il card LAUNCH che il
    -- metadata rtgameset_data.ini/ActiveConfig (che il merge Python legge).
    if opts.gamesettings and opts.gamesettings ~= "" then
        pcall(function()
            local GM = require("core.gameset_manager")
            GM.set_active(g.id, opts.gamesettings)
        end)
    end
    -- write enabled Boost/cheat codes into Dolphin only when there are any
    pcall(function()
        local C = require("core.rtcheats")
        for _, e in ipairs(C.load_for(g.id)) do
            if e.enabled then C.apply(g.id); break end
        end
    end)
    -- Mod Vault: piano per scripts/launch.sh (spegne/riaccende/linka le voci)
    pcall(function()
        require("core.mods").write_plan(g, U.vault_titles(g), function(cat) return U.vault_off(g, cat) end)
    end)
    Settings.set("last_game", g.id)
    require("ui.sfx").play("menu_select")
    ulog(("launch %s [%s] rom=%s profile=%s/%s controller=%s hotkeys=%s cheats=%s mods=%s"):format(
        tostring(g.id), tostring(g.system), tostring(g.path), opts.profile, tostring(opts.variant),
        opts.controller, opts.hotkeys, tostring(opts.cheats), tostring(opts.mods)))
    local ok, res = pcall(require("core.launcher").launch, g, opts)
    if not ok then
        ulog("launch error: " .. tostring(res))
        Notify.show("error", "Launch failed: " .. tostring(res))
    elseif res == false then
        ulog("launcher returned false (dev mode, missing ROM path or launch.sh)")
    end
end

return U
