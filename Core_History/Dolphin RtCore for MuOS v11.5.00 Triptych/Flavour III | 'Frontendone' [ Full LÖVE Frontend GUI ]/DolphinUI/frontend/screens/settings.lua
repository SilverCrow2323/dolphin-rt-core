-- screens/settings.lua — main settings menu.
--
-- v0.6.0 — SPDW definitive layout
--   * Structure rebuilt. The old entries "ROM Paths", "Key Mapping"
--     and "Input Debug" are gone: ROM paths now live inside
--     DolphinUI Options, and the two input screens live inside the
--     new "Input Center" hub.
--   * Config Wizard is no longer here: it moved to the Workshop,
--     where it belongs (it is a config editor, not a system option).
--   * Two groups remain: CONFIGURATION and SYSTEM.
--   * Visual language: colored rails, circular icon chips, pulsing
--     LEDs in group headers, focus glow, animated cursor. Matches
--     workshop.lua and game_detail.lua.
--
-- Actionable list (used by the cursor):
--   1  DolphinUI Options
--   2  Input Center
--   3  External Rt:Core
--   4  Rt:Manual & Abouts
--   5  About DolphinUI

local A       = require("assets")
local SFX     = require("sfx")
local State   = require("state")
local IM      = require("input_map")
local BI      = require("ui.button_icons")
local D       = require("ui.draw")
local BG      = require("ui.bg")
local Header  = require("ui.header")
local Icons   = require("ui.icons")

local S = {}
local W, H = 640, 480

local GROUPS = {
  ["CONFIGURATION"] = { color = {0.55, 0.35, 0.95}, icon = "settings" },
  ["SYSTEM"]        = { color = {0.20, 0.72, 0.98}, icon = "advanced" },
}

local ITEMS = {
  { group = "CONFIGURATION" },
  { key = "app",         label = "DolphinUI Options",
    desc  = "General, ROM paths, theme, UI, SFX, advanced",
    icon  = "settings",  color = {0.30, 0.60, 0.95} },
  { key = "input",       label = "Input Center",
    desc  = "Keymap, live input inspector, external input station",
    icon  = "controller",color = {0.96, 0.77, 0.26} },

  { group = "SYSTEM" },
  { key = "external",    label = "External Rt:Core",
    desc  = "Profiles, toggles, mods, muOS core tools",
    icon  = "external",  color = {0.96, 0.77, 0.26} },
  { key = "manual",      label = "Rt:Manual & Abouts",
    desc  = "Docs, credits, build info",
    icon  = "manual",    color = {0.30, 0.80, 0.60} },
  { key = "about",       label = "About DolphinUI",
    desc  = "Version, mission, QR repo",
    icon  = "about",     color = {0.30, 0.60, 0.95} },
}

