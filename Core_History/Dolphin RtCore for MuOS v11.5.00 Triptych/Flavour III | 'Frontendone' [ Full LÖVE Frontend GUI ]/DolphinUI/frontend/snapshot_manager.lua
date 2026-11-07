-- frontend/snapshot_manager.lua
-- Full configuration snapshots (backup all configs at once, restore later).
--
-- Layout:
--   <root>/frontend/workshop/snapshots/<id>/                  (snapshot dir)
--   <root>/frontend/workshop/snapshots/<id>/snapshot_data.ini (metadata)
--   <root>/frontend/workshop/snapshots/<id>/*.ini             (copied files)
--
-- Live configs live under <root>/dolphin-emu/Config/.
--
-- All shell args go through shq(). Snapshot labels are sanitized before
-- being used in filesystem paths.
--
-- restore/create use sh.atomic_copy: write to <dst>.tmp, verify it is
-- non-empty, then os.rename (atomic on POSIX, with a cp fallback for
-- FAT32). The previous revision did `cp` (no exit check) then
-- `os.remove(dst)` then `os.rename(tmp, dst)`, which could delete the
-- live config when the copy failed partway through.

local M = {}
local sh = require("sh")

local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close(); return true end
  return false
end

-- CWD is frontend/ (see mux_launch.sh), so both paths are relative to
-- it. The old root_dir() versions created frontend/frontend/workshop/
-- snapshots and looked for Config outside the app.
local function snapshots_root()
  return "workshop/snapshots"
end

local function config_dir()
  return "dolphin-emu/Config"
end

local function ensure_dir(p)
  sh.mkdir_p(p)
end

-- Sanitize a snapshot label for use as a path component.
local function safe_label(s)
  if type(s) ~= "string" then return "snapshot" end
  local clean = s:gsub("[^%w_%-]", "_")
  clean = clean:gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if clean == "" then return "snapshot" end
  if #clean > 40 then clean = clean:sub(1, 40) end
  return clean
end

local CONFIG_FILES = {
  "Dolphin.ini", "GFX.ini", "GCPadNew.ini",
  "WiimoteNew.ini", "Hotkeys.ini", "Logger.ini",
}

-- ── Public: create ──────────────────────────────────────────
function M.create(label)
  ensure_dir(snapshots_root())

  local t = os.date("*t")
  local id = string.format("%04d%02d%02d_%02d%02d%02d_%s",
    t.year, t.month, t.day, t.hour, t.min, t.sec,
    safe_label(label or "snapshot"))

  local dir = snapshots_root() .. "/" .. id
  ensure_dir(dir)

  local cfg = config_dir()
  for _, f in ipairs(CONFIG_FILES) do
    local src = cfg .. "/" .. f
    if file_exists(src) then
      sh.atomic_copy(src, dir .. "/" .. f)
    end
  end

  local mf = io.open(dir .. "/snapshot_data.ini", "w")
  if mf then
    mf:write("[Snapshot]\n")
    mf:write("Label = " .. (label or "snapshot") .. "\n")
    mf:write("Created = " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
    mf:write("Files = " .. #CONFIG_FILES .. "\n")
    mf:close()
  end
  return id
end

-- ── Public: list ────────────────────────────────────────────
local function parse_meta(path)
  local meta = {}
  local f = io.open(path, "r")
  if not f then return meta end
  local section = nil
  for line in f:lines() do
    local s = line:match("^%s*%[([^%]]+)%]")
    if s then
      section = s
    elseif section == "Snapshot" then
      local k, v = line:match("^%s*([^=]+)%s*=%s*(.*)$")
      if k then
        k = k:match("^%s*(.-)%s*$")
        v = v:match("^%s*(.-)%s*$")
        meta[k] = v
      end
    end
  end
  f:close()
  return meta
end

function M.list()
  ensure_dir(snapshots_root())
  local out = {}
  local root = snapshots_root()
  local h = io.popen('ls -1t ' .. sh.shq(root) .. ' 2>/dev/null')
  if not h then return out end

  for name in h:lines() do
    if name ~= "" and name:sub(1, 1) ~= "." then
      local dir = root .. "/" .. name
      if sh.is_dir(dir) then
        local meta = parse_meta(dir .. "/snapshot_data.ini")
        local total_kb = 0
        for _, f in ipairs(CONFIG_FILES) do
          local size = 0
          local fh = io.open(dir .. "/" .. f, "rb")
          if fh then
            fh:seek("end"); size = fh:seek(); fh:close()
          end
          total_kb = total_kb + math.floor(size / 1024)
        end
        table.insert(out, {
          id      = name,
          label   = meta.Label or name,
          created = meta.Created or "",
          size_kb = total_kb,
        })
      end
    end
  end
  h:close()
  return out
end

-- ── Public: restore ─────────────────────────────────────────
function M.restore(id)
  local dir = snapshots_root() .. "/" .. id
  if not sh.is_dir(dir) then return false end

  local BM  = require("backup_manager")
  local cfg = config_dir()

  -- Backup current files first (existing safety net).
  for _, f in ipairs(CONFIG_FILES) do
    if file_exists(cfg .. "/" .. f) then
      BM.backup(f)
    end
  end

  -- Atomic restore. Atomic copy never deletes dst before verifying tmp.
  local restored = 0
  for _, f in ipairs(CONFIG_FILES) do
    local src = dir .. "/" .. f
    if file_exists(src) then
      if sh.atomic_copy(src, cfg .. "/" .. f) then
        restored = restored + 1
      end
    end
  end
  return restored > 0
end

-- ── Public: delete ──────────────────────────────────────────
function M.delete(id)
  local name = safe_label(id)
  if name == "" or name == "snapshot" then return false end
  -- Prevent traversal: id must be a plain directory name.
  if id:find("[/\\]") or id:find("%.%.") then return false end
  local dir = snapshots_root() .. "/" .. id
  os.execute("rm -rf " .. sh.shq(dir))
  return true
end

return M