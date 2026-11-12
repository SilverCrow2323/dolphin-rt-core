-- User settings, persisted as JSON in data/settings.json.
-- The only place that touches user preferences.
local JSON = require("core.json")
local FS   = require("core.fs")
local Shell = require("core.shell")

local M = {}

local PATH = "data/settings.json"

local defaults = {
  rom_paths         = {},
  rom_discovery_done = false,
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

-- muOS can mount the ROM partition under different device paths and the
-- directory spelling is not consistent across firmware generations.
-- Probe the configured mount first, then conservative known fallbacks.
function M.rom_root_candidates()
  local roots, seen = {}, {}
  local function add(path)
    if type(path) ~= "string" or path == "" then return end
    path = path:gsub("/+$", "")
    if path ~= "" and not seen[path] then
      seen[path] = true
      roots[#roots + 1] = path
    end
  end

  local probe = "sh -c " .. Shell.shq(
    ". /opt/muos/script/var/func.sh >/dev/null 2>&1; GET_VAR \"device\" \"storage/rom/mount\" 2>/dev/null")
  local mount = Shell.first(probe, 5)
  if type(mount) == "string" and mount ~= "" then
    add(mount .. "/roms")
    add(mount .. "/ROMS")
  end

  for _, path in ipairs({
    "/mnt/sdcard/roms", "/mnt/sdcard/ROMS",
    "/mnt/mmc/roms", "/mnt/mmc/ROMS",
    "/mnt/union/roms", "/mnt/union/ROMS",
    "/roms",
  }) do add(path) end

  return roots
end

-- First-run discovery deliberately registers the whole ROM root for both
-- platforms. The library scanner reads disc IDs from headers, so mixed
-- GameCube/Wii roots are split correctly without guessing from folder names.
-- No directory is created, renamed, moved, or modified by this routine.
function M.auto_discover_rom_paths()
  if M.data.rom_discovery_done == true then
    -- Older releases marked discovery complete merely because rom_paths was
    -- non-empty. Validate those entries before trusting the marker.
    local current = M.data.rom_paths or {}
    local valid = false
    for _, entry in ipairs(current) do
      if entry.path and FS.is_dir(entry.path) then
        local cmd = "find " .. Shell.shq(entry.path) .. " -maxdepth 5 -type f "
          .. [[\( -iname '*.iso' -o -iname '*.gcm' -o -iname '*.rvz' -o -iname '*.gcz' -o -iname '*.ciso' -o -iname '*.wbfs' -o -iname '*.wia' \)]]
          .. " -print -quit 2>/dev/null"
        local sample = Shell.first(cmd, 8)
        if type(sample) == "string" and sample ~= "" then valid = true; break end
      end
    end
    if valid then return 0 end
    M.data.rom_discovery_done = false
  end

  local current = M.data.rom_paths or {}
  local valid_current, checked = false, {}
  local function contains_roms(path)
    if type(path) ~= "string" or path == "" or not FS.is_dir(path) then return false end
    local real = Shell.first("readlink -f " .. Shell.shq(path), 4)
    if type(real) ~= "string" or real == "" then real = path end
    if checked[real] ~= nil then return checked[real], real end
    local extensions = [[\( -iname '*.iso' -o -iname '*.gcm' -o -iname '*.rvz' -o -iname '*.gcz' -o -iname '*.ciso' -o -iname '*.wbfs' -o -iname '*.wia' \)]]
    local cmd = "find " .. Shell.shq(real) .. " -maxdepth 5 -type f " ..
      extensions .. " -print -quit 2>/dev/null"
    local sample = Shell.first(cmd, 8)
    checked[real] = type(sample) == "string" and sample ~= ""
    return checked[real], real
  end

  for _, entry in ipairs(current) do
    local has = contains_roms(entry.path)
    if has then valid_current = true end
  end
  if valid_current then
    M.data.rom_discovery_done = true
    M.save()
    return 0
  end

  -- Stale defaults / paths from older installations are not trusted. Probe
  -- the actual muOS ROM mount and known fallback mounts instead of stopping
  -- just because settings.json contains two obsolete folder names.
  local found, seen = 0, {}
  for _, path in ipairs(M.rom_root_candidates()) do
    local has, real = contains_roms(path)
    if has and not seen[real] then
      seen[real] = true
      local before = #M.data.rom_paths
      M.add_rom_path(real, "GC")
      M.add_rom_path(real, "Wii")
      if #M.data.rom_paths > before then found = found + 1 end
    end
  end

  M.data.rom_discovery_done = (found > 0)
  M.save()
  return found
end
return M
