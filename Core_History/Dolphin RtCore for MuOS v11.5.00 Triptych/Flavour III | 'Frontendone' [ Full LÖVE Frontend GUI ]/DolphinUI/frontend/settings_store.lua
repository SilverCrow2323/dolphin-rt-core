-- frontend/settings_store.lua
-- FrontendONE settings: load, get, set, save.
--
-- Storage: <frontend>/data/frontendone.json
-- Saves are atomic (write to .tmp, then rename).
--
-- ROM paths schema (multi-path, per system):
--   roms.paths_gc  = { "/abs/path/1", "/abs/path/2", ... }
--   roms.paths_wii = { "/abs/path/1", ... }
--
-- v0.5.0 — reset()
--   * M.reset() ripristina i defaults e riscrive il file.
--     Utile per uno screen "Factory Reset" futuro.

local json = require("json")
local sh   = require("sh")

local M = {}

local function S_state()
  local ok, s = pcall(require, "state")
  if ok then return s end
  return nil
end

local function store_path()
  local s = S_state()
  if s and s.frontend_path then
    return s.frontend_path("data/frontendone.json")
  end
  return "data/frontendone.json"
end

-- ── Defaults ────────────────────────────────────────────────
M.defaults = {
  general = {
    language       = "en",
    theme          = "gc",
    flip_animation = true,
    confirm_exit   = true,
  },
  roms = {
    paths_gc = {
      "/mnt/mmc/ROMS/gamecube",
      "/mnt/sdcard/roms/Nintendo GameCube",
    },
    paths_wii = {
      "/mnt/mmc/ROMS/wii",
      "/mnt/sdcard/roms/Nintendo Wii",
    },
    scan_recursive  = true,
    cache_enabled   = true,
    extensions      = "iso,gcm,rvz,wbfs",
  },
  double_theme = {
    enabled        = true,
    flip_sound     = true,
    mirror_layout  = true,
    theme_order    = "gc,wii",
  },
  ui = {
    show_header         = true,
    animations          = "full",
    background_animated = true,
    rough_borders       = true,
    show_fps            = false,
    particles           = true,
  },
  sfx = {
    enabled          = true,
    volume           = 70,
    ui_sounds        = true,
    boot_sound       = true,
    transition_sound = true,
  },
  advanced = {
    boot_animation            = true,
    spdw_warning              = true,
    enhancer_boot_animation   = true,
    homebrew_hub_splash       = true,

    update_check              = true,
    data_auto_download        = true,
    download_games_data       = true,
    download_rtenhancerhub    = true,
    download_wiitdb           = true,

    debug_mode                = false,
    log_level                 = "info",
    sfx_diagnose              = false,
  },
}

-- ── Validation ──────────────────────────────────────────────
local function is_valid_abs_path(v)
  if type(v) ~= "string" then return false end
  if v == "" then return false end
  if v:sub(1, 1) ~= "/" then return false end
  return true
end

-- ── Internal state ──────────────────────────────────────────
local data = nil

local function deep_copy(t)
  local c = {}
  for k, v in pairs(t) do
    c[k] = type(v) == "table" and deep_copy(v) or v
  end
  return c
end

local function merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      merge(dst[k], v)
    else
      dst[k] = v
    end
  end
end

-- ── Migration: single path → list ───────────────────────────
local function migrate_old_format(d)
  if type(d.roms) ~= "table" then return end
  if d.roms.path_gamecube and type(d.roms.path_gamecube) == "string" then
    local old = d.roms.path_gamecube
    d.roms.path_gamecube = nil
    if type(d.roms.paths_gc) ~= "table" then
      d.roms.paths_gc = {}
    end
    local present = false
    for _, p in ipairs(d.roms.paths_gc) do
      if p == old then present = true break end
    end
    if not present and old ~= "" then
      table.insert(d.roms.paths_gc, 1, old)
    end
  end
  if d.roms.path_wii and type(d.roms.path_wii) == "string" then
    local old = d.roms.path_wii
    d.roms.path_wii = nil
    if type(d.roms.paths_wii) ~= "table" then
      d.roms.paths_wii = {}
    end
    local present = false
    for _, p in ipairs(d.roms.paths_wii) do
      if p == old then present = true break end
    end
    if not present and old ~= "" then
      table.insert(d.roms.paths_wii, 1, old)
    end
  end
