-- frontend/external.lua
-- Access layer for the external Dolphin Rt:Core installation on muOS.
--
-- Paths (fixed, per muOS convention):
--   /opt/muos/share/emulator/dolphin              → core root
--     Config/Dolphin.ini[.<profile>]              → main config + variants
--     Config/GFX.ini[.<profile>]                  → graphics config + variants
--     Config/GCPadNew.ini[.<n>joy,default]        → controller variants
--     Config/WiimoteNew.ini[.<n>joy[.sideways]]   → wiimote variants
--     GameSettings/<GAMEID>.ini                   → per-game overrides
--     rtdata/rt_joywatch.py, rt_keyinject.py      → live menu backend
--     Sys/, Load/, Wii/, GC/                      → resources
--   /opt/muos/share/task/Dolphin Rt:Core          → Bash Arsenal scripts
--   /opt/muos/share/info/assign/Nintendo Gamecube → registered profiles (GC)
--   /opt/muos/share/info/assign/Nintendo Wii      → registered profiles (Wii)
--   /opt/muos/script/launch/ext-dolphin.sh        → external launch entry point
--
-- v0.5.1 — full coverage of the Bash Arsenal tree
--   * New M.list_config_profiles()   → enumerate Config/*.ini.<name> pairs
--   * New M.current_config_profile() → md5-compare live vs variant
--   * New M.apply_config_profile(n)  → backup + copy variant over live
--   * New M.list_assign_profiles(s)  → read a system's assign registry
--   * New M.list_backups()           → enumerate .backup_* dirs
--   * M.list_dir now quotes paths via shq (the task dir has a space
--     and a colon in its name: "Dolphin Rt:Core"). The old "..." form
--     would have broken on the first double quote or shell metachar.
--   * Adds .is_python and .is_text flags to entries so the screen can
--     pick the right runner.

local M = {}

M.ROOT_TASKS  = "/opt/muos/share/task/Dolphin Rt:Core"
M.ROOT_EMU    = "/opt/muos/share/emulator/dolphin"
M.ROOT_ASSIGN = "/opt/muos/share/info/assign"
M.LAUNCH_SCRIPT = "/opt/muos/script/launch/ext-dolphin.sh"

-- ── shell helpers ───────────────────────────────────────────
local function shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end
M.shq = shq

local function exists(p)
  local f = io.open(p, "r")
  if f then f:close(); return true end
  return false
end

local function is_dir(p)
  local h = io.popen('[ -d ' .. shq(p) .. ' ] && echo 1 2>/dev/null')
  if not h then return false end
  local r = h:read("*a"); h:close()
  return r:match("1") ~= nil
end

local function read_file(p)
  local f = io.open(p, "r")
  if not f then return nil end
  local c = f:read("*a"); f:close()
  return c
end

local function ini_section(text, section)
  if not text then return {} end
  local t = {}
  local cur = nil
  for line in text:gmatch("[^\n]+") do
    local s = line:match("^%s*%[([^%]]+)%]")
    if s then
      cur = s
    elseif cur == section then
      local k, v = line:match("^%s*([^=]+)%s*=%s*(.*)$")
      if k then
        t[(k:gsub("%s+$", ""))] = (v:gsub("^%s+", ""))
      end
    end
  end
  return t
end

local function md5(p)
  if not exists(p) then return nil end
  local h = io.popen('md5sum ' .. shq(p) .. ' 2>/dev/null | cut -d" " -f1')
  if not h then return nil end
  local v = h:read("*a"):gsub("%s+", "")
  h:close()
  if v == "" then return nil end
  return v
end

-- ══════════════════════════════════════════════════════════════
--  Directory listing (generic)
-- ══════════════════════════════════════════════════════════════
function M.list_dir(path)
  local out = {}
  if not path or path == "" then return out end
  local h = io.popen('ls -1 ' .. shq(path) .. ' 2>/dev/null')
  if not h then return out end
  for name in h:lines() do
    if name ~= "" and name:sub(1, 1) ~= "." then
      local full = path .. "/" .. name
      local lower = name:lower()
      table.insert(out, {
        name       = name,
        path       = full,
        is_dir     = is_dir(full),
        is_script  = lower:match("%.sh$")   ~= nil,
        is_python  = lower:match("%.py$")   ~= nil,
        is_text    = lower:match("%.md$")   ~= nil
                  or lower:match("%.txt$")  ~= nil,
      })
    end
  end
  h:close()
  table.sort(out, function(a, b)
    if a.is_dir ~= b.is_dir then return a.is_dir end
    return a.name:lower() < b.name:lower()
  end)
  return out
end

-- ══════════════════════════════════════════════════════════════
--  Status (read live config)
-- ══════════════════════════════════════════════════════════════
function M.read_status()
  local S = { ok = true, fields = {}, sections = {} }

  S.installed = is_dir(M.ROOT_EMU)
  if not S.installed then
    S.ok = false
    return S
  end

  -- Version from rtdata/logs/overview.log if present, else from
  -- Dolphin.ini [Rt:Data] if the Bash Arsenal scripts write one there.
  local ov = read_file(M.ROOT_EMU .. "/rtdata/logs/overview.log")
  if ov then
    S.version = ov:match("Dolphin Rt:Core ([^\n]+)")
  end

  local d = read_file(M.ROOT_EMU .. "/Config/Dolphin.ini")
  if d then
    local rt = ini_section(d, "Rt:Data")
    S.profile     = rt.RtProfile or rt.Profile or nil
    local core = ini_section(d, "Core")
    S.overclock   = core.Overclock
    S.dual_core   = core.CPUThread
    S.idle_skip   = core.EnableIdleSkipping
    S.cpu_core    = core.CPUCore
    S.dsp_hle     = core.DSPHLE
    S.fastmem     = core.Fastmem
    S.mmu         = core.MMU
    S.sync_gpu    = core.SyncGPU
    S.skip_ipl    = core.SkipIPL
    local iface = ini_section(d, "Interface")
    S.osd         = iface.OnScreenDisplayMessages
    S.osd_dur     = iface.OSDMessageDuration
    S.ext_fps     = iface.ExtendedFPSInfo
    S.panic       = iface.UsePanicHandlers
  end

  local g = read_file(M.ROOT_EMU .. "/Config/GFX.ini")
  if g then
    local s = ini_section(g, "Settings")
    S.backend       = s.Backend
    S.resolution    = s.InternalResolution
    S.msaa          = s.MSAA
    S.shader_mode   = s.ShaderCompilationMode
    S.disable_fog   = s.DisableFog
    S.fast_depth    = s.FastDepthCalc
    S.hires         = s.HiresTextures
    local h = ini_section(g, "Hacks")
    S.efb_to_tex    = h.EFBToTextureEnable
    S.viskip        = h.VISkip
    S.bbox          = h.BBoxEnable
    local hw = ini_section(g, "Hardware")
    S.vsync         = hw.VSync
  end

  S.gc_bios = {
    USA = exists(M.ROOT_EMU .. "/GC/USA/IPL.bin"),
    EUR = exists(M.ROOT_EMU .. "/GC/EUR/IPL.bin"),
    JAP = exists(M.ROOT_EMU .. "/GC/JAP/IPL.bin"),
  }
  S.wii_nand = is_dir(M.ROOT_EMU .. "/Wii/title/00000001/00000002")

  -- Count GameSettings entries
  local gs = 0
  local p = io.popen('ls -1 ' .. shq(M.ROOT_EMU .. "/GameSettings") ..
                     ' 2>/dev/null | wc -l')
  if p then gs = tonumber(p:read("*a")) or 0; p:close() end
  S.gamesettings_count = gs

  -- Count Mods
  local mc = 0
  local q = io.popen('ls -1 ' .. shq(M.ROOT_EMU .. "/Load/GraphicMods") ..
                     ' 2>/dev/null | wc -l')
  if q then mc = tonumber(q:read("*a")) or 0; q:close() end
  S.mods_count = mc

  S.tasks_available = is_dir(M.ROOT_TASKS)
  return S
end

-- ══════════════════════════════════════════════════════════════
--  Config variants (Dolphin.ini.<x> + GFX.ini.<x>)
-- ══════════════════════════════════════════════════════════════
function M.list_config_profiles()
  local dir = M.ROOT_EMU .. "/Config"
  local seen, names = {}, {}
  local h = io.popen('ls -1 ' .. shq(dir) .. ' 2>/dev/null')
  if not h then return {} end
  for name in h:lines() do
    local dtail  = name:match("^Dolphin%.ini%.(.+)$")
    local gtail  = name:match("^GFX%.ini%.(.+)$")
    local prof   = dtail or gtail
    if prof then
      if not seen[prof] then
        seen[prof] = { name = prof, has_dolphin = false, has_gfx = false }
        table.insert(names, prof)
      end
      if dtail then seen[prof].has_dolphin = true end
      if gtail then seen[prof].has_gfx     = true end
    end
  end
  h:close()
  table.sort(names, function(a, b)
    -- "default" first, then alphabetical
    if a == "default" then return true end
    if b == "default" then return false end
    return a:lower() < b:lower()
  end)
  local out = {}
  for _, n in ipairs(names) do out[#out + 1] = seen[n] end
  return out
end

-- Compare Config/Dolphin.ini + Config/GFX.ini against each variant.
-- Returns the profile name on a full match, "custom" otherwise.
function M.current_config_profile()
  local dir = M.ROOT_EMU .. "/Config"
  local live_d = md5(dir .. "/Dolphin.ini")
  local live_g = md5(dir .. "/GFX.ini")
  if not live_d and not live_g then return "custom" end

  for _, p in ipairs(M.list_config_profiles()) do
    local match = true
    if p.has_dolphin then
      local v = md5(dir .. "/Dolphin.ini." .. p.name)
      if not v or v ~= live_d then match = false end
    end
    if match and p.has_gfx then
      local v = md5(dir .. "/GFX.ini." .. p.name)
      if not v or v ~= live_g then match = false end
    end
    if match then return p.name end
  end
  return "custom"
end

-- Backup live files into Config/.backup_<timestamp>/, then copy the
-- named variant over them. If the variant only provides one of the two
-- files (e.g. "blackscreenfix" only ships GFX.ini), only that file
-- is replaced; the other stays as-is.
--
-- Returns (ok, backup_dir_or_error).
function M.apply_config_profile(name)
  if type(name) ~= "string" or name == "" then
    return false, "invalid name"
  end
  if name:find("[/\\]") or name:find("%.%.") then
    return false, "unsafe name"
  end

  local dir = M.ROOT_EMU .. "/Config"
  local live_d = dir .. "/Dolphin.ini"
  local live_g = dir .. "/GFX.ini"
  local var_d  = dir .. "/Dolphin.ini." .. name
  local var_g  = dir .. "/GFX.ini." .. name

  if not exists(var_d) and not exists(var_g) then
    return false, "no variant file for '" .. name .. "'"
  end

  local ts = os.date("%Y%m%d_%H%M%S")
  local bdir = dir .. "/.backup_" .. ts
  os.execute("mkdir -p " .. shq(bdir))
  if exists(live_d) then
    os.execute("cp " .. shq(live_d) .. " " .. shq(bdir .. "/Dolphin.ini"))
  end
  if exists(live_g) then
    os.execute("cp " .. shq(live_g) .. " " .. shq(bdir .. "/GFX.ini"))
  end

  if exists(var_d) then
    local ok = os.execute("cp " .. shq(var_d) .. " " .. shq(live_d))
    if ok ~= true and ok ~= 0 then
      return false, "copy failed for " .. var_d
    end
  end
  if exists(var_g) then
    local ok = os.execute("cp " .. shq(var_g) .. " " .. shq(live_g))
    if ok ~= true and ok ~= 0 then
      return false, "copy failed for " .. var_g
    end
  end

  return true, bdir
end

-- List .backup_* directories in Config/, newest first.
function M.list_backups()
  local out = {}
  local dir = M.ROOT_EMU .. "/Config"
  local h = io.popen('ls -1d ' .. shq(dir) .. '/.backup_* 2>/dev/null')
  if not h then return out end
  for line in h:lines() do
    local name = line:match("([^/]+)$")
    if name then
      table.insert(out, { name = name, path = line })
    end
  end
  h:close()
  table.sort(out, function(a, b) return a.name > b.name end)
  return out
end

-- ══════════════════════════════════════════════════════════════
--  Assign registry (muOS-registered profiles per system)
-- ══════════════════════════════════════════════════════════════
function M.list_assign_profiles(system)
  -- system = "Nintendo Gamecube" or "Nintendo Wii"
  local dir = M.ROOT_ASSIGN .. "/" .. system
  local out = {}
  local h = io.popen('ls -1 ' .. shq(dir) .. '/*.ini 2>/dev/null')
  if not h then return out end
  for line in h:lines() do
    local name = line:match("([^/]+)$")
    if name and name ~= "global.ini" then
      local content = read_file(line)
      local g = ini_section(content, "global")
      table.insert(out, {
        name        = name:gsub("%.ini$", ""),
        file        = name,
        path        = line,
        label       = g.name or name,
        default     = g.default or "",
        catalogue   = g.catalogue or "",
      })
    end
  end
  h:close()
  table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
  return out
end

function M.read_assign_info()
  local info = { gc = {}, wii = {} }
  local function read_global(platform)
    local txt = read_file(M.ROOT_ASSIGN .. "/" .. platform .. "/global.ini")
    if not txt then return {} end
    local g = ini_section(txt, "global")
    return { name = g.name, default = g.default, catalogue = g.catalogue }
  end
  info.gc  = read_global("Nintendo Gamecube")
  info.wii = read_global("Nintendo Wii")

  local function count(platform)
    local dir = M.ROOT_ASSIGN .. "/" .. platform
    local p = io.popen('ls -1 ' .. shq(dir) .. '/*.ini 2>/dev/null | wc -l')
    if not p then return 0 end
    local n = tonumber(p:read("*a")) or 0
    p:close()
    return math.max(0, n - 1)   -- minus global.ini
  end
  info.gc.profiles  = count("Nintendo Gamecube")
  info.wii.profiles = count("Nintendo Wii")
  return info
end

-- ══════════════════════════════════════════════════════════════
--  Convenience
-- ══════════════════════════════════════════════════════════════
function M.exists(p)  return exists(p) end
function M.is_dir(p)  return is_dir(p) end
function M.read(p)    return read_file(p) end

return M