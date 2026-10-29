-- frontend/screens/game_detail.lua
-- Game details: Overview, Files, Reports.
--
-- ── v1.1.0 — fixed layout + icon buttons ─────────────────────
--   * Fixed the "attempt to get length of local 'value' (a boolean
--     value)" crash: row objects are now consistently shaped
--     { card, kind, label, get, set } and read via named fields.
--   * Layout constants are absolute coordinates. Banner, LAUNCH,
--     and card grids no longer overlap.
--   * LAUNCH button uses a procedural [Y] badge via BI.draw, not
--     literal text.
--   * Overview card grid: 2 rows (varied widths), fit within the
--     screen at 640x480.
--   * Files / Reports tabs do NOT draw the banner; they use their
--     own title strip.
--   * All strings in English.

local A       = require("assets")
local SFX     = require("sfx")
local State   = require("state")
local IM      = require("input_map")
local D       = require("ui.draw")
local BG      = require("ui.bg")
local Header  = require("ui.header")
local BI      = require("ui.button_icons")
local GL      = require("ui.glyph")
local Icons   = require("ui.icons")
local Modal   = require("modal")
local Notify  = require("notify")
local Launcher = require("launcher")
local Covers  = require("covers")
local sh      = require("sh")

local S = {}
local W, H = 640, 480

-- ══════════════════════════════════════════════════════════════
--  ABSOLUTE LAYOUT
-- ══════════════════════════════════════════════════════════════
local HEADER_H    = 78          -- Header.height() assumed
local TABS_Y      = 82
local TABS_H      = 26
local BANNER_Y    = 114
local BANNER_H    = 100
local LAUNCH_Y    = 220
local LAUNCH_H    = 32
local CONTENT_Y   = 258
local CONTENT_H   = 194         -- to 452
local FOOTER_Y    = 452

-- Overview cards
local CARD_R1_Y   = CONTENT_Y            -- 258
local CARD_R1_H   = 98
local CARD_R2_Y   = CONTENT_Y + CARD_R1_H + 6   -- 362
local CARD_R2_H   = 90

local CARD_RECT = {
  profiles = { x =  20, y = CARD_R1_Y, w = 350, h = CARD_R1_H },
  overlays = { x = 380, y = CARD_R1_Y, w = 240, h = CARD_R1_H },
  content  = { x =  20, y = CARD_R2_Y, w = 190, h = CARD_R2_H },
  logging  = { x = 220, y = CARD_R2_Y, w = 190, h = CARD_R2_H },
  mods     = { x = 420, y = CARD_R2_Y, w = 200, h = CARD_R2_H },
}

local CARD_META = {
  profiles = { title = "PROFILE CONFIG",   icon = "settings",  color = {0.55, 0.35, 0.95} },
  overlays = { title = "OVERLAY TOGGLES",  icon = "info",      color = {0.20, 0.72, 0.98} },
  content  = { title = "CONTENT",          icon = "library",   color = {0.90, 0.35, 0.55} },
  logging  = { title = "LOGGING",          icon = "logging",   color = {0.96, 0.77, 0.26} },
  mods     = { title = "GRAPHIC MODS",     icon = "enhancer",  color = {0.30, 0.85, 0.40} },
}

local TABS = {
  { label = "OVERVIEW", key = "overview", color = {0.20, 0.72, 0.98}, icon = "info" },
  { label = "FILES",    key = "files",    color = {0.96, 0.77, 0.26}, icon = "advanced" },
  { label = "REPORTS",  key = "reports",  color = {0.30, 0.85, 0.40}, icon = "chart" },
}

S.game        = nil
S.tab         = 1
S.sel         = 1
S.report_sel  = 1
S.compat      = nil
S.file_info   = nil
S.gamesets    = {}
S.gameset_active = nil
S.mods        = {}
S.textures    = {}
S.cheats      = {}
S._overview_rows = nil

-- ══════════════════════════════════════════════════════════════
--  INI HELPERS
-- ══════════════════════════════════════════════════════════════
local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close(); return true end
  return false
end

local function emu_config_dir()
  return State.opts.core == "external"
    and "/opt/muos/share/emulator/dolphin/Config"
    or  "dolphin-emu/Config"
end
local function GFX_INI()     return emu_config_dir() .. "/GFX.ini"    end
local function DOLPHIN_INI() return emu_config_dir() .. "/Dolphin.ini" end
local function LOGGER_INI()  return emu_config_dir() .. "/Logger.ini" end

local function ini_read(path, section, key)
  local f = io.open(path, "r")
  if not f then return nil end
  local cur, val = nil, nil
  for line in f:lines() do
    local s = line:match("^%s*%[([^%]]+)%]")
    if s then cur = s
    elseif cur == section then
      local k, v = line:match("^%s*([^=]+)%s*=%s*(.*)$")
      if k and k:match("^%s*(.-)%s*$") == key then
        val = v:match("^%s*(.-)%s*$"); break
      end
    end
  end
  f:close()
  return val
end

local function ini_write(path, section, key, value)
  local f = io.open(path, "r")
  if not f then
    local w = io.open(path .. ".tmp", "w")
    if not w then return false end
    w:write("[" .. section .. "]\n")
    w:write(key .. " = " .. tostring(value) .. "\n")
    w:close()
    os.remove(path)
    return os.rename(path .. ".tmp", path) ~= nil
  end
  local lines, cur, done, found = {}, nil, false, false
  for line in f:lines() do
    local s = line:match("^%s*%[([^%]]+)%]")
    if s then
      if cur == section and not done then
        table.insert(lines, key .. " = " .. tostring(value)); done = true
      end
      cur = s
      if s == section then found = true end
      table.insert(lines, line)
    elseif cur == section then
      local k = line:match("^%s*([^=]+)%s*=")
      if k and k:match("^%s*(.-)%s*$") == key then
        table.insert(lines, key .. " = " .. tostring(value)); done = true
      else
        table.insert(lines, line)
      end
    else
      table.insert(lines, line)
    end
  end
  f:close()
  if not done and found then
    table.insert(lines, key .. " = " .. tostring(value))
  elseif not done then
    table.insert(lines, ""); table.insert(lines, "[" .. section .. "]")
    table.insert(lines, key .. " = " .. tostring(value))
  end
  local tmp = path .. ".tmp"
  local w = io.open(tmp, "w")
  if not w then return false end
  for _, l in ipairs(lines) do w:write(l .. "\n") end
  w:close()
  os.remove(path)
  return os.rename(tmp, path) ~= nil
