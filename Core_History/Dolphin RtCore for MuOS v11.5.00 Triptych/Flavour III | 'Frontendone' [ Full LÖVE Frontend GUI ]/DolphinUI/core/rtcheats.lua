-- core/rtcheats.lua — Rogue cheat database, two layers, per game.
--
--   Layer 1  Rogue DB: ONE FILE PER GAME, <GAMEID>.ini, downloaded on demand
--            from the Dolphin-Core-for-MuOS repo (data/database/cheats_db/).
--            data/rtcheats_db.json is the index: { gameid, performance_boost,
--            download_url } for every game that has a file.
--   Layer 2  rtcheats_data.ini (yours, always wins over the Rogue DB)
--
-- Per-game file format:
--   [GAMEID]                  comments "# -- <group heading>" + toggles
--                             slug = disabled|enabled  (boost entries)
--   [GAMEID.slug]             Name, Type (Gecko|ActionReplay), Enabled,
--                             Boost = true (performance patch),
--                             Codes (first code on the key line, the rest on
--                             indented continuation lines)
-- The file may be named with a 6-char id (GM4E01), a 4-char id (PA3J) or a
-- 3-char id (GE4: all regions); a game uses every file whose id is a prefix.
--
-- Pure Lua, no love.*: usable from tools and tests.

local M = {}

M.INDEX_FILE = "data/rtcheats_db.json"
M.DIRS = {                      -- where <GAMEID>.ini files live
    "data/cheats_db",
    "/opt/muos/share/emulator/dolphin/cheats_db",
    "workshop/db/cheats_db",
}
M.USER_DIRS = { "workshop/db", "/opt/muos/share/emulator/dolphin" }
M.USER_FILE = "rtcheats_data.ini"
M.SYNC_SCRIPT = "scripts/rtcheats_sync.sh"
M.SYNC_STATUS = "data/rtcheats_sync.status"
M.TAG = "[Rt] "                       -- prefix of every code we write to Dolphin

M.PCLASS_ORDER = { "speed", "compat", "lock30", "visual", "diag" }
M.PCLASS_LABEL = {
    speed  = "Speed hacks",
    compat = "Hang & compatibility fixes",
    lock30 = "30 FPS locks",
    visual = "Lighter visuals",
    diag   = "FPS counters",
    fps60  = "60 FPS patches",
    other  = "Other",
}

-- ── tiny helpers ────────────────────────────────────────────
local function exists(p)
    local f = io.open(p, "r"); if f then f:close(); return true end
    return false
