-- screens/workshop_controller.lua
-- Two-pane layout: profile list on the left, preview + metadata on the right.

local A = require("assets")
local SFX = require("sfx")
local State = require("state")
local IM = require("input_map")
local D = require("ui.draw")
local BG = require("ui.bg")
local Header = require("ui.header")
local Icons = require("ui.icons")
local BI = require("ui.button_icons")
local PM = require("profile_manager")
local PMerger = require("profile_merger")
local Notify = require("notify")

local S = {}
local W, H = 640, 480

local SYSTEMS = { "GameCube", "Wii" }
S.system = 1
S.sel = 1
S.list = {}

local LIST_W = 340
local PREVIEW_X = LIST_W + 20
local PREVIEW_W = W - PREVIEW_X - 20
local LIST_TOP = 98

local function shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function parse_hex(c)
  if not c then return {0.55, 0.35, 0.95} end
  local r,g,b = c:match("#(%x%x)(%x%x)(%x%x)")
  if r then
    return { tonumber(r,16)/255, tonumber(g,16)/255, tonumber(b,16)/255 }
  end
  return {0.55, 0.35, 0.95}
end

local function read_meta(dir)
  local parsed = PMerger.parse_ini(dir .. "/rtcontroller_data.ini")
  if not parsed then return {} end
  return parsed.data
end

local function file_exists(p)
  local f = io.open(p, "r")
  if f then f:close(); return true end
  return false
end

local function list_for_system(system)
  local out = {}
  local base = "workshop/controller/" .. system
  local h = io.popen('timeout 2 ls -1 ' .. shq(base) .. ' 2>/dev/null')
  if not h then return out end
  for name in h:lines() do
    if name ~= "" and name:sub(1, 1) ~= "." then
      local prof_dir = base .. "/" .. name
      local d = io.popen('timeout 1 [ -d ' .. shq(prof_dir) .. ' ] && echo 1 2>/dev/null')
      local is_dir = d and d:read("*a"):match("1") ~= nil
      if d then d:close() end
      if is_dir then
        local meta = read_meta(prof_dir)
        local fname = (system == "GameCube") and "GCPadNew.ini" or "WiimoteNew.ini"
        local has_ini = file_exists(prof_dir .. "/" .. fname)
        table.insert(out, {
          name = name,
          dir  = prof_dir,
          meta = meta,
          has_ini = has_ini,
          fname = fname,
        })
      end
    end
  end
  h:close()
  table.sort(out, function(a, b)
    local oa = tonumber((a.meta.UI and a.meta.UI.Order) or 99) or 99
    local ob = tonumber((b.meta.UI and b.meta.UI.Order) or 99) or 99
    if oa ~= ob then return oa < ob end
    return a.name:lower() < b.name:lower()
  end)
  return out
end

local function scan()
  S.list = list_for_system(SYSTEMS[S.system])
  S.sel = 1
end

function S.enter()
  S.sel = 1
  scan()
end

local function change_system(delta)
  S.system = ((S.system - 1 + delta) % #SYSTEMS) + 1
  scan()
  SFX.play("menu_pagescroll")
end

local function move(delta)
  local n = #S.list
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.sel + delta))
  if ni ~= S.sel then
    S.sel = ni
    SFX.play("menu_move")
  end
end

local function activate()
  local item = S.list[S.sel]
  if not item then return end
  if not item.has_ini then
    Notify.show("warning", "Missing " .. item.fname .. " in profile")
    return
  end
  local src  = item.dir .. "/" .. item.fname
  local dest = "dolphin-emu/Config/" .. item.fname
  os.execute("cp " .. shq(src) .. " " .. shq(dest))
  PM.set_active("controller", item.name)
  Notify.show("success", "Applied: " .. item.name)
end

local function edit_controller()
  local item = S.list[S.sel]
  if not item then return end
  if not item.has_ini then
    Notify.show("warning", "Missing " .. item.fname .. " in profile")
    return
  end
  os.execute("cp " .. shq(item.dir .. "/" .. item.fname) ..
             " " .. shq("dolphin-emu/Config/" .. item.fname))
  State.go("workshop_files", { file = item.fname })
end

function S.pad(b)
  if b == IM.A then activate() end
  if b == IM.Y then edit_controller() end
  if b == IM.L1 then change_system(-1) end
  if b == IM.R1 then change_system(1) end
end

function S.hat(dir)
  if     dir == "up"    then move(-1)
  elseif dir == "down"  then move(1)
  elseif dir == "left"  then change_system(-1)
  elseif dir == "right" then change_system(1) end
end

function S.key(k)
  if     k == "up"    then move(-1)
  elseif k == "down"  then move(1)
  elseif k == "left"  then change_system(-1)
  elseif k == "right" then change_system(1)
  elseif k == "return" or k == "space" then activate()
  elseif k == "y"     then edit_controller() end
end

-- ── Rendering ─────────────────────────────────────────────────
local function draw_system_tabs(th)
  local sx = 20
  for i, sys in ipairs(SYSTEMS) do
    local sw = 140
    local active = (i == S.system)
    local accent = (sys == "GameCube") and {0.55, 0.35, 0.95}
                   or {0.20, 0.72, 0.98}
    love.graphics.setColor(
      active and accent[1] or 0.10,
      active and accent[2] or 0.11,
      active and accent[3] or 0.14,
      active and 0.95 or 0.85)
    love.graphics.rectangle("fill", sx, 58, sw, 26, 4, 4)
    love.graphics.setColor(active and {1,1,1} or th.text_dim)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.printf(sys, sx, 63, sw, "center")
    if active then
      love.graphics.setColor(accent)
      D.rough_rect(sx, 58, sw, 26,
        { jitter = 0.6, thickness = 1.5, seed = i*7 })
    end
    sx = sx + sw + 8
  end
