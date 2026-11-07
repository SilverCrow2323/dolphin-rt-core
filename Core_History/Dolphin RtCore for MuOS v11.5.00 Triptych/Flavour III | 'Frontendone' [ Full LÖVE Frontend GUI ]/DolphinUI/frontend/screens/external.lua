-- screens/external.lua — External Dolphin Rt:Core hub.
--
-- Three tabs, cycled with L1 / R1:
--   1. STATUS   — version, active profile, assign registry, live
--                 values from Config/Dolphin.ini + GFX.ini, presence
--                 of GC BIOS / Wii NAND.
--   2. PROFILES — list Config/*.ini.<name> variants. Apply with
--                 [A] (backup + copy). [X] shows a diff between live
--                 and the variant. Current profile detected by md5.
--   3. TOOLS    — Bash Arsenal browser. Navigate the task tree under
--                 /opt/muos/share/task/Dolphin Rt:Core/ and run
--                 scripts. Destructive scripts require confirmation.
--
-- ── v0.5.2 — vertical config files list ─────────────────────
--   * The "CONFIG FILES" band used to be a horizontal grid of N
--     equal-width cells. With longer filenames (WiimoteNew.ini,
--     GCPadNew.ini), the labels overlapped at 640px width. It's
--     now a vertical list: one row per file, name on the left,
--     ✓/✗ on the right. No overlap possible.
--   * All strings translated to English.
--
-- State.raw_input is held true for the entire lifetime of this screen
-- so B reaches S.pad and navigates up one directory (or exits the
-- screen at the root), instead of popping the history twice.

local A      = require("assets")
local SFX    = require("sfx")
local State  = require("state")
local IM     = require("input_map")
local D      = require("ui.draw")
local BG     = require("ui.bg")
local Header = require("ui.header")
local Icons  = require("ui.icons")
local BI     = require("ui.button_icons")
local Modal  = require("modal")
local Notify = require("notify")
local Ext    = require("external")
local TR     = require("task_runner")

local S = {}
local W, H = 640, 480

-- ══════════════════════════════════════════════════════════════
--  Tabs
-- ══════════════════════════════════════════════════════════════
local TABS = {
  { key = "status",   label = "STATUS",   icon = "info",     color = {0.20, 0.72, 0.98} },
  { key = "profiles", label = "PROFILES", icon = "profile",  color = {0.55, 0.35, 0.95} },
  { key = "tools",    label = "TOOLS",    icon = "advanced", color = {0.96, 0.77, 0.26} },
}

S.tab       = 1
S.tab_anim  = 0

S._status = nil
S._assign = nil
S._profiles_cfg = nil
S._current_cfg = "custom"

S.prof_sel = 1

S.tools_path = nil
S.tools_list = {}
S.tools_sel  = 1
S.tools_scroll = 0

S.confirm = nil

-- ── shell/path helpers ──────────────────────────────────────
local function shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function parent_of(p)
  if not p or p == "" then return p end
  local par = p:match("^(.+)/[^/]+$")
  return par or p
end

local function rel_to(base, p)
  if not base or not p then return p end
  if p == base then return "." end
  local prefix = base .. "/"
  if p:sub(1, #prefix) == prefix then
    return p:sub(#prefix + 1)
  end
  return p
end

-- ══════════════════════════════════════════════════════════════
--  Data refresh
-- ══════════════════════════════════════════════════════════════
local function refresh_all()
  S._status       = Ext.read_status()
  S._assign       = Ext.read_assign_info()
  S._profiles_cfg = Ext.list_config_profiles()
  S._current_cfg  = Ext.current_config_profile()
end

local function reload_tools()
  local p = S.tools_path or Ext.ROOT_TASKS
  S.tools_path = p
  S.tools_list = Ext.list_dir(p)
  if #S.tools_list == 0 then
    S.tools_sel = 1
  else
    S.tools_sel = math.max(1, math.min(#S.tools_list, S.tools_sel))
  end
  S.tools_scroll = 0
end

-- ══════════════════════════════════════════════════════════════
--  Lifecycle
-- ══════════════════════════════════════════════════════════════
function S.enter()
  S.tab = 1
  S.tab_anim = 0
  S.prof_sel = 1
  S.tools_path = Ext.ROOT_TASKS
  S.tools_sel = 1
  S.tools_scroll = 0
  S.confirm = nil
  refresh_all()
  reload_tools()
  State.raw_input = true
end

function S.leave()
  State.raw_input = false
end

function S.re_enter()
  State.raw_input = true
  refresh_all()
  reload_tools()
end

function S.update(dt)
  S.tab_anim = math.min(1, (S.tab_anim or 0) + dt * 4)
end

-- ══════════════════════════════════════════════════════════════
--  Navigation
-- ══════════════════════════════════════════════════════════════
local function change_tab(delta)
  S.tab = ((S.tab - 1 + delta) % #TABS) + 1
  S.tab_anim = 0
  SFX.play("menu_pagescroll")
end

local function move_prof(delta)
  local n = #(S._profiles_cfg or {})
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.prof_sel + delta))
  if ni ~= S.prof_sel then
    S.prof_sel = ni
    SFX.play("menu_move")
  end
end

local function move_tools(delta)
  local n = #S.tools_list
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.tools_sel + delta))
  if ni ~= S.tools_sel then
    S.tools_sel = ni
    SFX.play("menu_move")
    local row_h = 26
    local top = 128
    local bottom = H - 34
    local vis_h = bottom - top
    local y0 = (S.tools_sel - 1) * row_h
    if y0 < S.tools_scroll then
      S.tools_scroll = y0
    elseif y0 + row_h > S.tools_scroll + vis_h then
      S.tools_scroll = y0 + row_h - vis_h
    end
  end
end

-- ══════════════════════════════════════════════════════════════
--  Actions
-- ══════════════════════════════════════════════════════════════
local DESTRUCTIVE = {
  ["Uninstall Dolphin.sh"]    = "This will REMOVE the external Dolphin core.\nYou will need to reinstall it from scratch.",
  ["Clear All Mods.sh"]       = "This will delete every installed Graphic Mod.",
  ["Rollback Last Apply.sh"]  = "This will revert the last profile apply.",
}

local function run_script(entry)
  if not entry then return end

  local msg = DESTRUCTIVE[entry.name]
  if msg then
    S.confirm = {
      title  = "Confirm: " .. entry.name,
      body   = msg .. "\n\nProceed?",
      action = function()
        SFX.play("menu_select")
        TR.run(entry.path)
      end,
    }
    return
  end

  SFX.play("menu_select")
  TR.run(entry.path)
end

local function tools_activate()
  local e = S.tools_list[S.tools_sel]
  if not e then return end
  if e.is_dir then
    S.tools_path = e.path
    S.tools_sel = 1
    S.tools_scroll = 0
    reload_tools()
    SFX.play("menu_select")
    return
  end
  if e.is_script or e.is_python then
    run_script(e)
    return
  end
  if e.is_text then
    local content = Ext.read(e.path)
    if content then
      local snippet = content:sub(1, 240):gsub("\n", " ")
      Notify.show("info", e.name .. ": " .. snippet, 5.0)
    end
    SFX.play("menu_select")
    return
  end
  Notify.show("warning", "Not runnable: " .. e.name)
end

local function tools_back()
  if S.tools_path and S.tools_path ~= Ext.ROOT_TASKS then
    S.tools_path = parent_of(S.tools_path)
    S.tools_sel = 1
    S.tools_scroll = 0
    reload_tools()
    SFX.play("menu_back")
    return
  end
  State.raw_input = false
  State.back()
end

local function apply_current_profile()
  local prof = (S._profiles_cfg or {})[S.prof_sel]
  if not prof then return end
  if prof.name == S._current_cfg then
    Notify.show("info", "Already active: " .. prof.name)
    return
  end
  local ok, reason = Ext.apply_config_profile(prof.name)
  if ok then
    Notify.show("success", "Applied: " .. prof.name .. "  (backup in " ..
      (reason:match("([^/]+)$") or "?") .. ")", 4.0)
    refresh_all()
    SFX.play("menu_toggleoption")
  else
    Notify.show("error", "Failed: " .. tostring(reason))
    SFX.play("menu_back")
  end
end

local function view_profile_diff()
  local prof = (S._profiles_cfg or {})[S.prof_sel]
  if not prof then return end
  local dir = Ext.ROOT_EMU .. "/Config"
  local lines = {}

  local function diff_pair(live, variant)
    local f1 = io.open(live, "r")
    local f2 = io.open(variant, "r")
    if not f1 and not f2 then return end
    local live_set = {}
    if f1 then
      for line in f1:lines() do live_set[line] = true end
      f1:close()
    end
    local var_set = {}
    if f2 then
      for line in f2:lines() do var_set[line] = true end
      f2:close()
    end
    local name = live:match("([^/]+)$")
    table.insert(lines, "── " .. name .. " ──")
    local diff = 0
    for k in pairs(var_set) do
      if not live_set[k] and k:match("%S") then
        diff = diff + 1
        if diff <= 8 then table.insert(lines, "+ " .. k) end
      end
    end
    for k in pairs(live_set) do
      if not var_set[k] and k:match("%S") then
        diff = diff + 1
        if diff <= 8 then table.insert(lines, "- " .. k) end
      end
    end
    if diff == 0 then
      table.insert(lines, "(identical)")
    end
  end

  if prof.has_dolphin then
    diff_pair(dir .. "/Dolphin.ini", dir .. "/Dolphin.ini." .. prof.name)
  end
  if prof.has_gfx then
    diff_pair(dir .. "/GFX.ini", dir .. "/GFX.ini." .. prof.name)
  end

  Modal.show("Variant: " .. prof.name,
    table.concat(lines, "\n"), {
      accept_label = "OK",
    })
end

-- ══════════════════════════════════════════════════════════════
--  Input
-- ══════════════════════════════════════════════════════════════
function S.pad(b)
  if S.confirm then
    if b == IM.A then
      local fn = S.confirm.action
      S.confirm = nil
      if fn then fn() end
    elseif b == IM.B then
      S.confirm = nil
      SFX.play("menu_back")
    end
    return
  end

  if b == IM.L1 then change_tab(-1); return end
  if b == IM.R1 then change_tab(1);  return end

  if S.tab == 1 then
    if b == IM.Y then
      refresh_all()
      Notify.show("success", "Status refreshed")
      SFX.play("menu_toggleoption")
    elseif b == IM.B then
      State.raw_input = false
      State.back()
    end

  elseif S.tab == 2 then
    if b == IM.A then
      apply_current_profile()
    elseif b == IM.X then
      view_profile_diff()
    elseif b == IM.Y then
      refresh_all()
      Notify.show("info", "Profiles refreshed")
      SFX.play("menu_toggleoption")
    elseif b == IM.B then
      State.raw_input = false
      State.back()
    end

  elseif S.tab == 3 then
    if b == IM.A then
      tools_activate()
    elseif b == IM.B then
      tools_back()
    end
  end
end

function S.hat(dir)
  if S.confirm then return end
  if S.tab == 2 then
    if     dir == "up"   then move_prof(-1)
    elseif dir == "down" then move_prof(1) end
  elseif S.tab == 3 then
    if     dir == "up"   then move_tools(-1)
    elseif dir == "down" then move_tools(1) end
  end
end

function S.key(k)
  if S.confirm then
    if k == "return" or k == "space" then
      local fn = S.confirm.action
      S.confirm = nil
      if fn then fn() end
    elseif k == "escape" then
      S.confirm = nil
    end
    return
  end
  if     k == "q" then change_tab(-1)
  elseif k == "e" then change_tab(1)
  elseif k == "up"    then S.hat("up")
  elseif k == "down"  then S.hat("down")
  elseif k == "return" or k == "space" then S.pad(IM.A)
  elseif k == "x" then S.pad(IM.X)
  elseif k == "y" then S.pad(IM.Y)
  elseif k == "backspace" and S.tab == 3 then tools_back()
  elseif k == "escape" then
    State.raw_input = false
    State.back()
  end
end

-- ══════════════════════════════════════════════════════════════
--  Rendering: header + tab bar
-- ══════════════════════════════════════════════════════════════
local function draw_header(_th)
  Header.draw("EXTERNAL CORE", "external")
end

local function draw_tab_bar(th)
  local y = Header.height() + 2
  local x = 12
  for i, t in ipairs(TABS) do
    local active = (i == S.tab)
    local c = t.color
    local font = A.font(th.font_body_bold, 11)
    love.graphics.setFont(font)
    local label_w = font:getWidth(t.label)
    local icon_size = 14
    local w = 12 + icon_size + 6 + label_w + 12
    local h = 24

    if active then
      love.graphics.setColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 0.95)
      love.graphics.rectangle("fill", x, y, w, h, 4, 4)
      local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 4)
      love.graphics.setColor(c[1], c[2], c[3], 0.30 + pulse * 0.35)
      love.graphics.setLineWidth(1.6)
      love.graphics.rectangle("line", x - 1, y - 1, w + 2, h + 2, 5, 5)
      love.graphics.setLineWidth(1)
      love.graphics.setColor(c)
      love.graphics.rectangle("line", x, y, w, h, 4, 4)
    else
      love.graphics.setColor(0.08, 0.10, 0.14, 0.85)
      love.graphics.rectangle("fill", x, y, w, h, 4, 4)
      love.graphics.setColor(0.28, 0.30, 0.36, 0.9)
      love.graphics.rectangle("line", x, y, w, h, 4, 4)
    end

    Icons.draw(t.icon, x + 8, y + 5, icon_size,
      active and {1, 1, 1} or {0.55, 0.60, 0.70})

    love.graphics.setColor(active and {1, 1, 1} or th.text_dim)
    love.graphics.printf(t.label, x + 8 + icon_size + 6, y + 7,
      label_w + 4, "left")

    x = x + w + 6
  end
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
  love.graphics.rectangle("fill", 0, y + 26, W, 1)
end

-- ══════════════════════════════════════════════════════════════
--  STATUS tab
-- ══════════════════════════════════════════════════════════════
local function card(th, x, y, w, h, color, title, icon_key)
  love.graphics.setColor(0.05, 0.06, 0.10, 0.95)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)

  love.graphics.setColor(color[1] * 0.35, color[2] * 0.35, color[3] * 0.35, 1)
  love.graphics.rectangle("fill", x, y, w, 20, 4, 4)

  love.graphics.setColor(color)
  D.rough_rect(x, y, w, h,
    { jitter = 0.7, thickness = 1.4, seed = (x + y) % 100 })

  if icon_key then
    Icons.draw(icon_key, x + 6, y + 3, 14, {1, 1, 1})
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print(title, x + 24, y + 4)
  else
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print(title, x + 8, y + 4)
  end
end

local function draw_status(th)
  local st = S._status or {}
  local as = S._assign or { gc = {}, wii = {} }

  local y = 96
  local cw = (W - 30) / 2

  -- Version
  card(th, 12, y, cw, 68, {0.20, 0.72, 0.98}, "VERSION", "info")
  love.graphics.setColor(0.85, 0.92, 1.0)
  love.graphics.setFont(A.font(th.font_body_bold, 16))
  love.graphics.printf(
    (st.version or "External Rt:Core"):sub(1, 26),
    20, y + 30, cw - 16, "center")
  love.graphics.setColor(0.55, 0.65, 0.78)
  love.graphics.setFont(A.font(th.font_body, 9))
  love.graphics.printf(Ext.ROOT_EMU, 20, y + 52, cw - 16, "center")

  -- Active config variant
  local cprof = S._current_cfg or "custom"
  local pcol = (cprof == "custom") and {0.55, 0.60, 0.72} or {0.55, 0.35, 0.95}
  card(th, 18 + cw, y, cw, 68, pcol, "ACTIVE CONFIG VARIANT", "profile")
  love.graphics.setColor(pcol)
  love.graphics.setFont(A.font(th.font_body_bold, 18))
  love.graphics.printf(cprof:upper(), 26 + cw, y + 28, cw - 16, "center")
  love.graphics.setColor(0.55, 0.65, 0.78)
  love.graphics.setFont(A.font(th.font_body, 9))
  love.graphics.printf("Config/Dolphin.ini + GFX.ini",
    26 + cw, y + 52, cw - 16, "center")

  y = y + 76

  -- Assign registry
  card(th, 12, y, W - 24, 66, {0.96, 0.77, 0.26},
    "MUOS REGISTRY (Content Explorer)", "settings")
  local ry = y + 26
  local function assign_line(sys, info)
    love.graphics.setColor(info.name and {0.85, 0.92, 1.0} or {0.55, 0.60, 0.72})
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print(sys, 22, ry)
    love.graphics.setColor(info.name and {1, 1, 1} or {0.55, 0.60, 0.72})
    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.print((info.name or "not registered"), 130, ry)
    love.graphics.setColor(0.55, 0.65, 0.78)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.print(
      ("default: %s   catalogue: %s   profiles: %d"):format(
        info.default or "—", info.catalogue or "—", info.profiles or 0),
      130, ry + 12)
    ry = ry + 22
  end
  assign_line("GameCube", as.gc or {})
  assign_line("Wii",      as.wii or {})

  y = y + 74

  -- Config files presence — VERTICAL LIST
  -- (was a horizontal grid, names overlapped on 640px)
  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body_bold, 10))
  love.graphics.print("CONFIG FILES", 20, y)
  y = y + 14

  local files = {
    { "Dolphin.ini",    Ext.exists(Ext.ROOT_EMU .. "/Config/Dolphin.ini") },
    { "GFX.ini",        Ext.exists(Ext.ROOT_EMU .. "/Config/GFX.ini")     },
    { "GCPadNew.ini",   Ext.exists(Ext.ROOT_EMU .. "/Config/GCPadNew.ini") },
    { "WiimoteNew.ini", Ext.exists(Ext.ROOT_EMU .. "/Config/WiimoteNew.ini") },
    { "Hotkeys.ini",    Ext.exists(Ext.ROOT_EMU .. "/Config/Hotkeys.ini") },
    { "Logger.ini",     Ext.exists(Ext.ROOT_EMU .. "/Config/Logger.ini")  },
    { "GC BIOS",        st.gc_bios and (st.gc_bios.USA or st.gc_bios.EUR or st.gc_bios.JAP) or false },
    { "Wii NAND",       st.wii_nand },
  }

  -- Two columns of 4 rows each. Each row is a thin band: name on the
  -- left, ✓/✗ on the right. No overlap possible.
  local list_font = A.font(th.font_body_bold, 9)
  love.graphics.setFont(list_font)
  local col_w = (W - 40) / 2
  local row_h = 18
  local list_y = y
  for i, f in ipairs(files) do
    local col = math.floor((i - 1) / 4)
    local row = (i - 1) % 4
    local fx = 20 + col * col_w
    local fy = list_y + row * row_h
    local on = f[2]
    local col_c = on and {0.30, 0.85, 0.40} or {0.90, 0.30, 0.30}

    love.graphics.setColor(col_c[1] * 0.18, col_c[2] * 0.18,
      col_c[3] * 0.18, 0.95)
    love.graphics.rectangle("fill", fx, fy, col_w - 8, row_h - 2, 3, 3)
    love.graphics.setColor(col_c)
    love.graphics.rectangle("line", fx, fy, col_w - 8, row_h - 2, 3, 3)

    love.graphics.setColor(col_c[1], col_c[2], col_c[3], 0.95)
    love.graphics.printf(f[1], fx + 6, fy + 3, col_w - 30, "left")

    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.setColor(col_c)
    love.graphics.printf(on and "✓" or "✗", fx, fy + 2, col_w - 14, "right")
    love.graphics.setFont(list_font)
  end
  y = y + row_h * 4 + 6

  -- Live values (2-column grid)
  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body_bold, 10))
  love.graphics.print("LIVE VALUES (Config/Dolphin.ini + GFX.ini)", 20, y)
  y = y + 14

  local values = {
    { "CPUThread",   st.dual_core   },
    { "CPUCore",     st.cpu_core    },
    { "Overclock",   st.overclock   },
    { "Fastmem",     st.fastmem     },
    { "MMU",         st.mmu         },
    { "DSPHLE",      st.dsp_hle     },
    { "Backend",     st.backend     },
    { "InternalRes", st.resolution  },
    { "MSAA",        st.msaa        },
    { "ShaderMode",  st.shader_mode },
    { "VSync",       st.vsync       },
    { "VISkip",      st.viskip      },
    { "DisableFog",  st.disable_fog },
    { "EFBtoTexture",st.efb_to_tex  },
    { "OSD",         st.osd         },
    { "ExtFPSInfo",  st.ext_fps     },
  }
  local col_w2 = (W - 40) / 2
  for i, v in ipairs(values) do
    local col = math.floor((i - 1) / 8)
    local row = (i - 1) % 8
    local x   = 20 + col * col_w2
    local yy  = y + row * 17
    love.graphics.setColor(0.60, 0.65, 0.78)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print(v[1], x, yy)
    love.graphics.setColor((v[2] ~= nil and v[2] ~= "") and {1,1,1} or {0.55,0.60,0.72})
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print(tostring(v[2] or "—"), x + 90, yy)
  end
end

-- ══════════════════════════════════════════════════════════════
--  PROFILES tab
-- ══════════════════════════════════════════════════════════════
local function draw_profiles(th)
  local list = S._profiles_cfg or {}
  if #list == 0 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 12))
    love.graphics.printf(
      "No config variants found in\n" .. Ext.ROOT_EMU .. "/Config/",
      0, 220, W, "center")
    return
  end

  local y = 100
  local rh = 42
  for i, p in ipairs(list) do
    local focused = (i == S.prof_sel)
    local active  = (p.name == S._current_cfg)
    local c = active and {0.30, 0.85, 0.40} or {0.55, 0.35, 0.95}
    if focused then D.glow(20 + (W - 40) / 2, y + rh / 2, 40, c, 0.7) end

    love.graphics.setColor(
      focused and c[1]*0.28 or c[1]*0.10,
      focused and c[2]*0.28 or c[2]*0.10,
      focused and c[3]*0.28 or c[3]*0.10, 0.95)
    love.graphics.rectangle("fill", 20, y, W - 40, rh - 2, 4, 4)

    love.graphics.setColor(c[1], c[2], c[3], focused and 1 or 0.65)
    love.graphics.rectangle("fill", 20, y, 4, rh - 2)

    love.graphics.setColor(c)
    D.rough_rect(20, y, W - 40, rh - 2,
      { jitter = focused and 1.1 or 0.7,
        thickness = focused and 2.2 or 1.3, seed = i * 11 })

    Icons.draw("profile", 34, y + 11, 20, c)

    love.graphics.setColor(focused and {1,1,1} or th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 13))
    love.graphics.print(p.name, 62, y + 4)

    local px = 62
    local py = y + 23
    local pill_font = A.font(th.font_body_bold, 8)
    love.graphics.setFont(pill_font)
    local function pill(label, on, col)
      local w = pill_font:getWidth(label) + 12
      love.graphics.setColor(col[1]*0.4, col[2]*0.4, col[3]*0.4, on and 0.95 or 0.35)
      love.graphics.rectangle("fill", px, py, w, 13, 6, 6)
      love.graphics.setColor(on and {1,1,1} or {0.60, 0.60, 0.68})
      love.graphics.printf(label, px, py + 1, w, "center")
      px = px + w + 4
    end
    pill("Dolphin.ini", p.has_dolphin, {0.20, 0.72, 0.98})
    pill("GFX.ini",     p.has_gfx,     {0.96, 0.77, 0.26})

    if active then
      local bf = A.font(th.font_body_bold, 9)
      local badge = "● ACTIVE"
      local bw = bf:getWidth(badge) + 12
      love.graphics.setColor(0.30, 0.85, 0.40, 0.9)
      love.graphics.rectangle("fill", W - 20 - bw - 8, y + 12, bw, 16, 8, 8)
      love.graphics.setColor(0, 0, 0, 0.9)
      love.graphics.setFont(bf)
      love.graphics.printf(badge, W - 20 - bw - 8, y + 14, bw, "center")
    end

    y = y + rh
  end

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 9))
  love.graphics.printf("Backups in Config/.backup_<timestamp>/",
    0, H - 44, W, "center")
end

-- ══════════════════════════════════════════════════════════════
--  TOOLS tab
-- ══════════════════════════════════════════════════════════════
local function draw_breadcrumb(th)
  local y = 96
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", 12, y, W - 24, 22, 3, 3)
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.55)
  love.graphics.rectangle("line", 12, y, W - 24, 22, 3, 3)

  love.graphics.setColor(th.accent)
  love.graphics.setFont(A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10))
  local rel = rel_to(Ext.ROOT_TASKS, S.tools_path or Ext.ROOT_TASKS)
  if rel == "" or rel == "." then rel = "/" end
  love.graphics.print("▶ Dolphin Rt:Core" ..
    (rel ~= "/" and ("  ›  " .. rel) or ""), 20, y + 6)

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 9))
  love.graphics.printf(("%d entries"):format(#S.tools_list),
    0, y + 6, W - 20, "right")
end

local function draw_tools(th)
  draw_breadcrumb(th)

  local y0 = 128
  local bottom = H - 34
  local rh = 26
  local list = S.tools_list
  if #list == 0 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 12))
    love.graphics.printf("(empty directory)", 0, 220, W, "center")
    return
  end

  love.graphics.setScissor(0, y0, W, bottom - y0)
  local y = y0 - S.tools_scroll
  for i, e in ipairs(list) do
    if y + rh > y0 - rh and y < bottom + rh then
      local focused = (i == S.tools_sel)
      local c
      if e.is_dir then c = {0.96, 0.77, 0.26}
      elseif e.is_python then c = {0.30, 0.85, 0.40}
      elseif e.is_script then c = {0.20, 0.72, 0.98}
      elseif e.is_text then c = {0.55, 0.60, 0.72}
      else c = {0.55, 0.60, 0.72} end

      if focused then
        love.graphics.setColor(c[1] * 0.28, c[2] * 0.28, c[3] * 0.28, 0.9)
        love.graphics.rectangle("fill", 12, y, W - 24, rh - 1, 3, 3)
        love.graphics.setColor(c)
        love.graphics.rectangle("fill", 12, y, 3, rh - 1, 1, 1)
      end

      love.graphics.setColor(c)
      love.graphics.setFont(A.font(th.font_body_bold, 11))
      local glyph = e.is_dir and "▶" or (e.is_text and "≡" or "▶")
      love.graphics.print(glyph, 20, y + 5)

      love.graphics.setColor(focused and {1,1,1} or th.text)
      love.graphics.setFont(A.font(th.font_body, 11))
      local name = e.name
      if #name > 56 then name = name:sub(1, 54) .. "…" end
      love.graphics.print(name, 40, y + 5)

      love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.55)
      love.graphics.setFont(A.font(th.font_body, 9))
      local tag = e.is_dir and "DIR"
              or e.is_python and "PY"
              or e.is_script and "SH"
              or e.is_text and "TXT"
              or "?"
      love.graphics.printf(tag, 0, y + 6, W - 20, "right")
    end
    y = y + rh
  end
  love.graphics.setScissor()

  local total = #list * rh
  local vis_h = bottom - y0
  if total > vis_h then
    local rx = W - 6
    love.graphics.setColor(0.20, 0.22, 0.28, 0.6)
    love.graphics.rectangle("fill", rx, y0, 3, vis_h, 1, 1)
    local ratio = vis_h / total
    local bar_h = math.max(20, vis_h * ratio)
    local span = total - vis_h
    local by = y0 + (span > 0 and (S.tools_scroll / span) *
      (vis_h - bar_h) or 0)
    love.graphics.setColor(th.accent)
    love.graphics.rectangle("fill", rx, by, 3, bar_h, 1, 1)
  end
end

-- ══════════════════════════════════════════════════════════════
--  Confirmation overlay
-- ══════════════════════════════════════════════════════════════
local function draw_confirm(th)
  if not S.confirm then return end
  local c = S.confirm
  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, 0, W, H)

  local bw, bh = 460, 200
  local bx, by = (W - bw) / 2, (H - bh) / 2
  local col = {0.90, 0.30, 0.30}

  love.graphics.setColor(0.08, 0.08, 0.12, 0.98)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
  love.graphics.setColor(col)
  D.rough_rect(bx, by, bw, bh,
    { jitter = 1.5, thickness = 2.5, seed = 77, cut = 18 })
  D.corner_brackets(bx, by, bw, bh, col, 14)

  love.graphics.setColor(col[1], col[2], col[3], 0.12)
  love.graphics.rectangle("fill", bx, by, bw, 30, 6, 6)
  love.graphics.setColor(col)
  love.graphics.setFont(A.font(th.font_body_bold, 13))
  love.graphics.printf(c.title or "Confirm", bx, by + 8, bw, "center")

  love.graphics.setColor(th.text)
  love.graphics.setFont(A.font(th.font_body, 11))
  love.graphics.printf(c.body or "", bx + 20, by + 50, bw - 40, "center")

  love.graphics.setColor(0.30, 0.85, 0.40)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.printf("[A] Proceed      [B] Cancel",
    bx, by + bh - 32, bw, "center")
end

-- ══════════════════════════════════════════════════════════════
--  Main draw
-- ══════════════════════════════════════════════════════════════
function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  draw_header(th)
  draw_tab_bar(th)

  if     S.tab == 1 then draw_status(th)
  elseif S.tab == 2 then draw_profiles(th)
  elseif S.tab == 3 then draw_tools(th) end

  if S.confirm then draw_confirm(th) end

  if not S.confirm then
    local items
    if S.tab == 1 then
      items = {
        { key = "l1", label = "Prev"    },
        { key = "r1", label = "Next"    },
        { key = "y",  label = "Refresh" },
        { key = "b",  label = "Back"    },
      }
    elseif S.tab == 2 then
      items = {
        { key = "l1", label = "Prev"    },
        { key = "r1", label = "Next"    },
        { key = "dpad", label = "Nav"   },
        { key = "a",  label = "Apply"   },
        { key = "x",  label = "Diff"    },
        { key = "y",  label = "Refresh" },
        { key = "b",  label = "Back"    },
      }
    else
      items = {
        { key = "l1", label = "Prev"  },
        { key = "r1", label = "Next"  },
        { key = "dpad", label = "Nav" },
        { key = "a",  label = "Enter / Run" },
        { key = "b",  label = "Up"    },
      }
    end
    BI.draw_footer(th, items, W, H - 22, A.font(th.font_body, 11))
  end

  Modal.draw()
end

return S