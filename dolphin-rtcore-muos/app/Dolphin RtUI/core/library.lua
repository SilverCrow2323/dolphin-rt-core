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

local EXTS = {
  gc  = { "iso", "gcm", "rvz", "gcz", "ciso" },
  wii = { "iso", "rvz", "wbfs", "wia", "gcz" },
}

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

-- Peso file in byte, con 3 strategie (la prima basta quasi sempre):
--   1) seek("end") — zero processi. Con LuaJIT a 32 bit su file > 2 GB
--      (Wii) puo' dare 0/negativo/clamp: in quel caso si passa alla 2)
--   2) stat -c %s   (coreutils / busybox)
--   3) wc -c        (ultima spiaggia)
-- Ritorna 0 SOLO se il file e' davvero illeggibile (la UI mostra "—").
local TWO_GB = 2147483647
local function file_size(path)
  local wrapped
  local f = io.open(path, "rb")
  if f then
    local ok, sz = pcall(f.seek, f, "end")
    f:close()
    if ok and type(sz) == "number" then
      if sz < 0 then wrapped = sz + 4294967296        -- overflow int32
      elseif sz > 0 and sz < TWO_GB then return sz
      elseif sz >= TWO_GB then wrapped = sz end        -- da confermare
    end
  end
  local n = tonumber(Shell.first("stat -c %s " .. Shell.shq(path), 4) or "")
  if n and n > 0 then return n end
  n = tonumber((Shell.first("wc -c < " .. Shell.shq(path), 10) or ""):match("%d+") or "")
  if n and n > 0 then return n end
  return wrapped or 0
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

local function find_files(root, system, depth)
  local exts = EXTS[system:lower()] or EXTS.gc
  local clauses = {}
  for _, e in ipairs(exts) do
    clauses[#clauses+1] = "-iname '*." .. e .. "'"
  end
  local pattern = table.concat(clauses, " -o ")
  local cmd = string.format(
    "find %s -maxdepth %d -type f \\( %s \\) 2>/dev/null",
    Shell.shq(root), depth or 4, pattern)
  local out = Shell.popen(cmd, 8)
  if not out then return {} end
  local files = {}
  for line in out:gmatch("[^\n]+") do
    if line ~= "" then files[#files+1] = line end
  end
  return files
end

-- ── scan ───────────────────────────────────────────────────────────
-- Due modi, stesso risultato:
--   M.scan()                        bloccante (compat col codice vecchio)
--   M.scan_begin() + M.scan_step()  incrementale: la UI resta fluida e puo'
--                                   mostrare una barra (M.progress = {done,total})
M.scanning = false
M.progress = { done = 0, total = 0 }
local _queue, _qi, _seen

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

function M.scan_begin()
  M.games = {}
  _queue, _qi, _seen = {}, 1, {}
  local paths = Settings.get("rom_paths") or {}
  local depth = Settings.get("scan_depth") or 4
  for _, entry in ipairs(paths) do
    if entry.path and FS.is_dir(entry.path) then
      for _, path in ipairs(find_files(entry.path, entry.system, depth)) do
        if not _seen[path] then
          _seen[path] = true
          _queue[#_queue + 1] = { path = path, entry = entry }
        end
      end
    end
  end
  M.scanning = true
  M.progress = { done = 0, total = #_queue }
  if #_queue == 0 then M.scan_finish() end
end

function M.scan_finish()
  table.sort(M.games, function(a, b)
    local ta, tb = (a.title or ""):lower(), (b.title or ""):lower()
    if ta == tb then return (a.path or "") < (b.path or "") end
    return ta < tb
  end)
  M.scanned_at = os.time()
  M.last_count = #M.games
  M.scanning = false
  _queue = nil
end

-- Elabora ROM per al massimo `budget` secondi (default 8 ms = 1/2 frame a 60).
-- Ritorna true quando ha finito.
function M.scan_step(budget)
  if not M.scanning then return true end
  local t0, limit = os.clock(), budget or 0.008
  while _qi <= #_queue do
    local job = _queue[_qi]; _qi = _qi + 1
    local ok = pcall(add_game, job.path, job.entry)
    M.progress.done = _qi - 1
    if os.clock() - t0 >= limit then break end
  end
  if _qi > #_queue then M.scan_finish(); return true end
  return false
end

-- Public: full scan. Blocking (usa scan_begin/scan_step per la versione fluida).
function M.scan()
  M.scan_begin()
  while M.scanning do M.scan_step(1) end
  return M.games
end

function M.count() return #M.games end

M._file_size = file_size           -- esposto per i test
M._extract_gameid = extract_gameid

return M
