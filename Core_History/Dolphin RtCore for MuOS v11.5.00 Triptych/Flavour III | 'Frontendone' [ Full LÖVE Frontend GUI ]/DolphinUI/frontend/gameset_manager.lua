-- frontend/gameset_manager.lua
-- Multi-config per-game settings manager.
--
-- Layout:
--   workshop/gamesettings/<GAMEID>/
--   ├── rtgameset_data.ini       metadata
--   ├── <GAMEID>.ini             default config
--   └── <GAMEID>.ini.<label>     variants
--
-- Active config is copied to dolphin-emu/Config/GameSettings/<GAMEID>.ini
-- before launching. This module handles listing, selection, and copying.
--
-- BUGFIX (this revision):
--   write_metadata(game_id, gs, full) now really uses the third argument.
--   Previous revision silently dropped [Configs] on every set_active /
--   new_config / rename_config / delete_config call, because the third
--   argument was ignored and the Configs table was read from the wrong
--   level of the metadata tree.
--
-- All shell args go through shq(). Game IDs and labels are sanitized.

local PMerger = require("profile_merger")

local M = {}

local ROOT = "workshop/gamesettings"
local DEST = "dolphin-emu/Config/GameSettings"

local function shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function is_dir(p)
  local h = io.popen('timeout 1 [ -d ' .. shq(p) .. ' ] && echo 1 2>/dev/null')
  if not h then return false end
  local r = h:read("*a"); h:close()
  return r:match("1") ~= nil
end

local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close(); return true end
  return false
end

-- Strip everything but [A-Za-z0-9_-] from a label.
local function safe_label(s)
  if type(s) ~= "string" or s == "" then return nil end
  local clean = s:gsub("[^%w_%-]", "_")
  clean = clean:gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if clean == "" then return nil end
  if #clean > 32 then clean = clean:sub(1, 32) end
  return clean
end

local function safe_game_id(s)
  if type(s) ~= "string" or s == "" then return nil end
  if #s > 16 then return nil end
  if s:find("[^%w_%-]") then return nil end
  return s
end

-- ── Metadata read/write ─────────────────────────────────────
local function meta_path(game_id)
  return ROOT .. "/" .. game_id .. "/rtgameset_data.ini"
end

function M.read_metadata(game_id)
  local parsed = PMerger.parse_ini(meta_path(game_id))
  if not parsed then return nil end
  return parsed.data
end

