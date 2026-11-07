-- frontend/covers.lua
-- Cover art: local lookup + remote fetch from GameTDB.
--
-- ── v0.6.0 — robust remote fetch ─────────────────────────────
--   * User-Agent header added to curl/wget. GameTDB serves some
--     endpoints with a stricter CDN that rejects requests without
--     a UA. This was the primary cause of 403 / empty responses.
--   * URL patterns: for each game we try `cover/` then `cover3D/`
--     against the game's own region first (parsed from position 4
--     of the GameID), then US, then EN.
--   * Every attempt is logged to `data/covers/_download.log` so
--     the user can inspect failures.
--   * Session-level failure cache has a 60-second TTL, not a
--     permanent mark. A cover missed once can succeed later.
--   * Title-based fallback URL removed (GameTDB does not accept
--     arbitrary title strings; only GameIDs work).

local json = require("json")
local sh   = require("sh")

local M = { cache = {}, loaded = false }

-- Tunables
local SAVE_DEBOUNCE   = 2.0
local EXT_LIST        = { "png", "jpg", "jpeg", "webp" }
local LOCAL_SUBDIRS   = { "media", "images", "boxart", "covers", "artwork" }

local TDB_BASE        = "https://art.gametdb.com"
local TDB_TIMEOUT_S   = 15
local REMOTE_DIR      = "data/covers"
local REMOTE_POLL     = 0.4
local REMOTE_MAX_Q    = 8
local FAIL_TTL        = 60   -- seconds

-- ── Session state ───────────────────────────────────────────
local _last_save_t = 0
local _dirty       = false

local _pending       = {}   -- key -> entry
local _queue         = {}   -- array
local _queued_ids    = {}   -- set
local _remote_result = {}   -- key -> { path=..., t=..., failed=bool }

-- ── Paths ───────────────────────────────────────────────────
local _state = nil
local function get_state()
    if not _state then
        local ok, s = pcall(require, "state")
        if ok then _state = s end
    end
    return _state
end

local function frontend_dir()
    local s = get_state()
    if s and s.root then return s.root() .. "/frontend" end
    return "."
end

local function cache_file()
    return frontend_dir() .. "/data/_covers_cache.json"
end

local function log_file()
    return frontend_dir() .. "/data/covers/_download.log"
end

-- ── Debug log ───────────────────────────────────────────────
local function log_dl(msg)
    local path = log_file()
    os.execute("mkdir -p " .. sh.shq(REMOTE_DIR) .. " 2>/dev/null")
    local f = io.open(path, "a")
    if f then
        f:write(string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), msg))
        f:close()
    end
end

-- ── Filesystem ──────────────────────────────────────────────
local function file_exists(p)
    local f = io.open(p, "rb")
    if f then f:close(); return true end
    return false
end

local function file_size(p)
    local f = io.open(p, "rb")
    if not f then return 0 end
    f:seek("end")
    local sz = f:seek()
    f:close()
    return sz or 0
end

local function atomic_write(path, content)
    local tmp = path .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return false end
    f:write(content)
    f:close()
    if os.rename(tmp, path) then return true end
    sh.exec("cp " .. sh.shq(tmp) .. " " .. sh.shq(path))
    os.remove(tmp)
    return true
end

-- ══════════════════════════════════════════════════════════════
--  ID EXTRACTION
-- ══════════════════════════════════════════════════════════════
local INVALID_IDS = {
    RVZ = true, WBFS = true, WIA = true,
    ISO = true, GCM = true, GCZ = true, NKIT = true,
}

local function is_valid_id(s)
    if type(s) ~= "string" or #s ~= 6 then return false end
    if INVALID_IDS[s] then return false end
    return s:match("^[A-Z][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$") ~= nil
end
M.is_valid_id = is_valid_id

