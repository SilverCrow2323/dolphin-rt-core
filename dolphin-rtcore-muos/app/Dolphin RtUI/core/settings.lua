-- User settings, persisted as JSON in data/settings.json.
-- The only place that touches user preferences.
local JSON = require("core.json")
local FS   = require("core.fs")
local Shell = require("core.shell")

local M = {}

local PATH = "data/settings.json"

local defaults = {
  muos_profile      = "auto", -- auto | andromeda | not_andromeda
  rom_paths         = {},
  rom_discovery_done = false,
  theme             = "gc",
  scan_depth        = 8,
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

local function rom_path_key(path)
  if type(path) ~= "string" or path == "" then return "" end
  local clean = path:gsub("/+$", "")
  local real = Shell.first("readlink -f " .. Shell.shq(clean), 3)
  if type(real) == "string" and real ~= "" then clean = real end
  return clean:lower()
end

function M.normalize_rom_paths()
  local out, seen, changed = {}, {}, false
  for _, entry in ipairs(M.data.rom_paths or {}) do
    if type(entry) == "table" and type(entry.path) == "string" and entry.path ~= "" then
      local key = rom_path_key(entry.path)
      local previous = seen[key]
      if previous then
        if previous.system ~= entry.system then previous.system = "Both" end
        changed = true
      else
        local clean = entry.path:gsub("/+$", "")
        local copy = { path = clean, system = entry.system or "GC" }
        out[#out + 1] = copy
        seen[key] = copy
        if clean ~= entry.path then changed = true end
      end
    else
      changed = true
    end
  end
  if #out ~= #(M.data.rom_paths or {}) then changed = true end
  M.data.rom_paths = out
  if changed then M.save() end
  return changed
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
  M.normalize_rom_paths()
end

function M.save()
  FS.mkdir_p("data")
  FS.atomic_write(PATH, JSON.encode(M.data))
end

-- Migrazione chiavi rinominate (idempotente). Chiamata da init().
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
  if changed then M.save() end
end

function M.get(k)      return M.data[k] end
function M.set(k, v)   M.data[k] = v; M.save() end

function M.add_rom_path(path, system)
  system = system or "GC"
  if type(path) ~= "string" or path == "" or (system ~= "GC" and system ~= "Wii") then return false end
  M.normalize_rom_paths()
  local key = rom_path_key(path)
  for _, entry in ipairs(M.data.rom_paths or {}) do
    if rom_path_key(entry.path) == key then
      if entry.system ~= system and entry.system ~= "Both" then entry.system = "Both" end
      M.data.rom_discovery_done = true
      M.save()
      return false
    end
  end
  table.insert(M.data.rom_paths, { path = path:gsub("/+$", ""), system = system })
  M.data.rom_discovery_done = true
  M.save()
  return true
end

function M.remove_rom_path(idx)
  table.remove(M.data.rom_paths, idx)
  M.save()
end

-- muOS can mount the ROM partition under different device paths and the
-- directory spelling is not consistent across firmware generations.
-- Probe the configured mount first, then conservative known fallbacks.
function M.rom_root_candidates()
  local roots, seen = {}, {}
  local function add(path)
    if type(path) ~= "string" or path == "" then return end
    path = path:gsub("/+$", "")
    local key = rom_path_key(path)
    if key ~= "" and not seen[key] then
      seen[key] = true
      roots[#roots + 1] = path
    end
  end
  local probe = "sh -c " .. Shell.shq(
    ". /opt/muos/script/var/func.sh >/dev/null 2>&1; GET_VAR \"device\" \"storage/rom/mount\" 2>/dev/null")
  local mount = Shell.first(probe, 5)
  if type(mount) == "string" and mount ~= "" then add(mount .. "/roms") end
  for _, path in ipairs({ "/mnt/sdcard/roms", "/mnt/mmc/roms", "/mnt/union/roms", "/roms" }) do add(path) end
  return roots
end

-- Backwards-compatible no-op. ROM paths are never registered automatically.
function M.auto_discover_rom_paths()
  return 0
end
return M