end

-- ── Public: load ────────────────────────────────────────────
function M.load()
  data = deep_copy(M.defaults)

  local path = store_path()
  local f = io.open(path, "r")
  if not f then
    f = io.open("data/frontendone.json", "r")
  end
  if not f then return data end

  local c = f:read("*a"); f:close()
  local ok, parsed = pcall(json.decode, c)
  if not ok or type(parsed) ~= "table" then
    print("[settings_store] cannot parse " .. path .. ", using defaults")
    return data
  end
  merge(data, parsed)

  migrate_old_format(data)

  if type(data.roms.paths_gc)  ~= "table" then data.roms.paths_gc  = {} end
  if type(data.roms.paths_wii) ~= "table" then data.roms.paths_wii = {} end
  for _, key in ipairs({ "paths_gc", "paths_wii" }) do
    local cleaned = {}
    for _, p in ipairs(data.roms[key]) do
      if is_valid_abs_path(p) then
        table.insert(cleaned, p)
      else
        print(string.format(
          "[settings_store] dropping invalid path in roms.%s: %q",
          key, tostring(p)))
      end
    end
    data.roms[key] = cleaned
  end

  return data
end

-- ── Public: get / set ───────────────────────────────────────
function M.get(section, key)
  if not data then M.load() end
  if key then
    return data[section] and data[section][key]
  end
  return data[section]
end

function M.set(section, key, value)
  if not data then M.load() end
  if not data[section] then data[section] = {} end
  data[section][key] = value
  return true
end

-- ── Public: path list API ───────────────────────────────────
local function key_for(system)
  if system == "gc"  or system == "GC"  then return "paths_gc" end
  if system == "wii" or system == "Wii" then return "paths_wii" end
  return nil
end

function M.get_paths(system)
  if not data then M.load() end
  local k = key_for(system)
  if not k then return {} end
  return data.roms[k] or {}
end

function M.add_path(system, path)
  if not data then M.load() end
  local k = key_for(system)
  if not k or not is_valid_abs_path(path) then return false, "invalid" end
  local list = data.roms[k]
  for _, p in ipairs(list) do
    if p == path then return false, "duplicate" end
  end
  table.insert(list, path)
  return true
end

function M.remove_path(system, index)
  if not data then M.load() end
  local k = key_for(system)
  if not k then return false end
  local list = data.roms[k]
  if index < 1 or index > #list then return false end
  table.remove(list, index)
  return true
end

function M.set_path(system, index, path)
  if not data then M.load() end
  local k = key_for(system)
  if not k or not is_valid_abs_path(path) then return false, "invalid" end
  local list = data.roms[k]
  if index < 1 or index > #list then return false end
  list[index] = path
  return true
end

-- ── Public: save ────────────────────────────────────────────
function M.save()
  if not data then return end
  local path = store_path()

  local dir = path:gsub("/[^/]+$", "")
  if dir ~= "" then sh.mkdir_p(dir) end

  local payload = json.encode(data)
  if not sh.atomic_write(path, payload) then
    local alt = "data/frontendone.json"
    local adir = alt:gsub("/[^/]+$", "")
    if adir ~= "" then sh.mkdir_p(adir) end
    sh.atomic_write(alt, payload)
  end
end

function M.data()
  if not data then M.load() end
  return data
end

-- ── Public: factory reset ───────────────────────────────────
-- Ripristina i defaults e riscrive il file. Da chiamare solo
-- da uno screen "Factory Reset" con conferma modale.
function M.reset()
  data = deep_copy(M.defaults)
  M.save()
  return true
end

return M