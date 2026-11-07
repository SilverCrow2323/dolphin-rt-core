-- screens/settings_app.lua — DolphinUI Options (unified cyberpunk).
--
-- v0.5.0 — MERGES FrontendONE settings into this screen. All the
-- former frontendone rows (scan_recursive, cache_enabled, animations,
-- background_animated, rough_borders, show_header) now live here, in
-- their correct sections. The old frontendone screen can be removed
-- from the screens registry.
--
-- The layout uses chamfered rows, pulsing LEDs on section headers,
-- and pill-shaped values with a subtle neon glow on focus. Rows
-- are 46 px tall, section headers 30 px, and body labels are 14 pt
-- so the panel reads clearly on the 640x480 panel.

local A       = require("assets")
local SFX     = require("sfx")
local State   = require("state")
local IM      = require("input_map")
local BI      = require("ui.button_icons")
local D       = require("ui.draw")
local BG      = require("ui.bg")
local Header  = require("ui.header")
local Icons   = require("ui.icons")
local Store   = require("settings_store")
local Notify  = require("notify")
local Modal   = require("modal")

local S = {}
local W, H = 640, 480

local TOP_Y     = Header.height() + 48
local BOTTOM_Y  = H - 32
local SECTION_H = 30
local ROW_H     = 46

-- ══════════════════════════════════════════════════════════════
--  Rows
-- ══════════════════════════════════════════════════════════════
local ROWS = {
  -- ── ACTIONS ───────────────────────────────────────────────
  { kind = "section", label = "ACTIONS",
    icon = "wrench", color = {0.55, 0.35, 0.95} },
  { kind = "action", key = "rescan",
    label = "Rescan ROMs & Homebrew",
    desc  = "Refresh the library and homebrew list",
    icon  = "library", color = {0.30, 0.80, 0.60} },
  { kind = "action", key = "reload_data",
    label = "Reload data indexes",
    desc  = "Re-parse games_data.json and rtenhancerhub.json",
    icon  = "save", color = {0.20, 0.72, 0.98} },
  { kind = "action", key = "force_update",
    label = "Check for updates now",
    desc  = "Compare the app version against Rt:Enhancer",
    icon  = "update", color = {0.96, 0.77, 0.26} },

  -- ── BOOT ──────────────────────────────────────────────────
  { kind = "section", label = "BOOT",
    icon = "play", color = {0.20, 0.72, 0.98} },
  { kind = "bool", key = "boot_animation",
    label = "Boot animation",
    desc  = "Animated LÖVE startup sequence",
    section = "advanced", field = "boot_animation" },
  { kind = "bool", key = "spdw_warning",
    label = "Startup advisory",
    desc  = "SPDW Factory warning shown before the app loads",
    section = "advanced", field = "spdw_warning" },
  { kind = "bool", key = "enhancer_boot_animation",
    label = "Enhancer Dock intro",
    desc  = "Cinematic transition for Rt:Enhancer Dock",
    section = "advanced", field = "enhancer_boot_animation" },
  { kind = "bool", key = "homebrew_hub_splash",
    label = "Homebrew Hub splash",
    desc  = "Overview screen for GC / Wii / quick apps",
    section = "advanced", field = "homebrew_hub_splash" },
  { kind = "bool", key = "boot_sound",
    label = "Boot sound",
    desc  = "Play the theme's startup jingle",
    section = "sfx", field = "boot_sound" },

  -- ── ROMS ──────────────────────────────────────────────────
  { kind = "section", label = "ROMS",
    icon = "library", color = {0.55, 0.35, 0.95} },
  { kind = "action", key = "rom_paths",
    label = "ROM Paths",
    desc  = "Add / edit / remove GameCube & Wii folders",
    icon  = "library", color = {0.55, 0.35, 0.95} },
  { kind = "bool", key = "scan_recursive",
    label = "Scan subfolders",
    desc  = "Recurse into subfolders while scanning the ROM paths",
    section = "roms", field = "scan_recursive" },
  { kind = "bool", key = "cache_enabled",
    label = "Cache scan results",
    desc  = "Speed up boot by caching the last scan",
    section = "roms", field = "cache_enabled" },

  -- ── UPDATES & DATA ────────────────────────────────────────
  { kind = "section", label = "UPDATES & DATA",
    icon = "update", color = {0.96, 0.77, 0.26} },
  { kind = "bool", key = "update_check",
    label = "Check for updates at boot",
    desc  = "Reads the version from data/rtenhancerhub.json",
    section = "advanced", field = "update_check" },
  { kind = "bool", key = "data_auto_download",
    label = "Auto-download data (master)",
    desc  = "Turns the three flags below on / off together",
    section = "advanced", field = "data_auto_download" },
  { kind = "bool", key = "download_games_data",
    label = "  games_data.json",
    desc  = "Community compatibility database",
    section = "advanced", field = "download_games_data" },
  { kind = "bool", key = "download_rtenhancerhub",
    label = "  rtenhancerhub.json",
    desc  = "Store catalogue for Rt:Enhancer Dock",
    section = "advanced", field = "download_rtenhancerhub" },
  { kind = "bool", key = "download_wiitdb",
    label = "  wiitdb.txt",
    desc  = "GameTDB titles for USB Loader GX (~350 KB)",
    section = "advanced", field = "download_wiitdb" },

  -- ── INTERFACE ─────────────────────────────────────────────
  { kind = "section", label = "INTERFACE",
    icon = "ui", color = {0.30, 0.80, 0.60} },
  { kind = "bool", key = "show_header",
    label = "Show header bar",
    desc  = "Top bar with title and status icons",
    section = "ui", field = "show_header" },
  { kind = "cycle", key = "animations",
    label = "Animations",
    desc  = "Amount of motion in screens and transitions",
    section = "ui", field = "animations",
    values = { "none", "reduced", "full" } },
  { kind = "bool", key = "background_animated",
    label = "Animated background",
    desc  = "Drifting grid and particles behind every screen",
    section = "ui", field = "background_animated" },
  { kind = "bool", key = "rough_borders",
    label = "Rough borders",
    desc  = "Hand-drawn cyberpunk outlines",
    section = "ui", field = "rough_borders" },
  { kind = "bool", key = "particles",
    label = "Background particles",
    desc  = "Animated particle field in menus and library",
    section = "ui", field = "particles" },
  { kind = "bool", key = "show_fps",
    label = "FPS counter",
    desc  = "Overlay the frame rate on screen",
    section = "ui", field = "show_fps" },
  { kind = "bool", key = "flip_animation",
    label = "Theme flip animation",
    desc  = "Animated transition when switching GC ↔ Wii",
    section = "general", field = "flip_animation" },
  { kind = "bool", key = "confirm_exit",
    label = "Confirm on exit",
    desc  = "Ask before quitting the frontend",
    section = "general", field = "confirm_exit" },
  { kind = "language", key = "language",
    label = "Language",
    desc  = "Interface language (only EN available)",
    section = "general", field = "language" },

  -- ── THEME ─────────────────────────────────────────────────
  { kind = "section", label = "THEME",
    icon = "theme", color = {0.55, 0.35, 0.95} },
  { kind = "cycle", key = "theme",
    label = "Current theme",
    desc  = "GameCube (violet) or Wii (azure)",
    section = "general", field = "theme",
    values = { "gc", "wii" }, on_change = "theme" },
  { kind = "bool", key = "double_theme",
    label = "Dual-theme mode",
    desc  = "Enable SELECT to flip GC ↔ Wii from any screen",
    section = "double_theme", field = "enabled" },
  { kind = "bool", key = "flip_sound",
    label = "Theme flip sound",
    desc  = "Play a chime when flipping themes",
    section = "double_theme", field = "flip_sound" },
  { kind = "bool", key = "mirror_layout",
    label = "Mirror layout on Wii",
    desc  = "Mirror the library grid on the Wii theme",
    section = "double_theme", field = "mirror_layout" },

  -- ── AUDIO ─────────────────────────────────────────────────
  { kind = "section", label = "AUDIO",
    icon = "sfx", color = {0.96, 0.77, 0.26} },
  { kind = "bool", key = "sfx_enabled",
    label = "Sound effects",
    desc  = "Master switch for all UI sounds",
    section = "sfx", field = "enabled" },
  { kind = "range", key = "sfx_volume",
    label = "Volume",
    desc  = "0 – 100 percent",
    section = "sfx", field = "volume", min = 0, max = 100, step = 5 },
  { kind = "bool", key = "ui_sounds",
    label = "UI sounds",
    desc  = "Navigation, selection, and page ticks",
    section = "sfx", field = "ui_sounds" },
  { kind = "bool", key = "transition_sound",
    label = "Transition sound",
    desc  = "Whoosh during screen changes",
    section = "sfx", field = "transition_sound" },

  -- ── ADVANCED ──────────────────────────────────────────────
  { kind = "section", label = "ADVANCED",
    icon = "advanced", color = {0.90, 0.30, 0.30} },
  { kind = "bool", key = "debug_mode",
    label = "Debug mode",
    desc  = "Verbose logging and dev shortcuts",
    section = "advanced", field = "debug_mode" },
  { kind = "cycle", key = "log_level",
    label = "Log level",
    desc  = "Minimum severity written to data/logs",
    section = "advanced", field = "log_level",
    values = { "error", "warn", "info", "debug" } },
  { kind = "bool", key = "sfx_diagnose",
    label = "SFX diagnostics on boot",
    desc  = "Print a sound inventory to data/logs at startup",
    section = "advanced", field = "sfx_diagnose" },
}

