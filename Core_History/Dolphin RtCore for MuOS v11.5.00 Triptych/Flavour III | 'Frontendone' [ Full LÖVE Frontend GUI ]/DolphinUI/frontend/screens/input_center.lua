-- screens/input_center.lua — Input hub.
--
-- Three entries:
--   * Key Mapping           → screens/settings_keymap.lua
--   * Input Debug           → screens/input_debug.lua
--   * External Input Station → screens/external_input_station.lua
--
-- Visual language matches settings.lua / workshop.lua: colored rails,
-- circular icon chips, pulsing LEDs, focus glow, animated cursor.

local A     = require("assets")
local SFX   = require("sfx")
local State = require("state")
local IM    = require("input_map")
local BI    = require("ui.button_icons")
local D     = require("ui.draw")
local BG    = require("ui.bg")
local Header= require("ui.header")
local Icons = require("ui.icons")

local S = {}
local W, H = 640, 480

local TOP_Y      = Header.height() + 12
local BOTTOM_PAD = 30
local CARD_H     = 108
local CARD_GAP   = 12

local ITEMS = {
  { key = "keymap",   label = "Key Mapping",
    desc  = "Rebind keyboard actions and shortcuts",
    icon  = "hotkeys",     color = {0.20, 0.72, 0.98},
    target = "settings_keymap" },
  { key = "debug",    label = "Input Debug",
    desc  = "Live gamepad inspector, raw button readout",
    icon  = "controller",  color = {0.96, 0.77, 0.26},
    target = "input_debug" },
  { key = "external", label = "External Input Station",
    desc  = "Burst Link — pair an external controller via USB or Bluetooth",
    icon  = "external",    color = {0.55, 0.35, 0.95},
    target = "external_input_station" },
}

S.sel = 1

function S.enter()
  S.sel = math.max(1, math.min(#ITEMS, S.sel or 1))
end

local function move(delta)
  local ni = math.max(1, math.min(#ITEMS, S.sel + delta))
  if ni ~= S.sel then S.sel = ni; SFX.play("menu_move") end
end

local function activate()
  local it = ITEMS[S.sel]
  if not it then return end
  SFX.play("menu_select")
  State.go(it.target)
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

-- ── Rendering ───────────────────────────────────────────────
local function draw_card(it, i, y, focused, th)
  local t = State.t_ui or 0
  local c = it.color
  local x, w, h = 24, W - 48, CARD_H

  if focused then
    local pulse = 0.5 + 0.5 * math.sin(t * 4)
    D.glow(x + w/2, y + h/2, 90 + pulse * 18, c, 0.95)
  end

  love.graphics.setColor(
    focused and c[1]*0.30 or 0.05,
    focused and c[2]*0.30 or 0.06,
    focused and c[3]*0.30 or 0.09,
    focused and 0.98 or 0.88)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)

  love.graphics.setColor(c[1], c[2], c[3], focused and 1 or 0.65)
  love.graphics.rectangle("fill", x, y, 6, h, 3, 3)

  if focused then
    love.graphics.setColor(1, 1, 1, 0.42)
    D.rough_rect(x - 1, y - 1, w + 2, h + 2,
      { jitter = 1.2, thickness = 2, seed = i * 13 })
    love.graphics.setColor(c)
    D.rough_rect(x, y, w, h,
      { jitter = 1.0, thickness = 2.6, seed = i * 17, cut = 14 })
    D.corner_brackets(x, y, w, h, c, 16)
  else
    love.graphics.setColor(c[1], c[2], c[3], 0.38)
    D.rough_rect(x, y, w, h,
      { jitter = 0.7, thickness = 1.3, seed = i * 17, cut = 14 })
  end

  -- Icon chip (large)
  local chip_cx = x + 52
  local chip_cy = y + h / 2
  local chip_r  = 30
  love.graphics.setColor(c[1]*0.28, c[2]*0.28, c[3]*0.28, 0.95)
  love.graphics.circle("fill", chip_cx, chip_cy, chip_r)
  love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.68)
  love.graphics.setLineWidth(focused and 2.2 or 1.4)
  love.graphics.circle("line", chip_cx, chip_cy, chip_r)
  love.graphics.setLineWidth(1)

  Icons.draw(it.icon, chip_cx - 22, chip_cy - 22, 44,
    focused and {1, 1, 1} or c)

  -- Label
  love.graphics.setColor(focused and {1, 1, 1} or th.text)
  love.graphics.setFont(A.font(th.font_title, 18))
  love.graphics.print(it.label, x + 100, y + 22)

  -- Description
  love.graphics.setColor(focused and c or th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 11))
  love.graphics.print(it.desc or "", x + 100, y + 52)

  -- Chevron hint
  if focused then
    local ax = x + w - 26 + math.sin(t * 6) * 3
    love.graphics.setColor(c)
    love.graphics.polygon("fill",
      ax,     y + h/2 - 9,
      ax + 12, y + h/2,
      ax,     y + h/2 + 9)
  end
end

function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  Header.draw("INPUT CENTER", "controller")

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 10))
  love.graphics.printf("Configure input sources and shortcuts",
    0, Header.height() + 6, W - 20, "right")

  local y = TOP_Y + 16
  for i, it in ipairs(ITEMS) do
    draw_card(it, i, y, i == S.sel, th)
    y = y + CARD_H + CARD_GAP
  end

  BI.draw_footer(th, {
    { key = "dpad", label = "Navigate" },
    { key = "a",    label = "Enter"    },
    { key = "b",    label = "Back"     },
  }, W, H - 22, A.font(th.font_body, 12))
end

return S