end
local function slurp(p)
    local f = io.open(p, "r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function truthy(v)
    v = tostring(v or ""):lower()
    return v == "true" or v == "1" or v == "yes" or v == "on" or v == "enabled"
end
local function split_lines(text)
    local out = {}
    for l in (text or ""):gmatch("([^\n]*)\n?") do out[#out + 1] = (l:gsub("\r$", "")) end
    if out[#out] == "" then out[#out] = nil end
    return out
end
local function shq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function write_atomic(path, text)
    local ok, Sh = pcall(require, "core.shell")
    if ok and Sh and Sh.atomic_write then
        local ok2, r = pcall(Sh.atomic_write, path, text)
        if ok2 and r then return true end
    end
    local tmp = path .. ".tmp"
    local f = io.open(tmp, "w"); if not f then return false end
    f:write(text); f:close()
    os.remove(path)
    return os.rename(tmp, path) and true or false
end
local function mkdir_p(dir) os.execute("mkdir -p " .. shq(dir) .. " 2>/dev/null") end
local function writable_dir(list)
    for _, d in ipairs(list) do
        mkdir_p(d)
        local probe = d .. "/.rtw"
        local f = io.open(probe, "w")
        if f then f:close(); os.remove(probe); return d end
    end
end

-- ── ids ─────────────────────────────────────────────────────
-- GM4E01 -> { "GM4E01", "GM4E", "GM4" } (most specific first)
local function candidates(gid)
    gid = tostring(gid or "")
    local out = { gid }
    if #gid > 4 then out[#out + 1] = gid:sub(1, 4) end
    if #gid > 3 then out[#out + 1] = gid:sub(1, 3) end
    return out
end

-- ── index (data/rtcheats_db.json) ───────────────────────────
local INDEX
function M.index()
    if INDEX then return INDEX end
    INDEX = {}
    local text = slurp(M.INDEX_FILE)
    if text then
        local ok, J = pcall(require, "core.json")
        local ok2, arr = false, nil
        if ok and J then ok2, arr = pcall(J.decode, text) end
        if ok2 and type(arr) == "table" then
            for _, e in ipairs(arr) do
                if e.gameid then
                    INDEX[e.gameid] = { boost = e.performance_boost == true, url = e.download_url }
                end
            end
        end
    end
    return INDEX
end

-- the index ids that cover a game, with their boost flag
local function index_hits(gid)
    local idx, out = M.index(), {}
    if type(gid) ~= "string" or gid == "" then return out end
    for _, c in ipairs(candidates(gid)) do
        if idx[c] then out[#out + 1] = { id = c, boost = idx[c].boost } end
    end
    return out
end

function M.in_index(gid) return #index_hits(gid) > 0 end
local BOOST_MEMO = {}
function M.has_boost(gid)
    if type(gid) ~= "string" or gid == "" then return false end
    local v = BOOST_MEMO[gid]
    if v == nil then
        v = false
        for _, h in ipairs(index_hits(gid)) do if h.boost then v = true end end
        BOOST_MEMO[gid] = v
    end
    return v
end

-- ── locating files ──────────────────────────────────────────
local function file_for(id)
    for _, d in ipairs(M.DIRS) do
        local p = d .. "/" .. id .. ".ini"
        if exists(p) then return p end
    end
end

function M.db_dir() return writable_dir(M.DIRS) end

function M.user_path()
    for _, d in ipairs(M.USER_DIRS) do
        local p = d .. "/" .. M.USER_FILE
        if exists(p) then return p end
    end
    local d = writable_dir(M.USER_DIRS) or "workshop/db"
    return d .. "/" .. M.USER_FILE
end

-- ids (from the index) that cover this game but have no local file yet
function M.missing(gid)
    local out = {}
    for _, h in ipairs(index_hits(gid)) do
        if not file_for(h.id) then out[#out + 1] = h.id end
    end
    return out
end

function M.status()
    local idx = M.index()
    local n = 0
    for _ in pairs(idx) do n = n + 1 end
    local files = 0
    for _, d in ipairs(M.DIRS) do
        local p = io.popen("ls " .. shq(d) .. " 2>/dev/null | grep -c '\\.ini$'")
        if p then files = files + (tonumber(p:read("*a")) or 0); p:close() end
    end
    return { index = { present = n > 0, count = n }, files = files,
             user = { present = exists(M.user_path()), path = M.user_path() } }
end

-- ── background download ─────────────────────────────────────
-- Starts scripts/rtcheats_sync.sh in the background for the given ids.
function M.sync(ids, force)
    if not ids or #ids == 0 then return false end
    os.remove(M.SYNC_STATUS)               -- no stale "ok" from a previous run
    local q = {}
    for _, id in ipairs(ids) do q[#q + 1] = shq(id) end
    os.execute(("%s sh %s %s >/dev/null 2>&1 &"):format(force and "FORCE=1" or "",
               shq(M.SYNC_SCRIPT), table.concat(q, " ")))
    return true
end

-- { state = running|ok|fail|idle, msg, done, total }
function M.sync_status()
    local t = slurp(M.SYNC_STATUS)
    if not t then return { state = "idle", done = 0, total = 0 } end
    local st = { state = t:match("state=(%w+)") or "idle", msg = t:match("msg=([^\n]*)") or "",
                 done = tonumber(t:match("done=(%d+)")) or 0, total = tonumber(t:match("total=(%d+)")) or 0 }
    return st
end

-- ── parsing ─────────────────────────────────────────────────
local HEAD_CLASS = {
    { "counter", "diag" }, { "30 fps", "lock30" }, { "30fps", "lock30" }, { "frame", "lock30" },
    { "speed", "speed" }, { "hang", "compat" }, { "compat", "compat" }, { "crash", "compat" },
    { "fix", "compat" }, { "visual", "visual" }, { "blur", "visual" }, { "bloom", "visual" },
    { "shadow", "visual" }, { "reducer", "visual" }, { "light", "visual" },
}
local function heading_class(text)
    text = text:lower()
    for _, h in ipairs(HEAD_CLASS) do if text:find(h[1], 1, true) then return h[2] end end
end

-- returns a flat list of entries { slug, name, type, codes, notes, enabled,
-- boost, group?, class? } and per-slug toggles/heading classes.
local function parse(text)
    local out = { entries = {}, toggles = {}, heads = {} }
    local sec, cur, lastkey, heading
    for _, raw in ipairs(split_lines(text)) do
        local line = trim(raw)
        local name = line:match("^%[([^%]]+)%]$")
        if name then
            lastkey, heading = nil, nil
            local g, slug = name:match("^(%w+)%.(.+)$")
            if slug then
                sec = "entry"
                cur = { slug = slug, gid = g, codes = {}, notes = {} }
                out.entries[#out.entries + 1] = cur
            else
                sec, cur = "toggle", nil
            end
        elseif line:sub(1, 1) == "#" or line:sub(1, 1) == ";" then
            if sec == "toggle" then
                local h = line:match("^#%s*%-%-%s*(.+)$")
                if h then heading = heading_class(h) or heading end
            end
        elseif line ~= "" then
            local k, v = line:match("^([%w_%-%.]+)%s*=%s*(.-)%s*$")
            if k and sec == "entry" then
                local lk = k:lower()
                lastkey = lk
                if lk == "name" then cur.name = v
                elseif lk == "type" then cur.type = v
                elseif lk == "enabled" then cur.enabled = truthy(v); cur.has_enabled = true
                elseif lk == "boost" then cur.boost = truthy(v)
                elseif lk == "class" or lk == "pclass" then cur.class = v:lower()
                elseif lk == "group" then cur.group = v:lower()
                elseif lk == "note" or lk == "notes" then cur.notes[#cur.notes + 1] = v
                elseif lk:match("^codes?%d*$") then
                    for c in (v .. "|"):gmatch("([^|;]*)[|;]") do
                        c = trim(c); if c ~= "" then cur.codes[#cur.codes + 1] = c end
                    end
                end
            elseif k and sec == "toggle" then
                out.toggles[k] = truthy(v)
                if heading then out.heads[k] = heading end
            elseif sec == "entry" and lastkey and lastkey:match("^codes?%d*$")
                   and line:match("^[%x]+%s+[%x]+") then
                cur.codes[#cur.codes + 1] = line           -- continuation line
            end
        end
    end
    return out
end

-- ── classification ──────────────────────────────────────────
local function classify(e, head_class)
    local hay = ((e.name or "") .. " " .. (e.type or "")):lower()
    local grp, pc = e.group, e.class
    if not grp then
        if hay:match("60%s*fps") or hay:match("60%s*hz") or hay:match("60fps") then
            grp, pc = "fps", pc or "fps60"
        elseif e.boost then grp = "perf"
        else grp = "cheat" end
    end
    if grp == "perf" and not pc then
        pc = head_class
        if not pc then
            if     hay:match("fps%s*counter") or hay:match("show%s*fps") then pc = "diag"
            elseif hay:match("30%s*fps") or hay:match("frame%s*lock") or hay:match("frame%s*limit") then pc = "lock30"
            elseif hay:match("hang") or hay:match("freeze") or hay:match("crash") or hay:match("black%s*screen")
                   or hay:match("compat") or hay:match("fix") then pc = "compat"
            elseif hay:match("bloom") or hay:match("blur") or hay:match("shadow") or hay:match("lighter")
                   or hay:match("low%s*qual") or hay:match("reduce") or hay:match("effect")
                   or hay:match("draw%s*dist") or hay:match("lod") then pc = "visual"
            else pc = "speed" end
        end
    end
    e.group, e.pclass = grp, pc
end

-- ── cache (M.reload() to drop it) ───────────────────────────
local USER
local CACHE = {}

local function load_user()
    local p = M.user_path()
    local text = exists(p) and slurp(p) or ""
    local d = parse(text)
    -- the user file keeps its game toggles as [GAMEID] slug = true|false;
    -- parse() sees one flat toggle list, so re-read it per game here
    local by_game, sec = {}, nil
    for _, l in ipairs(split_lines(text)) do
        local name = l:match("^%[([^%]]+)%]$")
        if name then sec = (not name:find(".", 1, true)) and name or nil
        elseif sec then
            local k, v = l:match("^%s*([%w_%-%.]+)%s*=%s*(.-)%s*$")
            if k then by_game[sec] = by_game[sec] or {}; by_game[sec][k] = truthy(v) end
        end
    end
    USER = { path = p, text = text, toggles = by_game, entries = d.entries }
end

function M.reload() INDEX, USER, CACHE, BOOST_MEMO = nil, nil, {}, {} end

local function rogue_entries(gid)
    if CACHE[gid] then return CACHE[gid] end
    local list = {}
    for _, c in ipairs(candidates(gid)) do
        local p = file_for(c)
        local text = p and slurp(p)
        if text then
            local d = parse(text)
            for _, e in ipairs(d.entries) do
                e.from_rogue = true
                e.toggle = d.toggles[e.slug]
                classify(e, d.heads[e.slug])
                list[#list + 1] = e
            end
        end
    end
    CACHE[gid] = list
    return list
end

function M.has_file(gid)
    if type(gid) ~= "string" or gid == "" then return false end
    for _, c in ipairs(candidates(gid)) do if file_for(c) then return true end end
    return false
end

-- ── public read API ─────────────────────────────────────────
-- Every entry: slug, name, type, codes, notes, group (perf|fps|cheat),
-- pclass, enabled, from_rogue, from_user.
function M.load_for(game_id)
    if not USER then load_user() end
    local gid = tostring(game_id or "")
    local by_slug, order = {}, {}
    local function put(e, user)
        local cur = by_slug[e.slug]
        if not cur then
            cur = { slug = e.slug, codes = {}, notes = {} }
            by_slug[e.slug] = cur
            order[#order + 1] = cur
        end
        cur.name   = e.name  or cur.name
        cur.type   = e.type  or cur.type
        cur.group  = e.group or cur.group
        cur.pclass = e.pclass or cur.pclass
        if #e.codes > 0 then cur.codes = e.codes end
        if #e.notes > 0 then cur.notes = e.notes end
        if e.has_enabled then cur.enabled = e.enabled end
        if not user and e.toggle ~= nil then cur.toggle = e.toggle end
        if user then cur.from_user = true else cur.from_rogue = true end
    end
    for _, e in ipairs(rogue_entries(gid)) do put(e, false) end
    local mine = {}
    for _, c in ipairs(candidates(gid)) do mine[c] = true end
    for _, e in ipairs(USER.entries) do
        if mine[e.gid] then classify(e, nil); put(e, true) end
    end
    local ut = USER.toggles[gid] or {}
    for _, e in ipairs(order) do
        e.name = e.name or e.slug
        if ut[e.slug] ~= nil then e.enabled = ut[e.slug]
        elseif e.toggle ~= nil then e.enabled = e.toggle
        end
        e.enabled = e.enabled and true or false
        e.group = e.group or "cheat"
    end
    local rank = {}
    for i, c in ipairs(M.PCLASS_ORDER) do rank[c] = i end
    table.sort(order, function(a, b)
        local ra, rb = rank[a.pclass or ""] or 99, rank[b.pclass or ""] or 99
        if ra ~= rb then return ra < rb end
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)
    return order
end

-- Installed games present in the index. opts.boost_only keeps games whose
-- index entry says performance_boost = true.
function M.library(opts)
    opts = opts or {}
    local ok, L = pcall(require, "core.library")
    local out = {}
    if ok and L and L.games then
        for _, g in ipairs(L.games) do
            local id = g.id
            if id and M.in_index(id) and (not opts.boost_only or M.has_boost(id)) then
                out[#out + 1] = { id = id, title = g.title or id, system = (g.system or "GC"):upper() }
            end
        end
    end
    table.sort(out, function(a, b) return (a.title or ""):lower() < (b.title or ""):lower() end)
    return out
end

-- ── user layer writes ───────────────────────────────────────
-- Rewrites the [GAMEID] toggle section of rtcheats_data.ini.
local function set_toggles(text, gid, changes)
    local lines = split_lines(text)
    local s, e
    for i, l in ipairs(lines) do
        local sec = l:match("^%[([^%]]+)%]")
        if sec then
            if s and not e then e = i - 1 end
            if sec == gid then s = i end
        end
    end
    if s and not e then e = #lines end
    local function fmt(slug, on) return ("%s = %s"):format(slug, on and "true" or "false") end
    if not s then
        if #lines > 0 and lines[#lines] ~= "" then lines[#lines + 1] = "" end
        lines[#lines + 1] = "[" .. gid .. "]"
        for _, c in ipairs(changes) do lines[#lines + 1] = fmt(c.slug, c.on) end
    else
        local pending = {}
        for _, c in ipairs(changes) do pending[c.slug] = c end
        for i = s + 1, e do
            local k = lines[i]:match("^%s*([^=#;%s]+)%s*=")
            if k and pending[k] then lines[i] = fmt(k, pending[k].on); pending[k] = nil end
        end
        local at = e
        while at > s and lines[at]:match("^%s*$") do at = at - 1 end
        for _, c in ipairs(changes) do
            if pending[c.slug] then table.insert(lines, at + 1, fmt(c.slug, c.on)); at = at + 1 end
        end
    end
    return table.concat(lines, "\n") .. "\n"
end

function M.set_many(game_id, batch)
    if not batch or #batch == 0 then return true end
    if not USER then load_user() end
    local text = USER.text
    if text == "" then
        text = "[Meta]\nNote = personal cheat toggles, wins over the Rogue DB\n"
    end
    text = set_toggles(text, tostring(game_id), batch)
    mkdir_p((USER.path:match("^(.*)/[^/]+$")) or ".")
    if not write_atomic(USER.path, text) then return false end
    USER = nil                      -- re-read on next access
    return true
end

function M.set_enabled(game_id, slug, on)
    return M.set_many(game_id, { { slug = slug, on = on and true or false } })
end

-- ── applying to Dolphin (GameSettings/<ID>.ini) ─────────────
-- Only blocks whose name starts with M.TAG are ours; anything the user wrote
-- by hand in [Gecko]/[ActionReplay] is left alone.
local SECTIONS = { "Gecko", "Gecko_Enabled", "ActionReplay", "ActionReplay_Enabled" }

local function is_ar(e)
    local t = (e.type or ""):lower()
    return t == "ar" or t:match("action") ~= nil
end

local function strip_managed(lines)
    local out, sec, skipping = {}, nil, false
    for _, l in ipairs(lines) do
        local s = l:match("^%[([^%]]+)%]")
        if s then sec = s; skipping = false; out[#out + 1] = l
        else
            local managed_sec = false
            for _, n in ipairs(SECTIONS) do if sec == n then managed_sec = true end end
            if managed_sec and l:sub(1, 1) == "$" then
                skipping = l:sub(2, 1 + #M.TAG) == M.TAG
                if not skipping then out[#out + 1] = l end
            elseif skipping and managed_sec then
                -- code line of a managed block: dropped
            else
                out[#out + 1] = l
            end
        end
    end
    return out
end

local function add_to_section(lines, section, block)
    local at
    for i, l in ipairs(lines) do
        if l == "[" .. section .. "]" then
            at = i
            for j = i + 1, #lines do
                if lines[j]:match("^%[") then break end
                at = j
            end
            break
        end
    end
    if not at then
        if #lines > 0 and lines[#lines] ~= "" then lines[#lines + 1] = "" end
        lines[#lines + 1] = "[" .. section .. "]"
        at = #lines
    end
    for k, b in ipairs(block) do table.insert(lines, at + k, b) end
end

function M.apply(game_id, dest_dir)
    local gid = tostring(game_id or "")
    if gid == "" then return nil, "no game id" end
    local entries = M.load_for(gid)
    dest_dir = dest_dir
    if not dest_dir then
        local ok, P = pcall(require, "core.paths")
        dest_dir = (ok and P and P.emu and P.emu("GameSettings"))
                   or "/opt/muos/share/emulator/dolphin/GameSettings"
    end
    mkdir_p(dest_dir)
    local path = dest_dir .. "/" .. gid .. ".ini"
    local lines = strip_managed(split_lines(slurp(path) or ""))
    local gecko, gecko_en, ar, ar_en = {}, {}, {}, {}
    local n = 0
    for _, e in ipairs(entries) do
        if e.enabled and #e.codes > 0 then
            local name = "$" .. M.TAG .. (e.name or e.slug)
            local code, en = gecko, gecko_en
            if is_ar(e) then code, en = ar, ar_en end
            code[#code + 1] = name
            for _, c in ipairs(e.codes) do code[#code + 1] = c end
            en[#en + 1] = name
            n = n + 1
        end
    end
    if #gecko > 0 then add_to_section(lines, "Gecko", gecko); add_to_section(lines, "Gecko_Enabled", gecko_en) end
    if #ar > 0 then add_to_section(lines, "ActionReplay", ar); add_to_section(lines, "ActionReplay_Enabled", ar_en) end
    if #lines == 0 then return true, 0 end
    local ok = write_atomic(path, table.concat(lines, "\n") .. "\n")
    if not ok then return nil, "cannot write " .. path end
    return true, n
end

return M