-- ══════════════════════════════════════════════════════════════
--  Navigation
-- ══════════════════════════════════════════════════════════════
S.sel    = 1
S.scroll = 0

local function is_selectable(row)
  return row and row.kind ~= "section"
end

local function first_selectable()
  for i, r in ipairs(ROWS) do
    if is_selectable(r) then return i end
  end
  return 1
end

local function row_y(idx)
  local y = 0
  for i = 1, idx - 1 do
    y = y + (ROWS[i].kind == "section" and SECTION_H or ROW_H)
  end
  return y
end

local function total_height()
  local h = 0
  for _, r in ipairs(ROWS) do
    h = h + (r.kind == "section" and SECTION_H or ROW_H)
  end
  return h
end

local function ensure_visible()
  local vis_h = BOTTOM_Y - TOP_Y
  local y0 = row_y(S.sel)
  local h  = (ROWS[S.sel].kind == "section" and SECTION_H or ROW_H)
  if y0 < S.scroll then S.scroll = y0
  elseif y0 + h > S.scroll + vis_h then
    S.scroll = y0 + h - vis_h
  end
  local max_s = math.max(0, total_height() - vis_h)
  S.scroll = math.max(0, math.min(max_s, S.scroll))
end

local function move(delta)
  local ni = S.sel
  local step = delta > 0 and 1 or -1
  for _ = 1, math.abs(delta) do
    local cand = ni + step
    while cand >= 1 and cand <= #ROWS and not is_selectable(ROWS[cand]) do
      cand = cand + step
    end
    if cand < 1 or cand > #ROWS then break end
    ni = cand
  end
  if ni ~= S.sel then
    S.sel = ni
    SFX.play("menu_move")
    ensure_visible()
  end