end

local function get_overlay(k)
  if k == "fps"   then return ini_read(GFX_INI(), "Settings", "ShowFPS") == "True" end
  if k == "vps"   then return ini_read(DOLPHIN_INI(), "Interface", "ExtendedFPSInfo") == "True" end
  if k == "speed" then return ini_read(GFX_INI(), "Settings", "OverlayStats") == "True" end
  return false
end
local function set_overlay(k, on)
  local v = on and "True" or "False"
  if k == "fps"   then ini_write(GFX_INI(), "Settings", "ShowFPS", v) end
  if k == "vps"   then ini_write(DOLPHIN_INI(), "Interface", "ExtendedFPSInfo", v) end
  if k == "speed" then ini_write(GFX_INI(), "Settings", "OverlayStats", v) end
end

local function get_osd() return ini_read(DOLPHIN_INI(), "Interface", "OnScreenDisplayMessages") ~= "False" end
local function set_osd(v) ini_write(DOLPHIN_INI(), "Interface", "OnScreenDisplayMessages", v and "True" or "False") end

local function get_logger()   return ini_read(LOGGER_INI(), "Options", "WriteToFile") == "True" end
local function set_logger(v)  ini_write(LOGGER_INI(), "Options", "WriteToFile", v and "True" or "False") end
local function get_debugger() local v = tonumber(ini_read(LOGGER_INI(), "Options", "Verbosity") or "0") or 0; return v >= 5 end
local function set_debugger(v) ini_write(LOGGER_INI(), "Options", "Verbosity", v and "5" or "4") end

local function get_gfxmods() return ini_read(GFX_INI(), "Hacks", "EnableGraphicsMods") == "True" end
local function set_gfxmods(v) ini_write(GFX_INI(), "Hacks", "EnableGraphicsMods", v and "True" or "False") end
local function get_hires()   return ini_read(GFX_INI(), "Settings", "HiresTextures") == "True" end
local function set_hires(v)  ini_write(GFX_INI(), "Settings", "HiresTextures", v and "True" or "False") end
local function get_cheat_engine() return ini_read(DOLPHIN_INI(), "Core", "EnableCheats") == "True" end
local function set_cheat_engine(v) ini_write(DOLPHIN_INI(), "Core", "EnableCheats", v and "True" or "False") end

-- ══════════════════════════════════════════════════════════════
--  RATING HELPERS
-- ══════════════════════════════════════════════════════════════
local function rating_color(r)
  r = tonumber(r) or 0
  if r >= 5 then return {0.25, 0.85, 0.40} end
  if r == 4 then return {0.60, 0.85, 0.30} end
  if r == 3 then return {0.96, 0.82, 0.22} end
  if r == 2 then return {0.98, 0.55, 0.22} end
  if r == 1 then return {0.95, 0.30, 0.20} end
  return {0.85, 0.12, 0.12}
end
local function rating_label(r)
  r = tonumber(r) or 0
  if r >= 5 then return "PERFECT" end
  if r == 4 then return "PLAYABLE" end
  if r == 3 then return "WITH ISSUES" end
  if r == 2 then return "UNPLAYABLE" end
  if r == 1 then return "BROKEN" end
  return "NO BOOT"
end

