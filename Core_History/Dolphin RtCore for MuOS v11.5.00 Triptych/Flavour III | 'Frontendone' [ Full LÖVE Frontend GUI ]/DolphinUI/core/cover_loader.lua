-- core/cover_loader.lua — v2.0 "front-only, no crop"
-- Scarica direttamente la front cover da GameTDB.
-- URL: https://art.gametdb.com/wii/cover/{REGION}/{GAMEID}.png
-- Cache: data/covers/<ID>.png
-- API:
--   M.get(game)     -> Image | nil   (scarica in bg se manca)
--   M.refresh(game) -> svuota cache di quel gioco
--   M.clear_all()   -> svuota tutta la cache
--   M.stats()       -> { cached=N }

local sh = require("core.sh")
local M = {}

local DIR = "data/covers"
local RAW = "data/covers/_raw"   -- tmp per download in corso

local _cache = {}         -- id -> { state = "ready"|"loading"|"failed", img = Image }
local _last_sweep = 0
local SWEEP = 2.0
local RETRY_SEC = 60

-- ── region da GameID (4° carattere) ───────────────────────
local function region_of(id)
    if not id or #id < 4 then return "US" end
    local r = id:sub(4,4)
    if r == "E" or r == "N" then return "US"
    elseif r == "P" or r == "D" or r == "F" or r == "I"
        or r == "S" or r == "X" or r == "H" or r == "Y" then return "EN"
    elseif r == "J" or r == "K" or r == "W" then return "JA"
    elseif r == "A" then return "US"   -- fallback per qualche titolo
    end
    return "US"
end

local function url_for(id)
    if not id or #id ~= 6 then return nil end
    return string.format("https://art.gametdb.com/wii/cover/%s/%s.png",
                         region_of(id), id)
end

-- ── path helpers ──────────────────────────────────────────
local function cover_path(id) return DIR .. "/" .. id .. ".png" end
local function raw_path(id)   return RAW .. "/" .. id .. ".png" end

local function exists(p)
    local f = io.open(p, "rb"); if f then f:close(); return true end
    return false
end

local function is_png(p)
    local f = io.open(p, "rb")
    if not f then return false end
    local head = f:read(8) or ""
    f:close()
    return head:sub(1,8) == "\137PNG\r\n\26\n"
end

local function ensure_dirs()
    sh.mkdir_p(DIR); sh.mkdir_p(RAW)
end

-- ── download in background ────────────────────────────────
local function spawn_download(id)
    ensure_dirs()
    local url = url_for(id)
    if not url then return end
    local out = raw_path(id)
    local tmp = out .. ".part"
    local inner = string.format(
        "if command -v curl >/dev/null 2>&1; then " ..
        "curl -fsSL --max-time 15 --retry 2 --retry-delay 1 -A 'RtUI/2' -o %s %s; " ..
        "elif command -v wget >/dev/null 2>&1; then " ..
        "wget -q -T 15 --tries=2 -U 'RtUI/2' -O %s %s; " ..
        "fi",
        sh.shq(tmp), sh.shq(url), sh.shq(tmp), sh.shq(url))
    os.execute("setsid sh -c " .. sh.shq(inner) ..
               " </dev/null >/dev/null 2>&1 &")
end

-- ── sweep dei raw: promuovi a cover_path i download completati ─
local function sweep_raw()
    if not sh.is_dir(RAW) then return end
    local h = io.popen("ls -1 " .. sh.shq(RAW) .. "/*.part 2>/dev/null")
    if not h then return end
    local jobs = {}
    for l in h:lines() do jobs[#jobs+1] = l end
    h:close()
    for _, p in ipairs(jobs) do
        local id = p:match("([A-Z0-9]+)%.png%.part$")
        if id and #id == 6 and is_png(p) then
            os.remove(cover_path(id))
            os.rename(p, cover_path(id))
            if _cache[id] then _cache[id] = nil end
        end
    end
    -- cleanup part orfani (>90s)
    os.execute("find " .. sh.shq(RAW) ..
        " -name '*.part' -mmin +2 -delete 2>/dev/null")
end

-- ── API ───────────────────────────────────────────────────
function M.update(_)
    local now = love and love.timer and love.timer.getTime() or os.time()
    if now - _last_sweep < SWEEP then return end
    _last_sweep = now
    sweep_raw()
end

function M.get(game)
    if not game or not game.id then return nil end
    local id = game.id
    if _cache[id] then
        local c = _cache[id]
        if c.state == "ready" then return c.img end
        if c.state == "loading" then return nil end
        if c.state == "failed" then
            local now = os.time()
            if now - (c.at or 0) < RETRY_SEC then return nil end
        end
    end

    -- 1) cover gia' in cache su disco
    local p = cover_path(id)
    if exists(p) and is_png(p) then
        local ok, img = pcall(love.graphics.newImage, p)
        if ok and img then
            img:setFilter("linear", "linear")
            _cache[id] = { state = "ready", img = img }
            return img
        end
        os.remove(p)   -- corrotto, ritenta
    end

    -- 2) cerca un .part gia' pronto
    local part = raw_path(id) .. ".part"
    if exists(part) and is_png(part) then
        os.rename(part, p)
        return M.get(game)
    end

    -- 3) nessun download in corso: lancia
    if not (_cache[id] and _cache[id].state == "loading") then
        _cache[id] = { state = "loading" }
        spawn_download(id)
    end
    return nil
end

function M.refresh(game)
    if not game or not game.id then return false end
    local id = game.id
    os.remove(cover_path(id))
    os.remove(raw_path(id) .. ".part")
    _cache[id] = nil
    return true
end

function M.clear_all()
    os.execute("rm -f " .. DIR .. "/*.png 2>/dev/null")
    os.execute("rm -f " .. RAW .. "/*.part 2>/dev/null")
    _cache = {}
end

function M.stats()
    local h = io.popen("ls -1 " .. DIR .. "/*.png 2>/dev/null | wc -l")
    local n = 0
    if h then n = tonumber(h:read("*a")) or 0; h:close() end
    return { cached = n }
end

return M