end

-- ══════════════════════════════════════════════════════════════
--  Values
-- ══════════════════════════════════════════════════════════════
local function cycle_list(values, cur)
  local idx = 1
  for i, v in ipairs(values) do if v == cur then idx = i break end end
  return values[(idx % #values) + 1]
end

local function read_value(row)
  return Store.get(row.section, row.field)
end

-- ══════════════════════════════════════════════════════════════
--  Actions
-- ══════════════════════════════════════════════════════════════
local function apply_theme_now()
  local name = Store.get("general", "theme") or "gc"
  local target
  if name == "wii" then target = require("theme_wii")
  else target = require("theme_gc") end
  if target then
    State.theme_name = name
    State.theme      = target
    love.graphics.setBackgroundColor(State.theme.bg)
  end
end

local function apply_sfx_now()
  local d = Store.data()
  if d.sfx then
    SFX.muted  = (d.sfx.enabled == false)
    local vol  = tonumber(d.sfx.volume) or 70
    SFX.volume = math.max(0, math.min(1, vol / 100))
  end
end

local function apply_ui_now(field, on)
  pcall(function()
    local BGm = require("ui.bg")
    if BGm.set_particles_enabled and field == "particles" then
      BGm.set_particles_enabled(on)
    end
  end)
end

local function run_action(key)
  if key == "rom_paths" then
    State.go("rom_paths"); return
  end
  if key == "rescan" then
    if State.scan_roms     then State.scan_roms()     end
    if State.scan_homebrew then State.scan_homebrew() end
    local ok, Chips = pcall(require, "chips")
    if ok and Chips and Chips.invalidate then Chips.invalidate() end
    Notify.show("info", "Rescanning library and homebrew")
  elseif key == "reload_data" then
    if State.load_games_data   then State.load_games_data()   end
    if State.load_enhancer_hub then State.load_enhancer_hub() end
    local ok, Chips = pcall(require, "chips")
    if ok and Chips and Chips.invalidate then Chips.invalidate() end
    Notify.show("success", "Data indexes reloaded")
  elseif key == "force_update" then
    local f = io.open("data/rtenhancerhub.json", "r")
    if not f then
      Notify.show("warning", "rtenhancerhub.json not present")
      return
    end
    local c = f:read("*a"); f:close()
    local ok, decoded = pcall(require("json").decode, c)
    if not ok or type(decoded) ~= "table"
       or type(decoded.dolphinui) ~= "table" then
      Notify.show("info", "Rt:Enhancer does not publish a version yet")
      return
    end
    local latest = tostring(decoded.dolphinui.latest_version or "")
    if latest == "" then
      Notify.show("info", "Rt:Enhancer does not publish a version yet")
    else
      Notify.show("info", "Latest: v" .. latest)
    end
  end
end

local function toggle_row(row)
  if row.kind == "action" then
    run_action(row.key); return
  end
  if row.kind == "language" then
    Notify.show("info", "Only English (EN) is available in this build")
    return
  end
  if row.kind == "bool" then
    local cur = read_value(row) ~= false
    Store.set(row.section, row.field, not cur)
    Store.save()
    SFX.play("menu_toggleoption")
    if row.section == "sfx" then apply_sfx_now() end
    if row.section == "ui" then
      apply_ui_now(row.field, not cur)
      if row.field == "show_fps" then
        Notify.show("info", not cur and "FPS counter ON" or "FPS counter OFF")
      end
    end
    return
  end
  if row.kind == "cycle" then
    local cur = read_value(row)
    local nv  = cycle_list(row.values, cur)
    Store.set(row.section, row.field, nv)
    Store.save()
    SFX.play("menu_toggleoption")
    if row.on_change == "theme" then apply_theme_now() end
    return
  end
  if row.kind == "range" then
    local cur = tonumber(read_value(row)) or row.min
    local nv  = cur + row.step
    if nv > row.max then nv = row.min end
    Store.set(row.section, row.field, nv)
    Store.save()
    SFX.play("menu_toggleoption")
    if row.section == "sfx" then apply_sfx_now() end
    return
  end
end

local function range_adjust(row, dir)
  if row.kind ~= "range" then return end
  local cur = tonumber(read_value(row)) or row.min
  local nv  = cur + dir * row.step
  if nv < row.min then nv = row.min end
  if nv > row.max then nv = row.max end
  if nv ~= cur then
    Store.set(row.section, row.field, nv)
    Store.save()
    SFX.play("menu_move")
    if row.section == "sfx" then apply_sfx_now() end
  end
end

-- ══════════════════════════════════════════════════════════════
--  Lifecycle
-- ══════════════════════════════════════════════════════════════
function S.enter()
  S.sel    = first_selectable()
  S.scroll = 0
  ensure_visible()
end

function S.re_enter() ensure_visible() end

-- ══════════════════════════════════════════════════════════════
--  Input
-- ══════════════════════════════════════════════════════════════
function S.pad(b)
  local row = ROWS[S.sel]
  if not row then return end
  if b == IM.A then toggle_row(row) end
end

function S.hat(dir)
  local row = ROWS[S.sel]
  if     dir == "up"   then move(-1)
  elseif dir == "down" then move(1)
  elseif dir == "left"  and row and row.kind == "range" then
    range_adjust(row, -1)
  elseif dir == "right" and row and row.kind == "range" then
    range_adjust(row,  1)
  end
end

function S.key(k)
  local row = ROWS[S.sel]
  if not row then return end
  if     k == "up"    then move(-1)
  elseif k == "down"  then move(1)
  elseif k == "left"  and row.kind == "range" then range_adjust(row, -1)
  elseif k == "right" and row.kind == "range" then range_adjust(row,  1)
  elseif k == "return" or k == "space" then toggle_row(row) end
end

function S.update(_dt) end

-- ══════════════════════════════════════════════════════════════
--  Cyberpunk helpers
-- ══════════════════════════════════════════════════════════════
local function chamfer(mode, x, y, w, h, cut)
  cut = cut or 4
  love.graphics.polygon(mode,
    x + cut,     y,
    x + w - cut, y,
    x + w,       y + cut,
    x + w,       y + h - cut,
    x + w - cut, y + h,
    x + cut,     y + h,
    x,           y + h - cut,
    x,           y + cut)
end

local function draw_scanlines(x, y, w, h, alpha)
  love.graphics.setColor(0, 0, 0, alpha or 0.045)
  for yy = y, y + h, 3 do
    love.graphics.line(x, yy, x + w, yy)
  end
end

local function draw_flag_usa(x, y, w, h)
  local stripe_h = h / 13
  for i = 0, 12 do
    if i % 2 == 0 then love.graphics.setColor(0.70, 0.10, 0.20)
    else                 love.graphics.setColor(1.00, 1.00, 1.00) end
    love.graphics.rectangle("fill", x, y + i * stripe_h, w, stripe_h + 0.5)
  end
  local cw = w * 0.42
  local ch = stripe_h * 7
  love.graphics.setColor(0.10, 0.18, 0.55)
  love.graphics.rectangle("fill", x, y, cw, ch)

  love.graphics.setColor(1, 1, 1)
  local rows, cols = 5, 6
  local cw2, ch2 = cw / cols, ch / rows
  local r = math.max(0.6, h * 0.022)
  for rr = 0, rows - 1 do
    for cc = 0, cols - 1 do
      local off = (rr % 2 == 0) and 0 or (cw2 * 0.5)
      local sx = x + off + (cc + 0.5) * cw2
      local sy = y + (rr + 0.5) * ch2
      if sx < x + cw - 1 then
        love.graphics.circle("fill", sx, sy, r)
      end
    end
  end
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
end

-- ══════════════════════════════════════════════════════════════
--  Rendering
-- ══════════════════════════════════════════════════════════════
local function fmt_value(row, v)
  if row.kind == "bool" then return (v ~= false) and "ON" or "OFF" end
  if row.kind == "cycle" then return tostring(v or "?") end
  if row.kind == "range" then return tostring(tonumber(v) or 0) end
  return ""
end

local function draw_section_header(row, y, th)
  local x, w = 20, W - 40
  local t = State.t_ui or 0
  local pulse = 0.5 + 0.5 * math.sin(t * 2 + row.label:len())

  -- LED dot
  love.graphics.setColor(row.color[1], row.color[2], row.color[3], 0.30 + pulse * 0.40)
  love.graphics.circle("fill", x + 8, y + SECTION_H/2, 5)
  love.graphics.setColor(row.color[1], row.color[2], row.color[3], 1)
  love.graphics.circle("fill", x + 8, y + SECTION_H/2, 2.5)

  -- Label
  love.graphics.setColor(row.color[1], row.color[2], row.color[3])
  love.graphics.setFont(A.font(th.font_body_bold, 13))
  love.graphics.print(row.label, x + 22, y + 6)

  -- Hairline
  local lx = x + 22 + love.graphics.getFont():getWidth(row.label) + 12
  local lw = x + w - lx
  if lw > 8 then
    love.graphics.setColor(row.color[1], row.color[2], row.color[3], 0.20)
    love.graphics.line(lx, y + SECTION_H/2, lx + lw, y + SECTION_H/2)
    -- Spark
    love.graphics.setColor(row.color[1], row.color[2], row.color[3], 0.55)
    love.graphics.rectangle("fill", lx, y + SECTION_H/2 - 1, 4, 2)
  end
end

local function draw_row(row, y, focused, th)
  local x, w, h = 20, W - 40, ROW_H
  local t = State.t_ui or 0

  -- Focus: dark cyan-tinted plate with chamfered corners + pulse
  if focused then
    local pulse = 0.5 + 0.5 * math.sin(t * 4)
    love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.10 + pulse * 0.06)
    chamfer("fill", x, y + 2, w, h - 4, 6)
    love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.85)
    love.graphics.setLineWidth(1.6)
    chamfer("line", x, y + 2, w, h - 4, 6)
    love.graphics.setLineWidth(1)
    -- Left rail
    love.graphics.setColor(th.focus)
    love.graphics.rectangle("fill", x, y + 4, 3, h - 8, 1, 1)
  end

  -- Icon
  local ic_col = row.color or th.text_dim
  Icons.draw(row.icon or "settings",
    x + 12, y + (h - 22) / 2, 22,
    focused and th.focus or ic_col)

  local tx = x + 46

  -- Label
  love.graphics.setColor(focused and {1,1,1} or th.text)
  love.graphics.setFont(A.font(th.font_body_bold, 14))
  love.graphics.print(row.label, tx, y + 6)

  -- Description
  if row.desc and row.desc ~= "" then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 11))
    local desc = row.desc
    if #desc > 62 then desc = desc:sub(1, 60) .. "…" end
    love.graphics.print(desc, tx, y + 26)
  end

  -- Right-side indicator
  local vx_right = x + w - 12

  if row.kind == "bool" then
    local v = read_value(row)
    local on = (v ~= false)
    local col = on and {0.30, 0.80, 0.40} or {0.55, 0.55, 0.62}
    local pill_w = 58
    local px = vx_right - pill_w
    local py = y + (h - 22) / 2

    love.graphics.setColor(col[1]*0.18, col[2]*0.18, col[3]*0.18, 1)
    chamfer("fill", px, py, pill_w, 22, 5)
    love.graphics.setColor(col)
    love.graphics.setLineWidth(1.6)
    chamfer("line", px, py, pill_w, 22, 5)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.setColor(col)
    love.graphics.printf(on and "ON" or "OFF", px, py + 5, pill_w, "center")

    if on then
      local pulse = 0.5 + 0.5 * math.sin(t * 5)
      love.graphics.setColor(col[1], col[2], col[3], 0.25 + pulse * 0.35)
      love.graphics.circle("fill", px + 10, py + 11, 3)
    end

  elseif row.kind == "cycle" then
    local v = tostring(read_value(row) or "?")
    local font = A.font(th.font_body_bold, 11)
    love.graphics.setFont(font)
    local vw = font:getWidth(v) + 22
    local px = vx_right - vw
    local py = y + (h - 22) / 2
    love.graphics.setColor(th.focus[1]*0.30, th.focus[2]*0.30,
      th.focus[3]*0.30, 0.95)
    chamfer("fill", px, py, vw, 22, 6)
    love.graphics.setColor(th.focus)
    chamfer("line", px, py, vw, 22, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(v, px, py + 5, vw, "center")

  elseif row.kind == "range" then
    local v = tostring(tonumber(read_value(row)) or 0)
    local font = A.font(th.font_body_bold, 12)
    love.graphics.setFont(font)
    local vw = font:getWidth(v) + 26
    local px = vx_right - vw
    local py = y + (h - 22) / 2
    love.graphics.setColor(0.10, 0.10, 0.14, 0.9)
    chamfer("fill", px, py, vw, 22, 5)
    love.graphics.setColor(th.focus)
    chamfer("line", px, py, vw, 22, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(v, px, py + 5, vw, "center")
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print("← →", px - 32, py + 6)

  elseif row.kind == "language" then
    local v = tostring(read_value(row) or "en"):upper()
    local font = A.font(th.font_body_bold, 11)
    love.graphics.setFont(font)
    local vw = font:getWidth(v) + 50
    local px = vx_right - vw
    local py = y + (h - 22) / 2
    love.graphics.setColor(th.focus[1]*0.25, th.focus[2]*0.25,
      th.focus[3]*0.25, 0.95)
    chamfer("fill", px, py, vw, 22, 6)
    love.graphics.setColor(th.focus)
    chamfer("line", px, py, vw, 22, 6)

    draw_flag_usa(px + 8, py + 3, 26, 16)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(v, px + 38, py + 5, vw - 42, "center")

  elseif row.kind == "action" then
    local ax = vx_right - 10
    local ay = y + h / 2
    local pulse = 0.5 + 0.5 * math.sin(t * 4)
    local c = row.color or th.focus
    love.graphics.setColor(c[1], c[2], c[3], 0.55 + pulse * 0.35)
    love.graphics.polygon("fill",
      ax,     ay - 6,
      ax + 8, ay,
      ax,     ay + 6)
  end
end

local function draw_scrollbar(th)
  local vis_h = BOTTOM_Y - TOP_Y
  local total = total_height()
  if total <= vis_h then return end
  local rail_x = W - 6
  love.graphics.setColor(0.30, 0.30, 0.35, 0.55)
  love.graphics.rectangle("fill", rail_x, TOP_Y, 3, vis_h, 1, 1)
  local ratio = vis_h / total
  local bar_h = math.max(20, vis_h * ratio)
  local span  = total - vis_h
  local bar_y = TOP_Y + (span > 0 and (S.scroll / span) * (vis_h - bar_h) or 0)
  love.graphics.setColor(th.accent)
  love.graphics.rectangle("fill", rail_x, bar_y, 3, bar_h, 1, 1)
end

function S.draw()
  local th = State.theme
  BG.draw_nexus(W, H, love.timer.getDelta(), th.accent)
  Header.draw("DOLPHINUI OPTIONS", "settings")

  -- Top toolbar strip (theme + hints)
  local y_bar = Header.height() + 4
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", 0, y_bar, W, 30)
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
  love.graphics.rectangle("fill", 0, y_bar + 29, W, 1)

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.print("THEME:", 16, y_bar + 9)
  love.graphics.setColor(th.focus)
  love.graphics.setFont(A.font(th.font_body_bold, 12))
  love.graphics.print((State.theme_name or "gc"):upper(), 68, y_bar + 8)

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 10))
  love.graphics.printf("[SELECT] Flip theme from any screen",
    0, y_bar + 10, W - 16, "right")

  -- Content
  love.graphics.setScissor(0, TOP_Y, W, BOTTOM_Y - TOP_Y)
  local y = TOP_Y - S.scroll
  for i, row in ipairs(ROWS) do
    local h = (row.kind == "section") and SECTION_H or ROW_H
    if y + h > TOP_Y - 80 and y < BOTTOM_Y + 80 then
      if row.kind == "section" then
        draw_section_header(row, y, th)
      else
        draw_row(row, y, i == S.sel, th)
      end
    end
    y = y + h
  end
  love.graphics.setScissor()

  -- Panel scanlines (subtle)
  draw_scanlines(0, TOP_Y, W, BOTTOM_Y - TOP_Y, 0.035)

  draw_scrollbar(th)

  BI.draw_footer(th, {
    { key = "dpad", label = "Navigate" },
    { key = "a",    label = "Toggle"   },
    { key = "b",    label = "Back"     },
  }, W, H - 22, A.font(th.font_body, 12))
end

return S