local function extract_id(rom)
    if not rom then return nil end
    if is_valid_id(rom.id) then return rom.id end
    local base = (rom.file or rom.title or "")
    if base == "" then return nil end
    base = base:gsub("%.[^.]+$", "")
    local id = base:match("%(([A-Z][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])%)")
            or base:match("%[([A-Z][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])%]")
    if is_valid_id(id) then return id end
    return nil
end

-- GameTDB system slug
local function tdb_system(rom)
    if rom and rom.sys == "Wii" then return "wii" end
    return "gamecube"
end

-- Regions to try, in order, based on the 4th char of the GameID.
-- GameTDB region codes: US, EN, DE, FR, ES, IT, NL, PT, RU, JA, KO, ZH, TW.
local function region_chain(id)
    if type(id) ~= "string" or #id < 4 then
        return { "US", "EN", "JA" }
    end
    local r4 = id:sub(4, 4)
    if     r4 == "E" then return { "US", "EN", "DE", "FR", "ES", "IT" }
    elseif r4 == "P" then return { "EN", "DE", "FR", "ES", "IT", "US" }
    elseif r4 == "J" then return { "JA" }
    elseif r4 == "K" then return { "KO" }
    elseif r4 == "W" then return { "US", "EN" }
    else                  return { "US", "EN", "JA" } end
end

local function remote_path_for(key)
    return REMOTE_DIR .. "/" .. key .. ".png"
end

-- ══════════════════════════════════════════════════════════════
--  CACHE
-- ══════════════════════════════════════════════════════════════
local function load_cache()
    if M.loaded then return end
    M.loaded = true
    local f = io.open(cache_file(), "r")
    if not f then return end
    local c = f:read("*a"); f:close()
    local ok, d = pcall(json.decode, c)
    if not ok or type(d) ~= "table" then return end
    for k, v in pairs(d) do
        if type(k) == "string" and type(v) == "string" then
            M.cache[k] = v
        end
    end
end

local function save_cache_now()
    local persist = {}
    for k, v in pairs(M.cache) do
        if type(v) == "string" then persist[k] = v end
    end
    atomic_write(cache_file(), json.encode(persist))
    _last_save_t = os.time()
    _dirty       = false
end

local function save_cache_debounced()
    if not _dirty then return end
    if os.time() - _last_save_t < SAVE_DEBOUNCE then return end
    save_cache_now()
end

function M.flush()
    if _dirty then save_cache_now() end
end