-- Actionable-only indices for navigation.
local ACTIONABLE = {}
for i, it in ipairs(ITEMS) do
  if not it.group then ACTIONABLE[#ACTIONABLE + 1] = i end
end

local TOP_Y       = Header.height() + 8
local BOTTOM_PAD  = 30
local GROUP_H     = 28
local ITEM_H      = 52
local ITEM_GAP    = 4

S.sel = 1

local function nth_actionable(n) return ACTIONABLE[n] end
local function actionable_idx_of(item_index)
  for n, ii in ipairs(ACTIONABLE) do
    if ii == item_index then return n end
  end
end

function S.enter()
  local n = #ACTIONABLE
  if not State.settings_index or State.settings_index < 1
     or State.settings_index > n then
    State.settings_index = 1
  end
  S.sel = nth_actionable(State.settings_index)
  State.settings_anim = { last = State.settings_index, t = 0 }
end

local function move(delta)
  local n = #ACTIONABLE
  if n == 0 then return end
  local cur = actionable_idx_of(S.sel) or 1
  local ni = ((cur - 1 + delta) % n) + 1
  if ni ~= cur then
    State.settings_index = ni
    S.sel = nth_actionable(ni)
    State.settings_anim = { last = ni, t = 0 }
    SFX.play("menu_move")
  end
end

local function activate()
  local it = ITEMS[S.sel]
  if not it or it.group then return end
  SFX.play("menu_select")
  if     it.key == "app"      then State.go("settings_app")
  elseif it.key == "input"    then State.go("input_center")
  elseif it.key == "external" then State.go("external")
  elseif it.key == "manual"   then State.go("manual")
  elseif it.key == "about"    then State.go("about") end
end

function S.pad(b) if b == IM.A then activate() end end
function S.hat(dir)
  if     dir == "up"   then move(-1)
  elseif dir == "down" then move(1) end
end
function S.key(k)
  if     k == "up"   then move(-1)
  elseif k == "down" then move(1)
  elseif k == "return" or k == "space" then activate() end
end

function S.update(dt)
  if State.settings_anim then
    State.settings_anim.t = State.settings_anim.t + dt
  end
end

-- ── Rendering ───────────────────────────────────────────────
local function draw_group_header(g, y, th)
  local meta = GROUPS[g] or { color = {0.55, 0.55, 0.65}, icon = "settings" }
  local col  = meta.color
  local t    = State.t_ui or 0
  local pulse = 0.5 + 0.5 * math.sin(t * 2 + g:len())

  local x = 20
  love.graphics.setColor(col[1], col[2], col[3], 0.30 + pulse * 0.40)
  love.graphics.circle("fill", x + 8, y + GROUP_H/2, 5)
  love.graphics.setColor(col[1], col[2], col[3], 1)
  love.graphics.circle("fill", x + 8, y + GROUP_H/2, 2.5)

  Icons.draw(meta.icon, x + 18, y + 7, 14, col)

  love.graphics.setColor(col)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.print(g, x + 36, y + 7)

  local lx = x + 36 + love.graphics.getFont():getWidth(g) + 12
  local lw = W - lx - x
  if lw > 8 then
    love.graphics.setColor(col[1], col[2], col[3], 0.20)
    love.graphics.line(lx, y + GROUP_H/2, lx + lw, y + GROUP_H/2)
    love.graphics.setColor(col[1], col[2], col[3], 0.55)
    love.graphics.rectangle("fill", lx, y + GROUP_H/2 - 1, 4, 2)
  end
end

local function draw_item(it, y, focused, th)
  local t = State.t_ui or 0
  local c = it.color or {0.55, 0.35, 0.95}
  local x, w, h = 20, W - 40, ITEM_H

  if focused then
    local pulse = 0.5 + 0.5 * math.sin(t * 4)
    D.glow(x + w/2, y + h/2, 70 + pulse * 15, c, 0.90)
  end

  love.graphics.setColor(
    focused and c[1]*0.30 or 0.05,
    focused and c[2]*0.30 or 0.06,
    focused and c[3]*0.30 or 0.09, focused and 0.98 or 0.85)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)

  love.graphics.setColor(c[1], c[2], c[3], focused and 1 or 0.65)
  love.graphics.rectangle("fill", x, y, 5, h)

  if focused then
    love.graphics.setColor(1, 1, 1, 0.42)
    D.rough_rect(x - 1, y - 1, w + 2, h + 2,
      { jitter = 1.2, thickness = 2, seed = 91 })
    love.graphics.setColor(c)
    D.rough_rect(x, y, w, h,
      { jitter = 1.0, thickness = 2.4, seed = 93, cut = 10 })
    D.corner_brackets(x, y, w, h, c, 10)
  else
    love.graphics.setColor(c[1], c[2], c[3], 0.38)
    D.rough_rect(x, y, w, h,
      { jitter = 0.7, thickness = 1.2, seed = 93, cut = 10 })
  end

  local chip_cx = x + 28
  local chip_cy = y + h/2
  local chip_r  = 16
  love.graphics.setColor(c[1]*0.30, c[2]*0.30, c[3]*0.30, 0.95)
  love.graphics.circle("fill", chip_cx, chip_cy, chip_r)
  love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.70)
  love.graphics.setLineWidth(focused and 1.6 or 1.2)
  love.graphics.circle("line", chip_cx, chip_cy, chip_r)
  love.graphics.setLineWidth(1)

  Icons.draw(it.icon, chip_cx - 11, chip_cy - 11, 22,
    focused and {1, 1, 1} or c)

  love.graphics.setColor(focused and {1, 1, 1} or th.text)
  love.graphics.setFont(A.font(th.font_body_bold, 14))
  love.graphics.print(it.label, x + 58, y + 8)

  love.graphics.setColor(focused and c or th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 11))
  love.graphics.print(it.desc or "", x + 58, y + 30)

  if focused then
    local ax = x - 14 + math.sin(t * 6) * 3
    love.graphics.setColor(c)
    love.graphics.polygon("fill",
      ax,     y + h/2 - 6,
      ax + 8, y + h/2,
      ax,     y + h/2 + 6)
  end
end

function S.draw()
  local th = State.theme
  BG.draw_nexus(W, H, love.timer.getDelta(), th.accent)
  Header.draw("SETTINGS", "settings")

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 10))
  love.graphics.printf("Press [A] to enter, [B] to go back",
    0, Header.height() + 6, W - 20, "right")

  local top = TOP_Y + 14
  local bottom = H - BOTTOM_PAD
  love.graphics.setScissor(0, top, W, bottom - top)

  local y = top + 6
  for i, row in ipairs(ITEMS) do
    if row.group then
      if y + GROUP_H > top - 40 and y < bottom + 40 then
        draw_group_header(row.group, y, th)
      end
      y = y + GROUP_H
    else
      if y + ITEM_H > top - 40 and y < bottom + 40 then
        draw_item(row, y, i == S.sel, th)
      end
      y = y + ITEM_H + ITEM_GAP
    end
  end
  love.graphics.setScissor()

  BI.draw_footer(th, {
    { key = "dpad", label = "Navigate" },
    { key = "a",    label = "Enter"    },
    { key = "b",    label = "Back"     },
  }, W, H - 22, A.font(th.font_body, 12))
end

return S