-- write_metadata(game_id, gs, full)
--   gs   = the [GameSettings] table (GameID, GameName, System, Region,
--          ActiveConfig)
--   full = the whole metadata table, which also carries [Configs], [UI]
--          and any other section.
--
-- Legacy two-argument form (game_id, full) is accepted: `full.GameSettings`
-- becomes `gs` and `full` is kept as-is. This keeps older callers working
-- while the current callers can pass both explicitly.
function M.write_metadata(game_id, gs, full)
  if full == nil then
    -- Legacy call: the second argument IS the whole metadata table.
    full = gs or {}
    gs   = full.GameSettings or {}
  end
  gs   = gs   or {}
  full = full or {}

  -- Configs live at the metadata root, not inside [GameSettings].
  -- Accept either location so we never silently drop the list again.
  local configs = full.Configs
  if type(configs) ~= "table" then configs = gs.Configs end
  if type(configs) ~= "table" then configs = {} end

  local dir = ROOT .. "/" .. game_id
  os.execute("mkdir -p " .. shq(dir))

  local path = dir .. "/rtgameset_data.ini"
  local tmp  = path .. ".tmp"

  local f = io.open(tmp, "w")
  if not f then return false end

  local function w(s) f:write(s .. "\n") end

  w("[GameSettings]")
  w("GameID       = " .. (gs.GameID       or full.GameID       or game_id))
  w("GameName     = " .. (gs.GameName     or full.GameName     or ""))
  w("System       = " .. (gs.System       or full.System       or "GC"))
  w("Region       = " .. (gs.Region       or full.Region       or ""))
  w("ActiveConfig = " .. (gs.ActiveConfig or full.ActiveConfig or ""))
  w("")

  w("[Configs]")
  -- Deterministic output: sorted by filename. Old code iterated with
  -- pairs() so the file content changed order on every write.
  local keys = {}
  for k in pairs(configs) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, filename in ipairs(keys) do
    local label = configs[filename]
    if label and label ~= "" then
      w(filename .. " = " .. label)
    end
  end
  w("")

  w("[UI]")
  w("Color        = " .. (full.Color or "#4CC850"))
  w("Icon         = " .. (full.Icon  or "save"))

  -- Preserve any additional top-level section the caller passed in
  -- (Source, Origin, Description…) without hard-coding them here.
  for section, kv in pairs(full) do
    if type(kv) == "table"
       and section ~= "GameSettings"
       and section ~= "Configs"
       and section ~= "UI" then
      w("")
      w("[" .. tostring(section) .. "]")
      local skeys = {}
      for k in pairs(kv) do skeys[#skeys + 1] = k end
      table.sort(skeys)
      for _, k in ipairs(skeys) do
        w(tostring(k) .. " = " .. tostring(kv[k]))
      end
    end
  end

  f:close()

  -- Atomic replace. os.rename replaces atomically on POSIX. On FAT32
  -- (some SD cards) it may fail; fall back to cp.
  os.remove(path)
  local ok = os.rename(tmp, path)
  if not ok then
    os.execute("cp " .. shq(tmp) .. " " .. shq(path))
    os.remove(tmp)
  end
  return true
end

-- ── Listing ─────────────────────────────────────────────────
function M.list_game_ids()
  local out = {}
  local h = io.popen('timeout 2 ls -1 ' .. shq(ROOT) .. ' 2>/dev/null')
  if not h then return out end
  for name in h:lines() do
    name = name:match("^%s*(.-)%s*$")
    if name ~= "" and name:sub(1, 1) ~= "." then
      local dir = ROOT .. "/" .. name
      if is_dir(dir) then
        local meta = M.read_metadata(name) or {}
        local gs   = meta.GameSettings or {}
        local cfg  = meta.Configs or {}
        local count = 0
        for _ in pairs(cfg) do count = count + 1 end

        table.insert(out, {
          id      = name,
          name    = gs.GameName or name,
          system  = gs.System or "GC",
          region  = gs.Region or "",
          active  = gs.ActiveConfig or "",
          count   = count,
        })
      end
    end
  end
  h:close()
  table.sort(out, function(a, b)
    return (a.name or ""):lower() < (b.name or ""):lower()
  end)
  return out
end

function M.list_configs(game_id)
  local out = {}
  local dir = ROOT .. "/" .. game_id
  if not is_dir(dir) then return out end

  local meta = M.read_metadata(game_id) or {}
  local gs   = meta.GameSettings or {}
  local cfg  = meta.Configs or {}
  local active = gs.ActiveConfig or ""

  local h = io.popen('timeout 2 ls -1 ' .. shq(dir) .. '/*.ini* 2>/dev/null')
  if not h then return out end
  for full in h:lines() do
    local fname = full:match("([^/]+)$")
    if fname and fname ~= "rtgameset_data.ini" then
      local size = 0
      local fh = io.open(full, "rb")
      if fh then fh:seek("end"); size = fh:seek(); fh:close() end
      table.insert(out, {
        filename  = fname,
        label     = cfg[fname] or fname,
        is_active = (fname == active),
        path      = full,
        size      = size,
      })
    end
  end
  h:close()
  table.sort(out, function(a, b)
    if a.is_active then return true end
    if b.is_active then return false end
    return (a.label or ""):lower() < (b.label or ""):lower()
  end)
  return out
end

-- ── Active config ───────────────────────────────────────────
function M.get_active(game_id)
  local meta = M.read_metadata(game_id)
  if not meta or not meta.GameSettings then return nil end
  return meta.GameSettings.ActiveConfig
end

function M.set_active(game_id, filename)
  local meta = M.read_metadata(game_id) or {}
  meta.GameSettings = meta.GameSettings or {}
  meta.Configs      = meta.Configs      or {}
  meta.GameSettings.ActiveConfig = filename
  -- ensure it's registered in [Configs]
  if not meta.Configs[filename] then
    meta.Configs[filename] = filename
  end
  return M.write_metadata(game_id, meta.GameSettings, meta)
end

-- ── Apply to dolphin-emu/Config/GameSettings/ ───────────────
function M.apply_active(game_id)
  local active = M.get_active(game_id)
  if not active then return false, "no active config" end

  local src = ROOT .. "/" .. game_id .. "/" .. active
  if not file_exists(src) then return false, "source missing" end

  os.execute("mkdir -p " .. shq(DEST))
  local dst = DEST .. "/" .. game_id .. ".ini"

  os.execute("cp " .. shq(src) .. " " .. shq(dst))
  return true
end

-- ── Create / rename / delete ────────────────────────────────
function M.new_config(game_id, label, source_filename)
  local gid   = safe_game_id(game_id)
  local lclean = safe_label(label)
  if not gid or not lclean then return false, "invalid" end

  local dir = ROOT .. "/" .. gid
  if not is_dir(dir) then return false, "game dir missing" end

  -- Filename scheme: <GAMEID>.ini.<label>
  local filename = gid .. ".ini." .. lclean
  local target   = dir .. "/" .. filename
  if file_exists(target) then return false, "already exists" end

  -- Source: existing config, or a new empty one
  local src = source_filename and (dir .. "/" .. source_filename) or nil
  if src and file_exists(src) then
    os.execute("cp " .. shq(src) .. " " .. shq(target))
  else
    local f = io.open(target, "w")
    if not f then return false, "cannot create" end
    f:write("# " .. gid .. " - " .. label .. "\n")
    f:write("# Created by DolphinUI GameSettings editor\n\n")
    f:write("[Core]\n")
    f:write("# Override keys here, e.g.:\n")
    f:write("# OverclockEnable = True\n")
    f:write("# Overclock = 0.70\n")
    f:close()
  end

  -- Register in metadata
  local meta = M.read_metadata(gid) or {}
  meta.GameSettings = meta.GameSettings or { GameID = gid }
  meta.Configs      = meta.Configs or {}
  meta.Configs[filename] = label
  return M.write_metadata(gid, meta.GameSettings, meta)
end

function M.rename_config(game_id, filename, new_label)
  local gid = safe_game_id(game_id)
  if not gid then return false end
  local lclean = safe_label(new_label)
  if not lclean then return false, "invalid label" end

  local dir = ROOT .. "/" .. gid
  local old_path = dir .. "/" .. filename
  if not file_exists(old_path) then return false, "source missing" end

  -- New filename keeps the game_id prefix
  local new_filename = gid .. ".ini." .. lclean

  -- If the label is unchanged, just update metadata
  if new_filename == filename then
    local meta = M.read_metadata(gid) or {}
    meta.Configs = meta.Configs or {}
    meta.Configs[filename] = new_label
    return M.write_metadata(gid, meta.GameSettings or {}, meta)
  end

  if file_exists(dir .. "/" .. new_filename) then
    return false, "target exists"
  end

  os.execute("mv " .. shq(old_path) .. " " .. shq(dir .. "/" .. new_filename))

  -- Update metadata
  local meta = M.read_metadata(gid) or {}
  meta.Configs = meta.Configs or {}
  meta.Configs[filename] = nil
  meta.Configs[new_filename] = new_label
  meta.GameSettings = meta.GameSettings or {}
  if meta.GameSettings.ActiveConfig == filename then
    meta.GameSettings.ActiveConfig = new_filename
  end
  return M.write_metadata(gid, meta.GameSettings, meta)
end

function M.delete_config(game_id, filename)
  local gid = safe_game_id(game_id)
  if not gid then return false end
  if filename == "rtgameset_data.ini" then return false end

  local dir = ROOT .. "/" .. gid
  local path = dir .. "/" .. filename
  if not file_exists(path) then return false end

  os.remove(path)

  local meta = M.read_metadata(gid) or {}
  meta.Configs = meta.Configs or {}
  meta.Configs[filename] = nil
  meta.GameSettings = meta.GameSettings or {}
  if meta.GameSettings.ActiveConfig == filename then
    -- Promote the first remaining config, if any
    local next_cfg = nil
    for k in pairs(meta.Configs) do next_cfg = k; break end
    meta.GameSettings.ActiveConfig = next_cfg or ""
  end
  return M.write_metadata(gid, meta.GameSettings, meta)
end

return M