end

local function draw_list(th)
  local y = LIST_TOP
  love.graphics.setScissor(0, LIST_TOP, LIST_W + 20, H - LIST_TOP - 34)
  for i, item in ipairs(S.list) do
    local focused = (i == S.sel)
    local c = parse_hex(item.meta.UI and item.meta.UI.Color)
    local x, w, h = 20, LIST_W, 48

    if y + h > LIST_TOP and y < H - 34 then
      if focused then D.glow(x + w/2, y + h/2, 60, c, 0.9) end
      love.graphics.setColor(
        focused and c[1]*0.35 or c[1]*0.15,
        focused and c[2]*0.35 or c[2]*0.15,
        focused and c[3]*0.35 or c[3]*0.15, 0.95)
      love.graphics.rectangle("fill", x, y, w, h, 4, 4)

      love.graphics.setColor(c)
      local cut = (S.system == 1) and 14 or 22
      D.rough_rect(x, y, w, h,
        { jitter = focused and 1.2 or 0.8,
          thickness = focused and 2.5 or 1.5,
          seed = i * 13, cut = cut })

      Icons.draw(item.meta.UI and item.meta.UI.Icon or "controller",
        x + 12, y + 13, 22, c)

      love.graphics.setColor(focused and {1,1,1} or th.text)
      love.graphics.setFont(A.font(th.font_body_bold, 13))
      love.graphics.print(item.name, x + 46, y + 8)

      love.graphics.setColor(th.text_dim)
      love.graphics.setFont(A.font(th.font_body, 9))
      local desc = (item.meta.Controller and item.meta.Controller.Description) or ""
      if #desc > 38 then desc = desc:sub(1, 36) .. "…" end
      love.graphics.print(desc, x + 46, y + 27)

      local active = PM.active_profile("controller")
      if active == item.name then
        love.graphics.setColor(0.30, 0.80, 0.40)
        love.graphics.setFont(A.font(th.font_body_bold, 9))
        love.graphics.print("●", x + w - 16, y + 8)
      end
    end
    y = y + h + 6
  end
  love.graphics.setScissor()
end

local function draw_preview(th)
  local x = PREVIEW_X
  local y = LIST_TOP
  local w = PREVIEW_W
  local h = H - LIST_TOP - 34

  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)

  local item = S.list[S.sel]
  if not item then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.printf("No profile selected.", x, y + h/2, w, "center")
    return
  end

  local c = parse_hex(item.meta.UI and item.meta.UI.Color)

  love.graphics.setColor(c[1], c[2], c[3], 0.75)
  love.graphics.rectangle("fill", x, y, w, 3, 6, 6)

  love.graphics.setColor(c)
  D.rough_rect(x, y, w, h,
    { jitter = 0.9, thickness = 1.5, seed = 71, cut = 12 })

  local icon_key = (item.meta.UI and item.meta.UI.Icon) or "controller"
  Icons.draw(icon_key, x + w/2 - 40, y + 26, 80, c)

  love.graphics.setColor(th.text)
  love.graphics.setFont(A.font(th.font_body_bold, 16))
  love.graphics.printf(item.name, x, y + 120, w, "center")

  love.graphics.setColor(c)
  love.graphics.setFont(A.font(th.font_body_bold, 10))
  love.graphics.printf(SYSTEMS[S.system]:upper(), x, y + 144, w, "center")

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 10))
  local desc = (item.meta.Controller and item.meta.Controller.Description) or ""
  love.graphics.printf(desc, x + 16, y + 172, w - 32, "left")

  local my = y + 214
  local function row(k, v)
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.print(k, x + 16, my)
    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.printf(v or "—", x + 16, my, w - 32, "right")
    my = my + 16
  end

  local meta = item.meta
  row("Author",  (meta.Controller and meta.Controller.Author)  or "—")
  row("Version", (meta.Controller and meta.Controller.Version) or "—")
  row("Tags",    (meta.UI and meta.UI.Tags) or "—")

  love.graphics.setColor(item.has_ini and {0.30,0.80,0.40} or {0.90,0.30,0.30})
  love.graphics.setFont(A.font(th.font_body_bold, 9))
  love.graphics.printf(item.has_ini and "● INI present" or "○ INI missing",
    x, my + 6, w, "center")

  love.graphics.setColor(c[1], c[2], c[3], 0.25)
  love.graphics.rectangle("fill", x + 12, y + h - 40, w - 24, 1)

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 9))
  love.graphics.printf("[A] Apply  ·  [Y] Edit INI", x, y + h - 28, w, "center")
end

function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  Header.draw("CONTROLLER PROFILES", "controller")

  draw_system_tabs(th)

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 10))
  love.graphics.printf(#S.list .. " profiles", 0, 64, W - 20, "right")

  if #S.list == 0 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 12))
    love.graphics.printf(
      "No profiles found for " .. SYSTEMS[S.system] ..
      "\n\nExpected path:\n  workshop/controller/" .. SYSTEMS[S.system] .. "/<Name>/",
      0, H/2 - 20, W, "center")
  else
    draw_list(th)
    draw_preview(th)
  end

  BI.draw_hint_centered(
    "[↑↓] Nav   [L1/R1] System   [A] Apply   [Y] Edit   [B] Back",
    W, H - 22, A.font(th.font_body, 11), th)
end

return S