-- ══════════════════════════════════════════════════════════════
--  LOCAL LOOKUP
-- ══════════════════════════════════════════════════════════════
local function local_candidates(rom)
    local base = (rom.file or ""):gsub("%.[^.]+$", "")
    if base == "" then return {} end
    local dir = rom.path and rom.path:match("^(.+)/[^/]+$") or "."
    local fe  = frontend_dir()
    local out = {}
    for _, e in ipairs(EXT_LIST) do
        for _, sub in ipairs(LOCAL_SUBDIRS) do
            out[#out + 1] = dir .. "/" .. sub .. "/" .. base .. "." .. e
        end
        out[#out + 1] = dir .. "/" .. base .. "." .. e
        out[#out + 1] = fe .. "/media/covers/" .. base .. "." .. e
        out[#out + 1] = fe .. "/data/covers/" .. base .. "." .. e
    end
    return out
end

local function cache_key(rom)
    return rom.path or rom.file or rom.title
end

function M.find(rom)
    if not rom or not rom.file then return nil end
    load_cache()
    local key = cache_key(rom)
    if not key then return nil end
    local cached = M.cache[key]
    if type(cached) == "string" then return cached end
    if cached == false then return nil end
    for _, p in ipairs(local_candidates(rom)) do
        if file_exists(p) then
            M.cache[key] = p
            _dirty = true
            save_cache_debounced()
            return p
        end
    end
    M.cache[key] = false
    return nil
end

-- ══════════════════════════════════════════════════════════════
--  REMOTE FETCH
-- ══════════════════════════════════════════════════════════════
local function read_marker(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local v = f:read("*a"); f:close()
    if not v or v == "" then return nil end
    return tonumber(v)
end

local function build_urls(rom)
    local urls = {}
    local id = extract_id(rom)
    if not id then return urls end
    local sys = tdb_system(rom)
    local regions = region_chain(id)

    -- Try flat cover for each region
    for _, region in ipairs(regions) do
        urls[#urls + 1] = {
            url    = string.format("%s/%s/cover/%s/%s.png",
                TDB_BASE, sys, region, id),
            region = region,
            kind   = "cover",
        }
    end
    -- Then 3D cover (fallback)
    for _, region in ipairs(regions) do
        urls[#urls + 1] = {
            url    = string.format("%s/%s/cover3D/%s/%s.png",
                TDB_BASE, sys, region, id),
            region = region,
            kind   = "cover3D",
        }
    end
    return urls
end

local function spawn_attempt(entry)
    if entry.idx > #entry.urls then return false end
    local u = entry.urls[entry.idx]
    if not u then return false end

    os.remove(entry.mark)
    os.remove(entry.dest)
    os.remove(entry.dest .. ".part")

    os.execute("mkdir -p " .. sh.shq(REMOTE_DIR))

    -- Build a shell script per attempt.
    -- Adds User-Agent so GameTDB CDN responds.
    local ua = 'Mozilla/5.0 (DolphinUI)'  -- simple UA, GameTDB-friendly
    local body = table.concat({
        "set +e",
        -- Try curl first
        "curl -fsSL -A " .. sh.shq(ua) ..
            " --connect-timeout 5 --max-time " .. TDB_TIMEOUT_S ..
            " -o " .. sh.shq(entry.dest .. ".part") .. " " ..
            sh.shq(u.url) .. " 2>/dev/null",
        "rc=$?",
        "if [ $rc -ne 0 ]; then",
        "  wget -q --user-agent=" .. sh.shq(ua) ..
            " --timeout=10 --tries=1 -O " .. sh.shq(entry.dest .. ".part") ..
            " " .. sh.shq(u.url) .. " 2>/dev/null",
        "  rc=$?",
        "fi",
        "if [ $rc -eq 0 ] && [ -s " .. sh.shq(entry.dest .. ".part") .. " ]; then",
        "  mv -f " .. sh.shq(entry.dest .. ".part") .. " " ..
            sh.shq(entry.dest) .. " 2>/dev/null || rc=1",
        "else",
        "  rm -f " .. sh.shq(entry.dest .. ".part"),
        "  [ $rc -eq 0 ] && rc=1",   -- empty file counts as failure
        "fi",
        "echo $rc > " .. sh.shq(entry.mark),
    }, "\n")

    local sh_path = "/tmp/dolphinui_cover_" .. entry.safe_key .. ".sh"
    local f = io.open(sh_path, "w")
    if not f then return false end
    f:write("#!/bin/sh\n")
    f:write(body .. "\n")
    f:close()
    os.execute("chmod +x " .. sh.shq(sh_path))
    os.execute("setsid sh " .. sh.shq(sh_path) ..
        " </dev/null >/dev/null 2>&1 &")
    log_dl(string.format("[%s] try %d/%d: %s",
        entry.key, entry.idx, #entry.urls, u.url))
    return true
end

function M.remote_lookup(rom)
    if not rom then return nil end
    local id = extract_id(rom)
    if not id then return nil end

    local entry = _remote_result[id]
    if entry then
        if entry.failed then
            -- Failed recently? Report nil unless TTL elapsed.
            if os.time() - entry.t < FAIL_TTL then return nil end
            _remote_result[id] = nil
        elseif entry.path then
            return entry.path
        end
    end

    local path = remote_path_for(id)
    if file_exists(path) and file_size(path) > 200 then
        _remote_result[id] = { path = path, t = os.time() }
        return path
    end
    return nil
end

function M.request_remote(rom)
    if not rom then return end
    local id = extract_id(rom)
    if not id then return end

    -- Already resolved?
    local r = _remote_result[id]
    if r then
        if r.path then return end
        if r.failed and os.time() - r.t < FAIL_TTL then return end
    end
    if _pending[id] or _queued_ids[id] then return end
    if #_queue >= REMOTE_MAX_Q then return end

    local urls = build_urls(rom)
    if #urls == 0 then return end

    _queued_ids[id] = true
    _queue[#_queue + 1] = {
        key  = id,
        urls = urls,
    }
end

local function start_next_queued()
    if #_queue == 0 then return end
    local active = 0
    for _ in pairs(_pending) do active = active + 1 end
    if active >= 3 then return end

    local job = table.remove(_queue, 1)
    if not job then return end
    _queued_ids[job.key] = nil

    local safe_key = job.key:gsub("[^%w_%-]", "_")
    local entry = {
        key      = job.key,
        safe_key = safe_key,
        urls     = job.urls,
        idx      = 1,
        t        = 0,
        poll_t   = 0,
        dest     = remote_path_for(job.key),
        mark     = "/tmp/dolphinui_cover_" .. safe_key .. ".done",
    }
    _pending[job.key] = entry
    spawn_attempt(entry)
end

function M.update_remote(dt)
    start_next_queued()

    local finished = nil
    for key, entry in pairs(_pending) do
        entry.t      = entry.t + dt
        entry.poll_t = entry.poll_t + dt
        if entry.poll_t >= REMOTE_POLL then
            entry.poll_t = 0
            local rc = read_marker(entry.mark)

            if rc == 0 then
                os.remove(entry.mark)
                local sz = file_size(entry.dest)
                if sz > 200 then
                    pcall(function()
                        local A = require("assets")
                        if A.invalidate_image then A.invalidate_image(entry.dest) end
                    end)
                    _remote_result[key] = { path = entry.dest, t = os.time() }
                    log_dl(string.format("[%s] OK  %s  (%d bytes)",
                        key, entry.dest, sz))
                else
                    _remote_result[key] = { failed = true, t = os.time() }
                    log_dl(string.format("[%s] EMPTY %s  (%d bytes)",
                        key, entry.dest, sz))
                end
                if not finished then finished = {} end
                finished[#finished + 1] = key

            elseif type(rc) == "number" then
                os.remove(entry.mark)
                os.remove(entry.dest)
                entry.idx = entry.idx + 1
                if entry.idx > #entry.urls then
                    _remote_result[key] = { failed = true, t = os.time() }
                    log_dl(string.format("[%s] FAIL all URLs (rc=%d)", key, rc))
                    if not finished then finished = {} end
                    finished[#finished + 1] = key
                else
                    spawn_attempt(entry)
                    entry.t = 0
                end

            elseif entry.t > TDB_TIMEOUT_S + 8 then
                os.remove(entry.dest)
                _remote_result[key] = { failed = true, t = os.time() }
                log_dl(string.format("[%s] TIMEOUT", key))
                if not finished then finished = {} end
                finished[#finished + 1] = key
            end
        end
    end

    if finished then
        for _, key in ipairs(finished) do
            _pending[key] = nil
        end
        start_next_queued()
    end
end

function M.resolve(rom)
    local p = M.find(rom)
    if p then return p end
    p = M.remote_lookup(rom)
    if p then return p end
    M.request_remote(rom)
    return nil
end

-- Manual reset for the fail cache (used by the "Retry covers" action)
function M.reset_failures()
    _remote_result = {}
end

function M.remote_log_tail(n)
    n = n or 20
    local f = io.open(log_file(), "r")
    if not f then return {} end
    local lines = {}
    for line in f:lines() do
        lines[#lines + 1] = line
    end
    f:close()
    local start = math.max(1, #lines - n + 1)
    local out = {}
    for i = start, #lines do out[#out + 1] = lines[i] end
    return out
end

return M
