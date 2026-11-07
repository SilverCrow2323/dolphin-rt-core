-- frontend/state.lua
-- Shared application state: paths, launch options, data indexes, scanners.
--
-- Required by nearly every module as `State`. It owns everything that has
-- to outlive a single screen:
--   roms / homebrew            device content, filled by the scanners
--   games_data / enhancer_hub  JSON indexes loaded from data/
--   opts                       launch options shown in the chips row
--   theme / screen / history   assigned by main.lua right after require
--
-- Navigation (State.go / State.back), theme flip, restart_app and the
-- rescan polling live in main.lua; this module only holds the fields
-- those functions read and write.
--
-- Path model (see mux_launch.sh): the process CWD is <root>/frontend, so
-- every relative path in the code resolves inside frontend/.
--   S.root()           -> <root>             (contains frontend/, lib/)
--   S.frontend_path(p) -> <root>/frontend/p
--   S.path(p)          -> <root>/p

local json = require("json")

local S = {}

-- ============================================================
--  PATHS
-- ============================================================

local _root = nil

local function popen_line(cmd)
  local h = io.popen(cmd)
  if not h then return nil end
  local out = h:read("*l")
  h:close()
  if out and out ~= "" then return out end
  return nil
end

local function detect_root()
  local dir = nil

  if love and love.filesystem then
    local ok, src = pcall(love.filesystem.getSource)
    if ok and type(src) == "string" and src:sub(1, 1) == "/" then
      dir = src
    end
    if not dir then
      local ok2, cwd = pcall(love.filesystem.getWorkingDirectory)
      if ok2 and type(cwd) == "string" and cwd:sub(1, 1) == "/" then
        dir = cwd
      end
    end
  end

  if not dir then
    dir = popen_line("pwd 2>/dev/null") or "."
  end

  dir = dir:gsub("/+$", "")
  -- CWD is the LÖVE game dir (frontend/) → the app root is its parent
  return dir:match("^(.*)/frontend$") or dir
end

function S.root()
  if not _root then _root = detect_root() end
  return _root
end

function S.path(rel)
  if not rel or rel == "" then return S.root() end
  return S.root() .. "/" .. rel
end

function S.frontend_path(rel)
  if not rel or rel == "" then return S.root() .. "/frontend" end
  return S.root() .. "/frontend/" .. rel
end

-- ============================================================
--  SHARED FIELDS
-- ============================================================

-- Navigation (main.lua assigns screen/history/theme at boot)
S.screen       = "boot"
S.history      = {}
S.theme_name   = "gc"
S.theme        = nil
S.t_ui         = 0

-- Input routing flags read by main.lua
S.raw_input    = false
S.capture_mode = false

-- Device content
S.roms         = {}
S.scan_done    = false
S.homebrew     = {}

-- JSON indexes
S.games_data       = {}
S.games_data_count = 0
S.enhancer_hub     = {}

-- Misc
S.features         = {}   -- filled by features.detect() in love.load
S.active_profiles  = {}   -- profile_manager.set_active()
S.update_available = nil

-- Library grid: 5 columns x 2 rows per page (screens/library.lua)
S.PAGE_LIB       = 10
S.page_lib       = 1
S.focus_lib      = { x = 0, y = 0 }
S.settings_index = 1

-- Launch options (chips row). Session-only: not persisted in
-- frontendone.json by design.
S.opts = {
  core       = "local",     -- "local" | "external"
  hotkeys    = false,
  livemenu   = false,
  logging    = false,
  controller = "Default",
  profile    = "Default",
}

-- ============================================================
--  FILE HELPERS
-- ============================================================

-- Reads the first candidate that exists. love.filesystem first (works
-- for paths inside the game dir), io.open as fallback (absolute paths).
local function read_text(candidates)
  if love and love.filesystem and love.filesystem.read then
    for _, p in ipairs(candidates) do
      local ok, content = pcall(love.filesystem.read, p)
      if ok and type(content) == "string" and #content > 0 then
        return content, p
      end
    end
  end
  for _, p in ipairs(candidates) do
    local f = io.open(p, "r")
    if f then
      local c = f:read("*a"); f:close()
      if c and #c > 0 then return c, p end
    end
  end
  return nil, nil
end

local function data_candidates(name)
  return {
    "data/" .. name,
    S.frontend_path("data/" .. name),
    S.path("frontend/data/" .. name),
  }
end

local function load_json(name)
  local content = read_text(data_candidates(name))
  if not content then return nil end
  local ok, decoded = pcall(json.decode, content)
  if not ok or type(decoded) ~= "table" then return nil end
  return decoded
end

-- ============================================================
--  GAMES DATA  (data/games_data.json)
-- ============================================================
-- Flattened index: games_data[GAME_ID] = record. The record keeps the
-- full `entries` list plus the fields of the best report (highest
-- rating), which is the shape report_store._merge_into_state() expects.

local _title_index = {}   -- normalised title -> record
local _alt_index   = {}   -- region-insensitive id -> record

