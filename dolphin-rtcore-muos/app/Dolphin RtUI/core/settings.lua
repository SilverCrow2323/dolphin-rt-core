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
  boot_anim         = "full",
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
  M.migrate()
end

function M.save()
  FS.mkdir_p("data")
  FS.atomic_write(PATH, JSON.encode(M.data))
end

local function clean_rom_path(path)
  local p = tostring(path or ""):gsub("\\", "/"):gsub("/+", "/")
  if #p > 1 then p = p:gsub("/+$", "") end
  return p
end
local function rom_path_key(path) return clean_rom_path(path):lower() end
local function rom_system(value)
  local s = tostring(value or "GC"):upper()
  if s == "WII" then return "Wii" end
  if s == "BOTH" or s == "GC+WII" or s == "GC + WII" then return "Both" end
  return "GC"
end
local function merge_rom_system(a, b)
  a, b = rom_system(a), rom_system(b)
  if a == "Both" or b == "Both" then return "Both" end
  if a ~= b then return "Both" end
  return a
end

-- Migrate renamed settings and collapse legacy ROM root duplicates.
local _MIGRATIONS = {
  boot_animation = function(v) return { boot_anim = v and "full" or "off" } end,
}
function M.migrate()
  local changed = false
  for k, conv in pairs(_MIGRATIONS) do
    if M.data[k] ~= nil then
      for nk, nv in pairs(conv(M.data[k])) do M.data[nk] = nv end
      M.data[k] = nil
      changed = true
    end
  end

  local source = type(M.data.rom_paths) == "table" and M.data.rom_paths or {}
  local normalized, by_key = {}, {}
  for _, entry in ipairs(source) do
    if type(entry) == "table" and type(entry.path) == "string" and entry.path ~= "" then
      local path = clean_rom_path(entry.path)
      local system = rom_system(entry.system)
      local key = rom_path_key(path)
      local existing = by_key[key]
      if existing then
        local merged = merge_rom_system(existing.system, system)
        if existing.system ~= merged then existing.system = merged end
        changed = true
      else
        local item = copy(entry)
        item.path, item.system = path, system
        normalized[#normalized + 1] = item
        by_key[key] = item
        if entry.path ~= path or entry.system ~= system then changed = true end
      end
    else
      changed = true
    end
  end
  if type(M.data.rom_paths) ~= "table" or #normalized ~= #M.data.rom_paths then changed = true end
  M.data.rom_paths = normalized
  if changed then M.save() end
end

function M.get(k)      return M.data[k] end
function M.set(k, v)   M.data[k] = v; M.save() end

function M.add_rom_path(path, system)
  path = clean_rom_path(path)
  if path == "" then return false, "invalid" end
  system = rom_system(system)
  M.data.rom_paths = type(M.data.rom_paths) == "table" and M.data.rom_paths or {}
  local key = rom_path_key(path)
  for _, entry in ipairs(M.data.rom_paths) do
    if type(entry) == "table" and rom_path_key(entry.path) == key then
      local merged = merge_rom_system(entry.system, system)
      if merged ~= rom_system(entry.system) then
        entry.system = merged
        M.save()
        return true, "updated"
      end
      return false, "exists"
    end
  end
  table.insert(M.data.rom_paths, { path = path, system = system })
  M.save()
  return true, "added"
end

function M.remove_rom_path(idx)
  table.remove(M.data.rom_paths, idx)
  M.save()
end

return M
