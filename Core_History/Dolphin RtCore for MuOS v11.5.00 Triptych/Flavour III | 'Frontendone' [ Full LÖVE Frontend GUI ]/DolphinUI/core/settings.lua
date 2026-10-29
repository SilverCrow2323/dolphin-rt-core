-- User settings, persisted as JSON in data/settings.json.
-- The only place that touches user preferences.
local JSON = require("core.json")
local FS   = require("core.fs")

local M = {}

local PATH = "data/settings.json"

local defaults = {
  rom_paths         = {},
  theme             = "gc",
  scan_depth        = 4,
  show_fps          = false,
  last_scan         = 0,
  -- v1.0.1 additions
  boot_animation    = true,
  fast_boot         = false,
  debug_input       = false,
  auto_update_check = true,
  confirm_quit      = true,
  quick_launch      = false,
  default_return_to = "library",
  -- log
  log_level          = "info",
  log_retention_days = 7,
  log_max_kb         = 512,
  log_auto_clear     = true,
}

M.data = nil

local function copy(t)
  local c = {}
  for k, v in pairs(t) do
    if type(v) == "table" then c[k] = copy(v) else c[k] = v end
  end
  return c
end

function M.init()
  M.data = copy(defaults)
  local raw = FS.read(PATH)
  if raw then
    local ok, decoded = pcall(JSON.decode, raw)
    if ok and type(decoded) == "table" then
      for k, v in pairs(decoded) do M.data[k] = v end
    end
  end
end

function M.save()
  FS.mkdir_p("data")
  FS.atomic_write(PATH, JSON.encode(M.data))
end

function M.get(k)      return M.data[k] end
function M.set(k, v)   M.data[k] = v; M.save() end

function M.add_rom_path(path, system)
  system = system or "GC"
  for _, e in ipairs(M.data.rom_paths) do
    if e.path == path and e.system == system then return false end
  end
  table.insert(M.data.rom_paths, { path = path, system = system })
  M.save()
  return true
end

function M.remove_rom_path(idx)
  table.remove(M.data.rom_paths, idx)
  M.save()
end

return M
