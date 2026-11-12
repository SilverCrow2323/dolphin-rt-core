-- ROM scanner. Finds GameCube / Wii images in user-configured paths.
-- Reads GameID from file headers (ISO/GCM/RVZ/WBFS/WIA/GCZ).
-- Uses core.shell + core.fs only — no love.*.
local Shell   = require("core.shell")
local FS      = require("core.fs")
local Settings = require("core.settings")
local SysDetect = require("core.system_detect")

local M = {}

M.games       = {}       -- { id, path, file, title, system, region, size }
M.scanned_at  = 0
M.last_count  = 0

local EXTS = { "iso", "gcm", "rvz", "gcz", "ciso", "wbfs", "wia" }

local VALID_ID = "^[A-Z][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$"

local function valid_id(s)
  if not s or #s ~= 6 then return false end
  if s == "RVZ" or s == "WBFS" or s == "WIA" or s == "ISO"
     or s == "GCM" or s == "GCZ" then return false end
  return s:match(VALID_ID) ~= nil
end

-- ── lettura header nativa (niente dd/popen per file) ───────────────
-- Prima: 1-3 processi (dd, tr, grep, stat) PER ROM => scan lentissimo e UI
-- congelata. Ora: un solo io.open per file, GameID letto all'offset giusto
-- per formato (riconosciuto dal magic, non dall'estensione).
--   ISO/GCM 0x0 · RVZ/WIA 0x58 (disc header dentro header2) · WBFS 0x200
--   CISO 0x8000 · GCZ compresso (niente ID) -> tag [ID] nel nome file
local function read6(f, off)
  if not f:seek("set", off) then return nil end
  local s = f:read(6)
  if s and #s == 6 and valid_id(s) then return s end
  return nil
end

local function id_from_filename(name)
  if type(name) ~= "string" then return nil end
  for tag in name:gmatch("[%[%(%{]([A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])[%]%)%}]") do
    if valid_id(tag) then return tag end
  end
  return nil
end

local function extract_gameid(path)
  local f = io.open(path, "rb")
  if not f then return id_from_filename(path) end
  local magic = f:read(4) or ""
  local id
  if     magic == "WBFS"               then id = read6(f, 0x200)
  elseif magic == "RVZ\1" or magic == "WIA\1"
         or magic:sub(1, 3) == "RVZ" or magic:sub(1, 3) == "WIA"
                                       then id = read6(f, 0x58)
  elseif magic == "CISO"               then id = read6(f, 0x8000)
  elseif magic == "\176\11\192\1"      then id = nil        -- GCZ: compresso
  else                                      id = read6(f, 0)  -- ISO / GCM
  end
  if not id then
    -- ultimo tentativo: cerca un ID plausibile nei primi 1 KB (header strani)
    f:seek("set", 0)
    local head = f:read(1024) or ""
    for cand in head:gmatch("%u[%u%d][%u%d][%u%d][%u%d][%u%d]") do
      if valid_id(cand) and cand:match("^[GDPRSWH]") then id = cand; break end
    end
  end
  f:close()
  return id or id_from_filename(path)
end

-- Read size without spawning stat/wc for every ROM. The target is ARM64:
-- LuaJIT's seek("end") uses the platform off_t and handles Wii images > 2 GiB.
local function file_size(path)
  local f = io.open(path, "rb")
  if not f then return 0 end
  local ok, size = pcall(f.seek, f, "end")
  f:close()
  if ok and type(size) == "number" and size > 0 then return size end
  return 0
end

local REGION_TAGS = {
  "pal", "ntsc", "ntsc%-u", "ntsc%-j", "ntsc%-k", "ntsc%-tw",
  "usa", "europe", "japan", "korea", "taiwan", "australia",
  "germany", "france", "italy", "spain", "netherlands",
  "en", "fr", "de", "es", "it", "ja", "ko", "zh", "ru", "nl",
  "beta", "proto", "prototype", "demo", "sample",
}
local function clean_parenthesis(s)
  return (s:gsub("%s*%b()", function(m)
    local inner = m:sub(2, -2)
    local low = inner:lower():gsub("%s+$", "")
    for _, tag in ipairs(REGION_TAGS) do
      if low == tag then return "" end
    end
    if low:match("^v%d+%.%d+") or low:match("^rev%s*%w+") then return "" end
    return m
  end))
end
local function base_title(filename)
  local t = filename:gsub("%.[^%.]+$", "")
  t = clean_parenthesis(t)
  t = t:gsub("_", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return t
end

local function region_from_id(id)
  if not id or #id ~= 6 then return "?" end
  local r = id:sub(4, 4)
  local map = { E = "NTSC-U", P = "PAL", J = "NTSC-J", K = "NTSC-K",
                W = "NTSC-TW", D = "PAL-DE", F = "PAL-FR",
                I = "PAL-IT", S = "PAL-ES", X = "PAL-NL" }
  return map[r] or "?"
end

local function system_from_id(id)
  -- Delegated to core.system_detect (single source of truth).
  return SysDetect.from_id(id)
end

local function find_command(root, depth)
  local clauses = {}
  for _, ext in ipairs(EXTS) do clauses[#clauses + 1] = "-iname '*." .. ext .. "'" end
  local pattern = table.concat(clauses, " -o ")
  return string.format(
    "find %s -maxdepth %d -type f \\( %s \\) -print 2>/dev/null",
    Shell.shq(root), depth or 8, pattern)
end

-- Enumeration and ROM inspection are both incremental. The old scanner read
-- the complete find output in scan_begin(), blocking the UI before frame one.
M.scanning = false
M.progress = { done = 0, total = 0 }
local _roots, _root_index, _scan_pipe, _scan_list_path, _scan_done_path, _seen, _depth

local function add_game(path, entry)
  local id   = extract_gameid(path)
  local file = path:match("([^/]+)$") or path
  local sys  = id and system_from_id(id) or SysDetect.from_rom({ path = path, file = file })
  table.insert(M.games, {
    id      = id,
    path    = path,
    file    = file,
    title   = base_title(file),
    system  = sys or entry.system,
    region  = region_from_id(id),
    size    = file_size(path),
  })
end

local function path_key(path)
  return tostring(path or ""):gsub("/+", "/"):gsub("/+$", ""):lower()
end

local function wall_time()
  if type(love) == "table" and love.timer and love.timer.getTime then
    return love.timer.getTime()
  end
  return os.clock()
end

local function close_scan_pipe()
  if _scan_pipe then pcall(_scan_pipe.close, _scan_pipe); _scan_pipe = nil end
  if _scan_list_path then os.remove(_scan_list_path); _scan_list_path = nil end
  if _scan_done_path then os.remove(_scan_done_path); _scan_done_path = nil end
end

function M.scan_begin()
  close_scan_pipe()
  M.games = {}
  _roots, _root_index, _seen, _depth = {}, 1, {}, nil
  _depth = math.max(8, tonumber(Settings.get("scan_depth")) or 8)
  local roots_seen = {}
  local function root_key(path)
    local clean = tostring(path or ""):gsub("/+$", "")
    -- Resolve only user-selected roots, never individual ROMs.
    local real = Shell.first("readlink -f " .. Shell.shq(clean), 3)
    if type(real) == "string" and real ~= "" then clean = real end
    return path_key(clean)
  end
  for _, entry in ipairs(Settings.get("rom_paths") or {}) do
    if type(entry) == "table" and entry.path and FS.is_dir(entry.path) then
      local key = root_key(entry.path)
      local existing = roots_seen[key]
      if not existing then
        local root = { path = entry.path, system = entry.system or "GC" }
        _roots[#_roots + 1] = root
        roots_seen[key] = root
      elseif existing.system ~= entry.system then
        existing.system = "Both"
      end
    end
  end
  M.scanning = #_roots > 0
  M.progress = { done = 0, total = 0 }
  if not M.scanning then M.scan_finish() end
end

local function open_next_root()
  while _root_index <= #_roots do
    local entry = _roots[_root_index]
    local suffix = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
    _scan_list_path = "/tmp/rt_romscan_" .. suffix .. ".list"
    _scan_done_path = _scan_list_path .. ".done"
    os.remove(_scan_list_path)
    os.remove(_scan_done_path)
    -- Create the regular file before starting the detached writer, removing
    -- the race where opening the read side happened before find created it.
    local seed = io.open(_scan_list_path, "w")
    if not seed then
      _scan_list_path, _scan_done_path = nil, nil
      _root_index = _root_index + 1
    else
    seed:close()
    local script = "find " .. Shell.shq(entry.path) .. " -maxdepth " ..
      tostring(_depth) .. " -type f \\( "
    local clauses = {}
    for _, ext in ipairs(EXTS) do clauses[#clauses + 1] = "-iname '*." .. ext .. "'" end
    script = script .. table.concat(clauses, " -o ") .. " \\) -print > " ..
      Shell.shq(_scan_list_path) .. "; : > " .. Shell.shq(_scan_done_path)
    local spawn = "setsid sh -c " .. Shell.shq(script) ..
      " </dev/null >/dev/null 2>&1 &"
    local rc = os.execute(spawn)
    if rc == true or rc == 0 then
      _scan_pipe = io.open(_scan_list_path, "r")
      if _scan_pipe then return true end
    end
    os.remove(_scan_list_path); os.remove(_scan_done_path)
    _scan_list_path, _scan_done_path, _scan_pipe = nil, nil, nil
    _root_index = _root_index + 1
    end
  end
  return false
end

function M.scan_finish()
  close_scan_pipe()
  table.sort(M.games, function(a, b)
    local ta, tb = (a.title or ""):lower(), (b.title or ""):lower()
    if ta == tb then return (a.path or "") < (b.path or "") end
    return ta < tb
  end)
  M.scanned_at = os.time()
  M.last_count = #M.games
  M.scanning = false
  M.progress.done = M.progress.total
  _roots, _seen = nil, nil
end

-- Process file discovery and header reads for a small real-time budget. The
-- wall clock includes time spent waiting for child processes; os.clock does not.
function M.scan_step(budget)
  if not M.scanning then return true end
  local t0, limit = wall_time(), budget or 0.008
  local did_work = false
  while M.scanning do
    if did_work and (wall_time() - t0) >= limit then break end
    if not _scan_pipe and not open_next_root() then
      M.scan_finish()
      break
    end

    local path = _scan_pipe:read("*l")
    if not path then
      -- This is a regular file, so EOF is non-blocking. find() may still be
      -- writing more rows; only advance when its completion marker appears.
      local marker = _scan_done_path and io.open(_scan_done_path, "r")
      if marker then
        marker:close()
        close_scan_pipe()
        _root_index = _root_index + 1
      else
        break
      end
    elseif path ~= "" then
      did_work = true
      local key = path_key(path)
      if not _seen[key] then
        _seen[key] = true
        M.progress.total = M.progress.total + 1
        local ok = pcall(add_game, path, _roots[_root_index])
        if ok then M.progress.done = M.progress.done + 1 end
      end
    end
  end
  return not M.scanning
end

-- Public: full scan. Blocking (usa scan_begin/scan_step per la versione fluida).
function M.scan()
  M.scan_begin()
  while M.scanning do M.scan_step(1) end
  return M.games
end

function M.count() return #M.games end

M._file_size = file_size           -- esposto per i test
M._find_command = find_command
M._extract_gameid = extract_gameid

return M
