-- frontend/minoru/workspace.lua
-- The "files he works on". Dossier-informed: TENRET, Minovice,
-- CrossWilson, EliTube buffer, Node5 self-diagnostics, etc.
-- Persisted at frontend/minoru/data/workspace.json so progress
-- survives restarts — the tasks advance slowly and never "finish"
-- in a jarring way.

local json = require("json")

local M = {}

local DIR         = "minoru/data"
local PATH        = DIR .. "/workspace.json"
local MAX_FILES   = 6
local TICK_EVERY  = 1.8
local ADVANCE_AMT = 0.020
local FLUSH_SECS  = 8.0

-- Canonical virtual filesystem.
local CATALOGUE = {
  { name = "tenret.sock",        project = "TENRET",       bytes = 512    },
  { name = "minovice.hab",       project = "MINOVICE",     bytes = 4096   },
  { name = "crosswilson.pkg",    project = "CROSSWILSON",  bytes = 131072 },
  { name = "elitube.buf",        project = "ELITUBE",      bytes = 8192   },
  { name = "node5.sys",          project = "NODE5",        bytes = 1024   },
  { name = "rintrompo.log",      project = "RINTROMPO",    bytes = 65536  },
  { name = "pips_notes.txt",     project = "ARCHIVE",      bytes = 2048   },
  { name = "suitai_wrist.fw",    project = "SUITAI",       bytes = 32768  },
  { name = "king_pajo.bak",      project = "ARCHIVE",      bytes = 524288 },
  { name = "ir_sara.cfg",        project = "IR_SARA",      bytes = 512    },
}

local _dirty      = false
local _last_flush = 0

local function save_now()
  os.execute("mkdir -p " .. DIR)
  local payload = json.encode({
    files     = M.files,
    focused_i = M.focused_i,
  })
  local tmp = PATH .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return end
  f:write(payload)
  f:close()
  if not os.rename(tmp, PATH) then
    os.execute("cp " .. "'" .. tmp .. "' '" .. PATH .. "'")
    os.remove(tmp)
  end
  _dirty = false
  _last_flush = os.time()
end

local function load()
  M.files = {}
  M.focused_i = 1
  local f = io.open(PATH, "r")
  if not f then return false end
  local c = f:read("*a"); f:close()
  local ok, data = pcall(json.decode, c)
  if not ok or type(data) ~= "table" or type(data.files) ~= "table" then
    return false
  end
  for _, fl in ipairs(data.files) do
    if type(fl) == "table" and fl.name then
      table.insert(M.files, {
        name     = tostring(fl.name),
        project  = tostring(fl.project or "?"),
        bytes    = tonumber(fl.bytes) or 0,
        progress = tonumber(fl.progress) or 0.1,
      })
    end
  end
  M.focused_i = tonumber(data.focused_i) or 1
  return #M.files > 0
end

function M.init()
  M._t = 0
  if load() then return end

  -- Fresh start: pick MAX_FILES unique entries from the catalogue.
  local pool = {}
  for i, t in ipairs(CATALOGUE) do pool[i] = t end
  for _ = 1, MAX_FILES do
    if #pool == 0 then break end
    local i = math.random(1, #pool)
    local src = pool[i]
    table.remove(pool, i)
    table.insert(M.files, {
      name     = src.name,
      project  = src.project,
      bytes    = src.bytes,
      progress = math.random(15, 85) / 100,
    })
  end
  M.focused_i = 1
  _dirty = true
end

function M.update(dt)
  if not M.files or #M.files == 0 then return end
  M._t = (M._t or 0) + dt
  if M._t < TICK_EVERY then
    -- Still allow debounced flush.
    if _dirty and os.time() - _last_flush > FLUSH_SECS then save_now() end
    return
  end
  M._t = 0

  local f = M.files[M.focused_i]
  if f then
    f.progress = math.min(1, f.progress + ADVANCE_AMT *
      (0.6 + math.random() * 0.8))
    _dirty = true
    if f.progress >= 1 then
      -- Silent rotation: never actually "ends".
      f.progress  = 0.05
      M.focused_i = (M.focused_i % #M.files) + 1
    end
  end

  if _dirty and os.time() - _last_flush > FLUSH_SECS then save_now() end
end

function M.focused()
  return M.files and M.files[M.focused_i] or nil
end

function M.all()
  return M.files or {}
end

function M.flush()
  if _dirty then save_now() end
end

return M