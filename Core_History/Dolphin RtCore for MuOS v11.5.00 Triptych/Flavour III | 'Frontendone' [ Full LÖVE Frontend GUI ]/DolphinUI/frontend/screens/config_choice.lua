-- screens/config_choice.lua — Manual vs Guided configuration chooser.
-- Shown before entering the INI editor. The user picks either the classic
-- manual editor or the guided wizard. Also exposes the option to edit an
-- existing profile rather than create a new one.
local A      = require("assets")
local SFX    = require("sfx")
local State  = require("state")
local IM     = require("input_map")
local D      = require("ui.draw")
local BG     = require("ui.bg")
local Header = require("ui.header")
local BI     = require("ui.button_icons")

local S = {}
local W, H = 640, 480

local CHOICES = {
  {
    key   = "manual",
    label = "Manual Configuration",
    desc  = "Edit INI keys directly. Full control, all options exposed.",
    icon  = "settings",
    color = {0.30, 0.80, 0.60},
  },
  {
    key   = "guided",
    label = "Guided Configuration",
    desc  = "Answer a few questions. Wizard creates a ready-made profile.",
    icon  = "target",
    color = {0.20, 0.72, 0.98},
  },
}

S.sel = 1

function S.enter()
  S.sel = 1
end

local function activate()
  local c = CHOICES[S.sel]
  SFX.play("menu_select")
  if c.key == "manual" then
    State.go("workshop_files")
  elseif c.key == "guided" then
    State.go("config_wizard", { wizard_id = "core_profile" })
  end
end

function S.pad(b) if b == IM.A then activate() end end

function S.hat(dir)
  if dir == "up" then S.sel = math.max(1, S.sel - 1); SFX.play("menu_move")
  elseif dir == "down" then S.sel = math.min(#CHOICES, S.sel + 1); SFX.play("menu_move") end
end

function S.key(k)
  if k == "up" then S.hat("up")
  elseif k == "down" then S.hat("down")
  elseif k == "return" or k == "space" then activate()
  elseif k == "escape" then State.back() end
end

function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  Header.draw("CONFIG EDITOR", "settings")

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 12))
  love.graphics.printf(
    "Choose how you want to build or modify a configuration.",
    0, 76, W, "center")

  local y = 120
  local bw = W - 100
  local bx = 50
  local bh = 110
  for i, c in ipairs(CHOICES) do
    local focused = (i == S.sel)

    if focused then
      D.glow(bx + bw/2, y + bh/2, 90, c.color, 0.9)
    end
    love.graphics.setColor(
      focused and c.color[1]*0.28 or c.color[1]*0.10,
      focused and c.color[2]*0.28 or c.color[2]*0.10,
      focused and c.color[3]*0.28 or c.color[3]*0.10,
      0.95)
    love.graphics.rectangle("fill", bx, y, bw, bh, 6, 6)

    if focused then
      love.graphics.setColor(1, 1, 1, 0.5)
      D.rough_rect(bx - 2, y - 2, bw + 4, bh + 4,
        { jitter = 1.4, thickness = 2, seed = i * 7 })
    end
    love.graphics.setColor(c.color)
    D.rough_rect(bx, y, bw, bh,
      { jitter = focused and 1.1 or 0.7,
        thickness = focused and 2.5 or 1.5, seed = i * 13, cut = 14 })
    if focused then D.corner_brackets(bx, y, bw, bh, c.color, 16) end

    love.graphics.setColor(c.color[1], c.color[2], c.color[3], 0.95)
    love.graphics.rectangle("fill", bx, y + 6, 3, bh - 12, 1, 1)

    love.graphics.setFont(A.font(th.font_body_bold, 16))
    love.graphics.setColor(focused and {1,1,1} or th.text)
    love.graphics.print(c.label, bx + 24, y + 20)

    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.setColor(focused and c.color or th.text_dim)
    love.graphics.print(c.desc, bx + 24, y + 46)

    if focused then
      love.graphics.setColor(c.color)
      love.graphics.polygon("fill",
        bx + bw - 40, y + bh/2 - 8,
        bx + bw - 28, y + bh/2,
        bx + bw - 40, y + bh/2 + 8)
    end

    y = y + bh + 16
  end

  BI.draw_footer(th, {
    { key = "dpad", label = "Navigate" },
    { key = "a",    label = "Select"   },
    { key = "b",    label = "Back"     },
  }, W, H - 22, A.font(th.font_body, 12))
end

return S