local function norm_title(s)
  if not s then return "" end
  s = tostring(s):lower()
  s = s:gsub("%b()", " "):gsub("%b[]", " ")      -- drop (USA), [GZ3P01], …
  s = s:gsub("[^%w]", "")
  return s
end

-- GZ3P01 -> GZ3 + 01 (drops the region char, position 4)
local function alt_key(id)
  if type(id) ~= "string" or #id < 6 then return nil end
  return id:sub(1, 3) .. id:sub(5, 6)
end

-- Pick the entry with the highest rating; on ties, the one with
-- the highest fps_max; on further ties, the last iterated.
local function best_entry(entries)
  local best, best_r, best_fps = nil, -1, -1
  for _, e in ipairs(entries or {}) do
    local tr = e.test_review or {}
    local r = tonumber(tr.rating) or 0
    local f = tonumber(tr.fps_max) or 0
    if r > best_r or (r == best_r and f > best_fps) then
      best_r = r
      best_fps = f
      best = e
    end
  end
  return best or {}
end

local function build_record(gi, entries)
  local best = best_entry(entries)
  local tr = best.test_review      or {}
  local td = best.test_details     or {}
  local te = best.test_environment or {}
  return {
    game_id        = gi.game_id or "",
    game           = gi.game    or "",
    system         = gi.system  or "",
    region         = gi.region  or "",
    info           = gi,
    rating         = tonumber(tr.rating)  or 0,
    fps_min        = tonumber(tr.fps_min) or 0,
    fps_max        = tonumber(tr.fps_max) or 0,
    fps_str        = tr.fps      or "",
    boot           = tr.boot     or "?",
    playable       = tr.playable or "?",
    considerations = td.considerations or "",
    core_profile   = td.core_profile   or "",
    rtcore_version = td.rtcore_version or "",
    tester         = te.tester       or "",
    device         = te.device       or "",
    muos_version   = te.muos_version or "",
    entries        = entries or {},
    report_count   = #(entries or {}),
  }
end

function S.load_games_data()
  S.games_data       = {}
  S.games_data_count = 0
  _title_index = {}
  _alt_index   = {}

  local decoded = load_json("games_data.json")
  if not decoded then
    print("[state] games_data.json not found or invalid")
    return 0
  end

  local games = decoded.games or decoded.items or {}
  for _, g in ipairs(games) do
    local gi = g.game_info or {}
    local id = gi.game_id
    if type(id) == "string" and id ~= "" then
      local rec = build_record(gi, g.entries or {})
      S.games_data[id]   = rec
      S.games_data_count = S.games_data_count + 1

      local tkey = norm_title(rec.game)
      if tkey ~= "" and not _title_index[tkey] then _title_index[tkey] = rec end

      local akey = alt_key(id)
      if akey and not _alt_index[akey] then _alt_index[akey] = rec end
    end
  end

  print(string.format("[state] games_data: %d titles", S.games_data_count))
  return S.games_data_count
end

function S.games_data_stats()
  local st = { total = 0, gc = 0, wii = 0, reports = 0, playable = 0, tested = 0 }
  for _, g in pairs(S.games_data) do
    st.total   = st.total + 1
    st.reports = st.reports + (g.report_count or 0)
    if g.system == "GC"  then st.gc  = st.gc  + 1 end
    if g.system == "Wii" then st.wii = st.wii + 1 end
    if (g.rating or 0) > 0 then st.tested = st.tested + 1 end
    if g.playable == "YES" then st.playable = st.playable + 1 end
  end
  return st
end

-- Resolve a ROM entry (State.roms item) to its compatibility record.
-- Order: explicit id → id embedded in the filename → title → same game,
-- different region.
function S.find_compat(game)
  if not game or game.virtual then return nil end

  local id = game.id
  if not id and game.file then
    id = game.file:match("%(([A-Z][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])%)")
      or game.file:match("%[([A-Z][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])%]")
  end

  if id then
    local rec = S.games_data[id]
    if rec then return rec end
  end

  local tkey = norm_title(game.title or game.file)
  if tkey ~= "" and _title_index[tkey] then return _title_index[tkey] end

  if id then
    local akey = alt_key(id)
    if akey then return _alt_index[akey] end
  end

  return nil
end

-- ============================================================
--  ENHANCER HUB  (data/rtenhancerhub.json)
-- ============================================================