local function draw_star(cx, cy, r, col, filled)
  local pts = {}
  for i = 0, 9 do
    local a = -math.pi / 2 + i * math.pi / 5
    local rad = (i % 2 == 0) and r or (r * 0.42)
    pts[#pts + 1] = cx + math.cos(a) * rad
    pts[#pts + 1] = cy + math.sin(a) * rad
  end
  if filled then
    love.graphics.setColor(col[1], col[2], col[3], 0.22)
    love.graphics.polygon("fill", pts)
  end
  love.graphics.setColor(col[1], col[2], col[3], 1)
  love.graphics.setLineWidth(1.6)
  love.graphics.polygon("line", pts)
  love.graphics.setLineWidth(1)
end

local function draw_rating_ring(cx, cy, radius, rating, th)
  local r = tonumber(rating) or 0
  local c = rating_color(r)
  D.glow(cx, cy, radius + 12, c, 0.55)
  love.graphics.setColor(c[1] * 0.20, c[2] * 0.20, c[3] * 0.20, 1)
  love.graphics.setLineWidth(6)
  love.graphics.circle("line", cx, cy, radius)
  if r > 0 then
    local frac = math.min(1, r / 5)
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.arc("line", "open", cx, cy, radius,
      -math.pi / 2, -math.pi / 2 + 2 * math.pi * frac)
  end
  love.graphics.setLineWidth(1)
  love.graphics.setColor(0.05, 0.06, 0.10, 0.95)
  love.graphics.circle("fill", cx, cy, radius - 4)
  love.graphics.setColor(c[1], c[2], c[3], 1)
  love.graphics.setFont(A.font(th.font_body_bold, 22))
  love.graphics.printf(tostring(r), cx - radius, cy - 12, radius * 2, "center")
  draw_star(cx, cy + radius * 0.42, 4, c, false)
end

-- ══════════════════════════════════════════════════════════════
--  CACHE BUILDERS (unchanged from previous version)
-- ══════════════════════════════════════════════════════════════
local function build_file_info(game)
  if not game or not game.path or game.virtual then return nil end
  if not file_exists(game.path) then return nil end
  local info = { path = game.path }
  info.name = game.path:match("([^/]+)$") or game.path
  info.dir  = game.path:match("^(.+)/[^/]+$") or ""
  info.ext  = (info.name:match("%.([^.]+)$") or ""):lower()
  info.size = tonumber(sh.read('stat -c %s ' .. sh.shq(game.path), 0, "sz:" .. game.path)) or 0
  local st = sh.read('stat -c "%A|%y" ' .. sh.shq(game.path), 0, "st:" .. game.path)
  if st then
    info.perms = st:match("^([^|]+)") or "?"
    info.mtime = (st:match("|(.+)$") or ""):gsub("%s+%S+$", "")
  end
  local magic = sh.read('xxd -p -l 8 ' .. sh.shq(game.path) .. " 2>/dev/null")
  if not magic or magic == "" then
    magic = sh.read('od -An -tx1 -N8 ' .. sh.shq(game.path) .. " 2>/dev/null | tr -d ' \\n'")
  end
  info.magic = (magic or ""):gsub("%s+", ""):gsub("\n", ""):upper()
  info.cover = Covers.find(game) and true or false
  local id = game.id
  if id and id ~= "" then
    local base = State.opts.core == "external"
      and "/opt/muos/share/emulator/dolphin/StateSaves"
      or  "dolphin-emu/StateSaves"
    local out = sh.read('ls -1 ' .. sh.shq(base) .. " 2>/dev/null | grep -c '^" .. id .. "'")
    info.save_count = tonumber((out or ""):match("(%d+)")) or 0
  else
    info.save_count = 0
  end
  return info
end

local function scan_gamesets(game)
  if not game or not game.id or game.id == "" or game.virtual then return {}, nil end
  local ok, GM = pcall(require, "gameset_manager")
  if not ok or not GM then return {}, nil end
  return GM.list_configs(game.id) or {}, GM.get_active(game.id)
end

local function mod_matches_game(mod_name, game)
  local m = mod_name:lower()
  if m:find("^all games") then return true end
  if game.id and game.id ~= "" and m:find(game.id:lower(), 1, true) then return true end
  if game.title then
    for word in game.title:lower():gmatch("%a%a%a%a+") do
      if m:find(word, 1, true) then return true end
    end
  end
  return false
end

local function scan_mods(game)
  local out = {}
  local root = "dolphin-emu/Load/GraphicMods"
  local entries = sh.lines('timeout 2 ls -1 ' .. sh.shq(root) .. " 2>/dev/null", 0, "gm:" .. root)
  for _, name in ipairs(entries or {}) do
    if name ~= "" and name:sub(1, 1) ~= "." and mod_matches_game(name, game) then
      local path = root .. "/" .. name
      out[#out + 1] = { name = name, path = path, disabled = file_exists(path .. "/.disabled") }
    end
  end
  table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
  return out
end

local function scan_textures(game)
  local out = {}
  if not game.id or game.id == "" then return out end
  local root = "dolphin-emu/Load/Textures/" .. game.id
  if not sh.is_dir(root) then return out end
  local entries = sh.lines('timeout 2 ls -1 ' .. sh.shq(root), 0, "tx:" .. root)
  for _, name in ipairs(entries or {}) do
    if name ~= "" and name:sub(1, 1) ~= "." then
      local path = root .. "/" .. name
      if sh.is_dir(path) then
        out[#out + 1] = { name = name, path = path, disabled = file_exists(path .. "/.disabled") }
      end
    end
  end
  table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
  return out
end

local function scan_cheats(game)
  local out = {}
  if not game.id or game.id == "" then return out end
  local path = emu_config_dir() .. "/GameSettings/" .. game.id .. ".ini"
  if not file_exists(path) then return out end
  local f = io.open(path, "r")
  if not f then return out end
  local section, line_no = nil, 0
  for line in f:lines() do
    line_no = line_no + 1
    local s = line:match("^%s*%[([^%]]+)%]")
    if s then section = s
    elseif section == "ActionReplay" then
      local raw = line:match("^%s*(%$[^\n]*)")
      if raw then
        local disabled = raw:sub(1, 2) == "$*"
        local name = disabled and raw:sub(3) or raw:sub(2)
        out[#out + 1] = { name = name, disabled = disabled, line_no = line_no, raw = line, path = path }
      end
    end
  end
  f:close()
  return out
end

-- ══════════════════════════════════════════════════════════════
--  OVERVIEW ROWS — clean shape
-- ══════════════════════════════════════════════════════════════
local function add_row(rows, card, kind, label, get, set)
  rows[#rows + 1] = {
    card  = card,
    kind  = kind,   -- "toggle" | "cycle" | "info"
    label = label,
    get   = get,
    set   = set,
  }
end

local function build_overview_rows()
  local rows = {}
  local game = S.game

  -- ── profiles card
  add_row(rows, "profiles", "cycle", "Core Profile",
    function() return State.opts.profile or "Default" end,
    function(dir)
      local list = { "Default", "Performance", "Compatibility", "Speedhack",
                     "Sweet Spot", "Ultra", "Ultra Extreme", "Black Screen Fix" }
      local cur = State.opts.profile or "Default"
      local idx = 1
      for i, v in ipairs(list) do if v == cur then idx = i break end end
      idx = ((idx - 1 + dir) % #list) + 1
      State.opts.profile = list[idx]
      pcall(function()
        local PM = require("profile_manager")
        PM.apply("rtcoreprofile", State.opts.profile)
        PM.set_active("rtcoreprofile", State.opts.profile)
      end)
    end)

  add_row(rows, "profiles", "cycle", "GameSettings",
    function()
      local a = S.gameset_active
      if a and a ~= "" then return a end
      return "(none)"
    end,
    function(dir)
      if not game or not game.id or game.id == "" then return end
      local list = { { filename = "" } }
      for _, c in ipairs(S.gamesets) do list[#list + 1] = c end
      local cur = S.gameset_active or ""
      local idx = 1
      for i, v in ipairs(list) do if v.filename == cur then idx = i break end end
      idx = ((idx - 1 + dir) % #list) + 1
      require("gameset_manager").set_active(game.id, list[idx].filename)
      S.gamesets, S.gameset_active = scan_gamesets(game)
    end)

  add_row(rows, "profiles", "cycle", "Controller",
    function() return State.opts.controller or "Default" end,
    function(dir)
      local sys = (game and game.sys == "Wii") and "Wii" or "GameCube"
      local base = "workshop/controller/" .. sys
      local list = {}
      local h = io.popen('timeout 2 ls -1 ' .. sh.shq(base) .. " 2>/dev/null")
      if h then
        for name in h:lines() do
          if name ~= "" and name:sub(1, 1) ~= "." then list[#list + 1] = name end
        end
        h:close()
      end
      table.sort(list)
      if #list == 0 then list = { "Default" } end
      local cur = State.opts.controller or "Default"
      local idx = 1
      for i, v in ipairs(list) do if v == cur then idx = i break end end
      idx = ((idx - 1 + dir) % #list) + 1
      State.opts.controller = list[idx]
    end)

  add_row(rows, "profiles", "toggle", "Hotkeys",
    function() return State.opts.hotkeys == true end,
    function() State.opts.hotkeys = not State.opts.hotkeys end)

  -- ── overlays card
  add_row(rows, "overlays", "toggle", "FPS counter",
    function() return get_overlay("fps") end,
    function() set_overlay("fps", not get_overlay("fps")) end)
  add_row(rows, "overlays", "toggle", "VPS counter",
    function() return get_overlay("vps") end,
    function() set_overlay("vps", not get_overlay("vps")) end)
  add_row(rows, "overlays", "toggle", "Speed indicator",
    function() return get_overlay("speed") end,
    function() set_overlay("speed", not get_overlay("speed")) end)

  -- ── content card
  add_row(rows, "content", "toggle", "Graphic Mods",
    function() return get_gfxmods() end,
    function() set_gfxmods(not get_gfxmods()) end)
  add_row(rows, "content", "toggle", "HD Textures",
    function() return get_hires() end,
    function() set_hires(not get_hires()) end)
  if game and not game.virtual then
    add_row(rows, "content", "toggle", "Cheat engine",
      function() return get_cheat_engine() end,
      function() set_cheat_engine(not get_cheat_engine()) end)
  else
    add_row(rows, "content", "info", "Cheats",
      function() return "n/a" end, nil)
  end

  -- ── logging card
  add_row(rows, "logging", "toggle", "Logger",
    function() return get_logger() end,
    function() set_logger(not get_logger()) end)
  add_row(rows, "logging", "toggle", "Debugger",
    function() return get_debugger() end,
    function() set_debugger(not get_debugger()) end)
  add_row(rows, "logging", "toggle", "OSD messages",
    function() return get_osd() end,
    function() set_osd(not get_osd()) end)

  -- ── mods card (informational)
  add_row(rows, "mods", "info", "Graphic Mods",
    function() return ("%d"):format(#S.mods) end, nil)
  add_row(rows, "mods", "info", "Textures",
    function() return ("%d"):format(#S.textures) end, nil)
  add_row(rows, "mods", "info", "Cheats",
    function() return ("%d"):format(#S.cheats) end, nil)

  return rows
end

-- ══════════════════════════════════════════════════════════════
--  REPORTS (best-first)
-- ══════════════════════════════════════════════════════════════
local function build_reports()
  local compat = S.compat
  if not compat then return {} end
  local entries = compat.entries or {}
  local out = {}
  for _, e in ipairs(entries) do
    if type(e) == "table" and e.test_review then
      out[#out + 1] = {
        review      = e.test_review      or {},
        details     = e.test_details     or {},
        env         = e.test_environment or {},
        custom      = e.custom_settings  or {},
        attachments = e.attachments      or {},
      }
    end
  end
  table.sort(out, function(a, b)
    local ra = tonumber(a.review.rating) or 0
    local rb = tonumber(b.review.rating) or 0
    if ra ~= rb then return ra > rb end
    local fa = tonumber(a.review.fps_max) or 0
    local fb = tonumber(b.review.fps_max) or 0
    if fa ~= fb then return fa > fb end
    return (a.env.tester or "") < (b.env.tester or "")
  end)
  return out
end

-- ══════════════════════════════════════════════════════════════
--  LIFECYCLE
-- ══════════════════════════════════════════════════════════════
local function rebuild_cache()
  local game = S.game
  if not game then return end
  S.compat         = State.find_compat and State.find_compat(game) or nil
  S.file_info      = build_file_info(game)
  S.gamesets, S.gameset_active = scan_gamesets(game)
  S.mods           = scan_mods(game)
  S.textures       = scan_textures(game)
  S.cheats         = scan_cheats(game)
  S._overview_rows = build_overview_rows()
end

function S.enter(game)
  S.game       = game
  S.tab        = 1
  S.sel        = 1
  S.report_sel = 1
  rebuild_cache()
  State.raw_input = true
end

function S.leave() State.raw_input = false end

function S.re_enter()
  State.raw_input = true
  rebuild_cache()
end

-- ══════════════════════════════════════════════════════════════
--  LAUNCH
-- ══════════════════════════════════════════════════════════════
local function do_launch() Launcher.launch(S.game) end

local function request_launch()
  if not S.game then return end
  local compat = S.compat
  if compat and compat.playable == "NO" then
    Modal.show("Marked as UNPLAYABLE",
      string.format(
        "%s\n\nCommunity reports indicate this title does not run " ..
        "on this device.\n\nRating: %d/5 . FPS: %d-%d",
        S.game.title or "?",
        compat.rating or 0, compat.fps_min or 0, compat.fps_max or 0),
      {
        accept_label = "Launch anyway",
        cancel_label = "Cancel",
        color = {0.96, 0.77, 0.26},
        on_accept = function()
          SFX.play("menu_select")
          do_launch()
        end,
      })
    return
  end
  SFX.play("menu_select")
  do_launch()
end

-- ══════════════════════════════════════════════════════════════
--  INPUT
-- ══════════════════════════════════════════════════════════════
local function ov_rows() return S._overview_rows or {} end

local function move_overview(delta)
  local rows = ov_rows()
  local n = #rows
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.sel + delta))
  if ni ~= S.sel then S.sel = ni; SFX.play("menu_move") end
end

local function jump_card(dir)
  local rows = ov_rows()
  local n = #rows
  if n == 0 then return end
  local cur = rows[S.sel]
  if not cur then return end
  local cur_card = cur.card
  if dir > 0 then
    for i = S.sel + 1, n do
      if rows[i].card ~= cur_card then S.sel = i; SFX.play("menu_move"); return end
    end
    S.sel = n
  else
    for i = S.sel - 1, 1, -1 do
      if rows[i].card ~= cur_card then S.sel = i; SFX.play("menu_move"); return end
    end
    S.sel = 1
  end
end

local function activate_overview(dir)
  local rows = ov_rows()
  local r = rows[S.sel]
  if not r then return end
  if r.kind == "toggle" and r.set then
    SFX.play("menu_toggleoption")
    r.set()
    -- Refresh cached rows so value displays update immediately
    S._overview_rows = build_overview_rows()
  elseif r.kind == "cycle" and r.set then
    SFX.play("menu_toggleoption")
    r.set(dir or 1)
    S._overview_rows = build_overview_rows()
  end
end

function S.pad(b)
  if     b == IM.L1 then
    S.tab = (S.tab - 2) % #TABS + 1
    S.sel = 1
    SFX.play("menu_pagescroll")
  elseif b == IM.R1 then
    S.tab = (S.tab % #TABS) + 1
    S.sel = 1
    SFX.play("menu_pagescroll")
  elseif S.tab == 1 then
    if     b == IM.A then activate_overview(1)
    elseif b == IM.X then activate_overview(-1)
    elseif b == IM.Y then request_launch()
    elseif b == IM.B then State.raw_input = false; State.back() end
  else
    if b == IM.B then State.raw_input = false; State.back() end
  end
end

function S.hat(dir)
  if S.tab == 1 then
    if     dir == "up"    then move_overview(-1)
    elseif dir == "down"  then move_overview(1)
    elseif dir == "left"  then jump_card(-1)
    elseif dir == "right" then jump_card(1) end
  elseif S.tab == 3 then
    local reports = build_reports()
    if #reports == 0 then return end
    if     dir == "up"   then S.report_sel = math.max(1, S.report_sel - 1); SFX.play("menu_move")
    elseif dir == "down" then S.report_sel = math.min(#reports, S.report_sel + 1); SFX.play("menu_move") end
  end
end

function S.key(k)
  if k == "up" or k == "down" or k == "left" or k == "right" then
    return S.hat(k)
  elseif k == "return" or k == "space" then
    return S.pad(IM.A)
  elseif k == "x" then return S.pad(IM.X)
  elseif k == "y" then return S.pad(IM.Y)
  elseif k == "q" then return S.pad(IM.L1)
  elseif k == "e" then return S.pad(IM.R1)
  elseif k == "escape" then
    State.raw_input = false
    State.back()
  end
end

function S.update(_dt) end

-- ══════════════════════════════════════════════════════════════
--  DRAW — TABS
-- ══════════════════════════════════════════════════════════════
local function draw_tabs(th)
  local x = 20
  for i, t in ipairs(TABS) do
    local active = (i == S.tab)
    local c = t.color
    local font = A.font(th.font_body_bold, 11)
    love.graphics.setFont(font)
    local label_w = font:getWidth(t.label)
    local icon_size = 14
    local w = 14 + icon_size + 6 + label_w + 14

    if active then
      love.graphics.setColor(c[1]*0.35, c[2]*0.35, c[3]*0.35, 0.98)
      love.graphics.rectangle("fill", x, TABS_Y, w, TABS_H, 4, 4)
      love.graphics.setColor(c)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", x, TABS_Y, w, TABS_H, 4, 4)
      love.graphics.setLineWidth(1)
    else
      love.graphics.setColor(0.08, 0.10, 0.14, 0.85)
      love.graphics.rectangle("fill", x, TABS_Y, w, TABS_H, 4, 4)
      love.graphics.setColor(0.28, 0.30, 0.36, 0.9)
      love.graphics.rectangle("line", x, TABS_Y, w, TABS_H, 4, 4)
    end

    Icons.draw(t.icon, x + 10, TABS_Y + 6, icon_size,
      active and {1,1,1} or {0.55, 0.60, 0.70})
    love.graphics.setColor(active and {1,1,1} or th.text_dim)
    love.graphics.printf(t.label, x + 10 + icon_size + 6,
      TABS_Y + 7, label_w + 4, "left")
    x = x + w + 6
  end
end

-- ══════════════════════════════════════════════════════════════
--  DRAW — OVERVIEW BANNER + LAUNCH
-- ══════════════════════════════════════════════════════════════
local function draw_overview_banner(th)
  local game = S.game

  -- Background band
  love.graphics.setColor(0.03, 0.04, 0.08, 0.92)
  love.graphics.rectangle("fill", 0, BANNER_Y, W, BANNER_H)

  -- Cover thumbnail 92x92
  local cov_x, cov_y, cov_w, cov_h = 20, BANNER_Y + 4, 92, 92
  love.graphics.setColor(0.02, 0.02, 0.04, 0.95)
  love.graphics.rectangle("fill", cov_x, cov_y, cov_w, cov_h, 4, 4)

  local cover_path = game.path and Covers.find(game)
  local img = cover_path and A.image(cover_path)
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    local sc = math.min(cov_w / iw, cov_h / ih)
    local dw, dh = iw * sc, ih * sc
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, cov_x + (cov_w-dw)/2, cov_y + (cov_h-dh)/2, 0, sc, sc)
  else
    A.drawImage(th.empty_disc, cov_x + 10, cov_y + 10, cov_w - 20, cov_h - 20)
    -- Little hint that cover is missing
    love.graphics.setColor(0.55, 0.60, 0.72, 0.55)
    love.graphics.setFont(A.font(th.font_body, 8))
    love.graphics.printf("no cover", cov_x, cov_y + cov_h - 12, cov_w, "center")
  end
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.55)
  love.graphics.setLineWidth(1.4)
  love.graphics.rectangle("line", cov_x, cov_y, cov_w, cov_h, 4, 4)
  love.graphics.setLineWidth(1)

  -- Title + meta
  local tx = cov_x + cov_w + 16
  local title = game.title or "?"
  if #title > 34 then title = title:sub(1, 32) .. "…" end
  love.graphics.setColor(th.text)
  love.graphics.setFont(A.title_font(title, 17))
  love.graphics.print(title, tx, BANNER_Y + 6)

  local sys = game.sys or "?"
  local sc_col = (sys == "GC") and {0.55, 0.35, 0.95} or {0.20, 0.72, 0.98}
  local font = A.font(th.font_body_bold, 10)
  local sw = font:getWidth(sys) + 14
  love.graphics.setColor(sc_col[1], sc_col[2], sc_col[3], 0.9)
  love.graphics.rectangle("fill", tx, BANNER_Y + 34, sw, 16, 4, 4)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setFont(font)
  love.graphics.printf(sys, tx, BANNER_Y + 37, sw, "center")

  local id = game.id
  if id and id ~= "" then
    local id_w = font:getWidth(id) + 14
    love.graphics.setColor(0.15, 0.15, 0.20, 0.9)
    love.graphics.rectangle("fill", tx + sw + 6, BANNER_Y + 34, id_w, 16, 4, 4)
    love.graphics.setColor(0.85, 0.88, 0.95)
    love.graphics.printf(id, tx + sw + 6, BANNER_Y + 37, id_w, "center")
  end

  local compat = S.compat
  local reports_n = (compat and compat.report_count) or 0
  local fps_txt = "N/A"
  if compat and (compat.fps_min or 0) > 0 then
    fps_txt = ("%d-%d FPS"):format(compat.fps_min, compat.fps_max)
  end
  love.graphics.setColor(0.70, 0.78, 0.88)
  love.graphics.setFont(A.font(th.font_body, 11))
  love.graphics.print(("%d report(s)  .  best: %s"):format(reports_n, fps_txt),
    tx, BANNER_Y + 60)

  -- Rating ring far right
  local rx = W - 56
  local ry = BANNER_Y + BANNER_H/2
  draw_rating_ring(rx, ry, 30, (compat and compat.rating) or 0, th)
end

local function draw_launch_button(th)
  local bx, by = 20, LAUNCH_Y
  local bw, bh = W - 40, LAUNCH_H

  love.graphics.setColor(0.20, 0.60, 0.30, 0.98)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
  love.graphics.setColor(0.30, 0.85, 0.40, 0.95)
  love.graphics.setLineWidth(1.6)
  love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
  love.graphics.setLineWidth(1)

  -- Layout: [icon-triangle] LAUNCH GAME [Y badge]
  local font = A.font(th.font_body_bold, 14)
  love.graphics.setFont(font)
  local txt = "LAUNCH GAME"
  local txt_w = font:getWidth(txt)
  local tri_w = 12
  local gap = 12
  local badge_size = 22

  local total = tri_w + gap + txt_w + gap + badge_size
  local start_x = bx + (bw - total) / 2
  local cy = by + bh / 2

  -- Triangle
  GL.triangle_right(start_x + tri_w/2, cy, 6, {1,1,1}, 1)

  -- Text
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(txt, start_x + tri_w + gap, by + 8)

  -- Y badge
  BI.draw(th, "y", start_x + tri_w + gap + txt_w + gap, cy - badge_size/2, badge_size)
end

-- ══════════════════════════════════════════════════════════════
--  DRAW — OVERVIEW CARDS
-- ══════════════════════════════════════════════════════════════
local function draw_card(th, key, focused_row)
  local meta = CARD_META[key]
  local rect = CARD_RECT[key]
  if not meta or not rect then return end
  local c = meta.color

  -- Body
  love.graphics.setColor(0.04, 0.05, 0.09, 0.96)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)

  -- Header strip
  love.graphics.setColor(c[1]*0.28, c[2]*0.28, c[3]*0.28, 1)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, 22, 6, 6)
  love.graphics.setColor(c)
  love.graphics.rectangle("fill", rect.x, rect.y + 20, rect.w, 2)

  Icons.draw(meta.icon, rect.x + 6, rect.y + 4, 14, c)
  love.graphics.setFont(A.font(th.font_body_bold, 10))
  love.graphics.setColor(c)
  love.graphics.print(meta.title, rect.x + 24, rect.y + 5)

  -- Border
  love.graphics.setColor(c[1], c[2], c[3], 0.65)
  love.graphics.setLineWidth(1.4)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)
  love.graphics.setLineWidth(1)

  -- Rows
  local rows = ov_rows()
  local ry = rect.y + 28
  local row_h = 18
  for _, r in ipairs(rows) do
    if r.card == key then
      local focused = (focused_row == r)

      if focused then
        love.graphics.setColor(c[1], c[2], c[3], 0.18)
        love.graphics.rectangle("fill", rect.x + 6, ry - 1, rect.w - 12, row_h, 3, 3)
        love.graphics.setColor(c)
        love.graphics.rectangle("fill", rect.x + 6, ry - 1, 3, row_h, 1, 1)
      end

      -- Label
      love.graphics.setFont(A.font(th.font_body, 10))
      love.graphics.setColor(focused and {1,1,1} or {0.80, 0.85, 0.92})
      local label = r.label or "?"
      local max_label_w = rect.w - 90
      if love.graphics.getFont():getWidth(label) > max_label_w then
        while #label > 3 and
              love.graphics.getFont():getWidth(label .. "…") > max_label_w do
          label = label:sub(1, -2)
        end
        label = label .. "…"
      end
      love.graphics.print(label, rect.x + 14, ry + 2)

      -- Value (right-aligned)
      local ok, value = pcall(r.get)
      if not ok or value == nil then value = "—" end
      value = tostring(value)
      if #value > 14 then value = value:sub(1, 12) .. "…" end

      local vf = A.font(th.font_body_bold, 9)
      love.graphics.setFont(vf)
      local vw = vf:getWidth(value) + 12
      local vx = rect.x + rect.w - vw - 8

      if r.kind == "toggle" then
        local on = (value == "ON" or value == "true" or value == "True")
        local col = on and {0.30, 0.85, 0.40} or {0.55, 0.58, 0.68}
        love.graphics.setColor(col[1]*0.55, col[2]*0.55, col[3]*0.55, 0.98)
        love.graphics.rectangle("fill", vx, ry, vw, row_h - 2, 6, 6)
        love.graphics.setColor(col)
        love.graphics.rectangle("line", vx, ry, vw, row_h - 2, 6, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(on and "ON" or "OFF", vx, ry + 3, vw, "center")
      elseif r.kind == "cycle" then
        love.graphics.setColor(c[1]*0.35, c[2]*0.35, c[3]*0.35, 0.98)
        love.graphics.rectangle("fill", vx, ry, vw, row_h - 2, 3, 3)
        love.graphics.setColor(c)
        love.graphics.rectangle("line", vx, ry, vw, row_h - 2, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(value, vx, ry + 2, vw, "center")
      else
        love.graphics.setColor(0.35, 0.38, 0.48, 0.95)
        love.graphics.rectangle("fill", vx, ry, vw, row_h - 2, 3, 3)
        love.graphics.setColor(0.88, 0.92, 0.98)
        love.graphics.printf(value, vx, ry + 2, vw, "center")
      end

      ry = ry + row_h + 2
      if ry + row_h > rect.y + rect.h - 2 then break end
    end
  end
end

local function draw_overview(th)
  local rows = ov_rows()
  local sel_row = rows[S.sel]

  draw_overview_banner(th)
  draw_launch_button(th)

  for _, key in ipairs({ "profiles", "overlays", "content", "logging", "mods" }) do
    draw_card(th, key, sel_row)
  end
end

-- ══════════════════════════════════════════════════════════════
--  DRAW — FILES TAB
-- ══════════════════════════════════════════════════════════════
local function draw_panel(th, x, y, w, h, title, color, rows)
  love.graphics.setColor(0.03, 0.04, 0.08, 0.95)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)
  love.graphics.setColor(color[1]*0.25, color[2]*0.25, color[3]*0.25, 1)
  love.graphics.rectangle("fill", x, y, w, 20, 4, 4)
  love.graphics.setColor(color)
  love.graphics.setLineWidth(1.2)
  love.graphics.rectangle("line", x, y, w, h, 4, 4)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(A.font(th.font_body_bold, 10))
  love.graphics.print(title, x + 8, y + 4)

  local ry = y + 26
  local label_w = 82
  local mono = A.font("assets/fonts/JetBrainsMono-Regular.ttf", 9)
  for _, r in ipairs(rows) do
    local label = r[1]
    local value = r[2]
    local col   = r[3] or {0.88, 0.90, 0.95}
    love.graphics.setFont(A.font(th.font_body_bold, 9))
    love.graphics.setColor(0.55, 0.62, 0.78)
    love.graphics.print(label, x + 8, ry)
    love.graphics.setFont(mono)
    love.graphics.setColor(col)
    local v = tostring(value or "—")
    local max_w = w - label_w - 20
    if mono:getWidth(v) > max_w then
      while #v > 3 and mono:getWidth(v .. "…") > max_w do
        v = v:sub(1, -2)
      end
      v = v .. "…"
    end
    love.graphics.print(v, x + 8 + label_w, ry)
    ry = ry + 14
    if ry > y + h - 4 then break end
  end
end

local function draw_files(th)
  local info = S.file_info
  local game = S.game
  local top = CONTENT_Y

  local main_rows = {
    { "filename", info and info.name or "—" },
    { "path",     info and info.path or "—" },
    { "size",     info and ("%d bytes"):format(info.size) or "—" },
    { "magic",    info and info.magic or "—",
      (info and info.magic ~= "" and {0.96, 0.82, 0.22}) or {0.85, 0.30, 0.30} },
    { "game_id",  (game and game.id) or "—",
      (game and game.id and game.id ~= "" and {0.96, 0.82, 0.22}) or {0.55, 0.58, 0.68} },
    { "modified", info and info.mtime or "—" },
  }
  draw_panel(th, 20, top, W - 40, 116, "MAIN", {0.20, 0.72, 0.98}, main_rows)

  local res_rows = {
    { "cover",     info and (info.cover and "present" or "none") or "—",
      info and info.cover and {0.30, 0.85, 0.40} or {0.85, 0.30, 0.30} },
    { "save_state",("slot(s): %d"):format(info and info.save_count or 0),
      ((info and info.save_count or 0) > 0) and {0.30, 0.85, 0.40} or {0.55, 0.58, 0.68} },
    { "textures",  ("%d pack(s)"):format(#S.textures) },
    { "mods",      ("%d pack(s)"):format(#S.mods) },
    { "cheats",    ("%d code(s)"):format(#S.cheats) },
  }
  draw_panel(th, 20, top + 126, (W - 50) / 2, 106,
    "RESOURCES", {0.30, 0.85, 0.40}, res_rows)

  local tech_rows = {
    { "system",    (game and game.sys) or "—" },
    { "region",    (game and game.region) or "—" },
    { "extension", info and ("." .. (info.ext ~= "" and info.ext or "?")) or "—" },
    { "perms",     info and info.perms or "—" },
    { "directory", info and info.dir or "—" },
  }
  draw_panel(th, 30 + (W - 50) / 2, top + 126, (W - 50) / 2, 106,
    "TECHNICAL", {0.96, 0.77, 0.26}, tech_rows)
end

-- ══════════════════════════════════════════════════════════════
--  DRAW — REPORTS TAB
-- ══════════════════════════════════════════════════════════════
local function draw_reports(th)
  local reports = build_reports()
  local top = CONTENT_Y

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body_bold, 10))
  love.graphics.print(("%d report(s) — sorted best-first"):format(#reports),
    20, top - 14)

  if #reports == 0 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body_bold, 14))
    love.graphics.printf("No reports yet", 0, H/2 - 20, W, "center")
    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.printf(
      "This title has not been tested.\nSubmit one from Workshop > Test Report.",
      0, H/2 + 10, W, "center")
    return
  end

  local y = top
  local row_h = 26
  local body_h = 60
  for i, r in ipairs(reports) do
    local focused = (i == S.report_sel)
    local is_best = (i == 1)
    local c = rating_color(r.review.rating)
    local row_h_total = row_h + (focused and body_h or 0)

    if y + row_h_total > H - 40 then break end

    if focused then
      love.graphics.setColor(c[1], c[2], c[3], 0.15)
      love.graphics.rectangle("fill", 16, y, W - 32, row_h_total, 4, 4)
    end

    -- Star badge
    local bx = 24
    draw_star(bx + 12, y + 13, 9, c, true)
    love.graphics.setFont(A.font(th.font_body_bold, 13))
    love.graphics.setColor(c)
    love.graphics.printf(tostring(r.review.rating or 0), bx, y + 5, 24, "center")

    -- Metadata line
    local fx = bx + 34
    love.graphics.setFont(A.font(th.font_body_bold, 12))
    love.graphics.setColor(focused and {1,1,1} or th.text)
    local fps = (r.review.fps_min or 0) > 0
      and ("%d-%d FPS"):format(r.review.fps_min, r.review.fps_max)
      or "N/A FPS"
    love.graphics.print(fps, fx, y + 3)

    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.setColor(0.70, 0.78, 0.88)
    local tester = r.env.tester or "?"
    local device = r.env.device or "?"
    local rtcore = r.details.rtcore_version or "?"
    love.graphics.print(("%s  .  %s  .  %s"):format(tester, device, rtcore),
      fx + 100, y + 5)

    if is_best then
      local tag = "BEST"
      local vf = A.font(th.font_body_bold, 9)
      love.graphics.setFont(vf)
      local tw = vf:getWidth(tag) + 14
      local tx = W - 24 - tw
      love.graphics.setColor(0.30, 0.85, 0.40, 0.9)
      love.graphics.rectangle("fill", tx, y + 5, tw, 15, 7, 7)
      love.graphics.setColor(0, 0, 0, 0.9)
      love.graphics.printf(tag, tx, y + 7, tw, "center")
    end

    -- Body (only when focused)
    if focused then
      local by = y + row_h + 4
      love.graphics.setColor(0.55, 0.62, 0.78)
      love.graphics.setFont(A.font(th.font_body_bold, 9))
      love.graphics.print("NOTES", 34, by)
      love.graphics.setColor(0.88, 0.90, 0.95)
      love.graphics.setFont(A.font(th.font_body, 10))
      local notes = r.details.considerations or "(no notes)"
      local _, wrapped = love.graphics.getFont():getWrap(notes, W - 70)
      for wi, ln in ipairs(wrapped) do
        if wi > 3 then break end
        love.graphics.print(ln, 34, by + 12 + (wi - 1) * 13)
      end
    end

    y = y + row_h_total + 2
  end
end

-- ══════════════════════════════════════════════════════════════
--  MAIN DRAW
-- ══════════════════════════════════════════════════════════════
function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)

  if not S.game then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 12))
    love.graphics.printf("No game selected.", 0, H / 2, W, "center")
    return
  end

  Header.draw("GAME DETAILS", "library")
  draw_tabs(th)

  if     S.tab == 1 then draw_overview(th)
  elseif S.tab == 2 then draw_files(th)
  elseif S.tab == 3 then draw_reports(th) end

  -- Footer with procedural button badges
  local items
  if S.tab == 1 then
    items = {
      { key = "dpad", label = "Nav" },
      { key = "a",    label = "Toggle" },
      { key = "x",    label = "Cycle" },
      { key = "y",    label = "Launch" },
      { key = "l1",   label = "Prev tab" },
      { key = "r1",   label = "Next tab" },
      { key = "b",    label = "Back" },
    }
  elseif S.tab == 3 then
    items = {
      { key = "dpad", label = "Report" },
      { key = "l1",   label = "Prev tab" },
      { key = "r1",   label = "Next tab" },
      { key = "b",    label = "Back" },
    }
  else
    items = {
      { key = "l1", label = "Prev tab" },
      { key = "r1", label = "Next tab" },
      { key = "b",  label = "Back" },
    }
  end
  BI.draw_footer(th, items, W, H - 22, A.font(th.font_body, 11))

  Modal.draw()
end

return S