function S.load_enhancer_hub()
  S.enhancer_hub = {}
  local decoded = load_json("rtenhancerhub.json")
  if decoded and type(decoded.items) == "table" then
    S.enhancer_hub = decoded.items
  end
  print(string.format("[state] enhancer hub: %d items", #S.enhancer_hub))
  return #S.enhancer_hub
end

-- ============================================================
--  ROM SCAN
-- ============================================================
-- The real work is done by async_scanner.lua, driven by main.lua:
-- poll_rom_rescan() picks up _rescan_pending on the next frame and
-- restarts the background scan, then finalize_scan() refills S.roms.
-- Never scan synchronously here: on SD storage a blocking find freezes
-- the UI for seconds.

function S.rescan_roms_async(delay)
  S._rescan_delay   = delay or 0.6
  S._rescan_pending = true
  return true
end

-- Kept for screens/settings_app.lua ("Rescan ROMs & Homebrew").
function S.scan_roms()
  return S.rescan_roms_async(0.1)
end

-- ── Deduplication ──────────────────────────────────────────
-- Remove entries that share the same absolute path. Falls back to
-- sys+file when path is missing. This is the single source of truth
-- for de-duplication across the app: main.lua's finalize_scan() calls
-- this before handing the list to the UI, so overlapping scan paths
-- and keyword-fallback directories can never produce duplicates.
function S.dedupe_roms(roms)
  local seen, out = {}, {}
  for _, r in ipairs(roms or {}) do
    local key = r.path
      or ((r.sys or "?") .. "|" .. tostring(r.file or r.title or "?"))
    if not seen[key] then
      seen[key] = true
      out[#out + 1] = r
    end
  end
  return out
end

-- ============================================================
--  HOMEBREW SCANNER
-- ============================================================
-- Reads both rtcore_hb.ini (native format) and meta.xml (HBC standard).
-- meta.xml entries are converted to the same internal shape as INI ones.
-- If both exist, INI wins for fields it provides; meta.xml fills the rest.

local function xml_unescape(s)
  if not s then return s end
  s = s:gsub("&lt;",   "<")
  s = s:gsub("&gt;",   ">")
  s = s:gsub("&quot;", "\"")
  s = s:gsub("&apos;", "'")
  s = s:gsub("&amp;",  "&")
  return s
end

local function parse_meta_xml(content)
  if not content then return nil end
  local function pick(tag)
    local v = content:match("<" .. tag .. ">([^<]*)</" .. tag .. ">")
    if v then return xml_unescape(v:match("^%s*(.-)%s*$")) end
    return nil
  end
  local name = pick("name")
  if not name then return nil end
  return {
    name        = name,
    description = pick("short_description") or pick("long_description") or "",
    author      = pick("coder") or "",
    version     = pick("version") or "",
    type        = "dol",
    dol         = "boot.dol",
    icon        = "icon.png",
    banner      = "icon.png",
    _from_xml   = true,
  }
end

function S.scan_homebrew()
  S.homebrew = {}
  local hb_dir = "hb"
  local p = io.popen('timeout 2 ls -1 "' .. hb_dir .. '" 2>/dev/null')
  if not p then return S.homebrew end
  local ini = require("ini_parser")

  for dir in p:lines() do
    if dir ~= "" and dir:sub(1,1) ~= "." then
      local base = hb_dir .. "/" .. dir
      local entry = nil

      -- 1. Try rtcore_hb.ini (native)
      local ini_path = base .. "/rtcore_hb.ini"
      local data = ini.parse(ini_path)
      local e = data.Info or data.homebrew
      if not e then
        for k, v in pairs(data) do
          if k:match("^entry%.") then e = v; break end
        end
      end
      if e and e.name then
        entry = {
          name         = e.name,
          description  = e.description or "",
          author       = e.author or "",
          version      = e.version or "",
          type         = e.type or "dol",
          icon         = e.icon or "icon.png",
          banner       = e.banner,
          instructions = e.instructions or "",
          dol          = e.dol or e.boot or e.boot_dol or "boot.dol",
        }
      end

      -- 2. Fallback / merge from meta.xml (HBC standard)
      if not entry then
        local mf = io.open(base .. "/meta.xml", "r")
        if not mf then
          mf = io.open(base .. "/META.XML", "r")
        end
        if mf then
          local mc = mf:read("*a"); mf:close()
          entry = parse_meta_xml(mc)
        end
      end

      -- 3. If we have a valid entry, resolve icons and push
      if entry and entry.name then
        local icon_file   = entry.icon or "icon.png"
        local banner_file = entry.banner or icon_file
        local icon_full   = base .. "/" .. icon_file
        local banner_full = base .. "/" .. banner_file

        local function exists(p)
          local f = io.open(p, "rb")
          if f then f:close(); return true end
          return false
        end
        if not exists(icon_full) then
          if exists(base .. "/icon.png") then
            icon_full = base .. "/icon.png"
          end
        end
        if not exists(banner_full) then
          banner_full = icon_full
        end

        table.insert(S.homebrew, {
          dir          = dir,
          name         = entry.name,
          description  = entry.description or "",
          author       = entry.author or "",
          version      = entry.version or "",
          type         = entry.type or "dol",
          icon         = icon_full,
          banner       = banner_full,
          instructions = entry.instructions or "",
          boot         = base .. "/" .. (entry.dol or "boot.dol"),
        })
      end
    end
  end
  p:close()
  table.sort(S.homebrew, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
  return S.homebrew
end

return S