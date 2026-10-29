-- screens/workshop_hotkeys.lua — Hotkey profile selector.
-- Profile cards with color band + bindings preview on expand.

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
local Notify = require("notify")

local S = {}
local W, H = 640, 480
S.sel = 1
S.list = {}
S.expanded = false

local function parse_hex(c, fb)
  if not c or c == "" then return fb or {0.55, 0.35, 0.95} end
  local r, g, b = c:match("#(%x%x)(%x%x)(%x%x)")
  if r then
    return { tonumber(r,16)/255, tonumber(g,16)/255, tonumber(b,16)/255 }
  end
  return fb or {0.55, 0.35, 0.95}
end

local function scan()
  local raw = PM.list("hotkeys")
  S.list = {}
  for _, item in ipairs(raw) do
    -- Robust defaults so we never crash on a malformed profile
    item.meta = item.meta or {}
    item.meta.UI = item.meta.UI or {}
    item.meta.Hotkeys = item.meta.Hotkeys or {}
    item.meta.Summary = item.meta.Summary or {}
    S.list[#S.list+1] = item
  end
  table.sort(S.list, function(a, b)
    local oa = tonumber(a.meta.UI.Order or 99) or 99
    local ob = tonumber(b.meta.UI.Order or 99) or 99
    if oa ~= ob then return oa < ob end
    return a.name:lower() < b.name:lower()
  end)
  S.sel = math.max(1, math.min(#S.list, S.sel))
end

function S.enter()
  S.sel = 1
  S.expanded = false
  scan()
end

local function move(delta)
  local n = #S.list
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.sel + delta))
  if ni ~= S.sel then
    S.sel = ni
    S.expanded = false
    SFX.play("menu_move")
  end
end

local function activate()
  local item = S.list[S.sel]
  if not item then return end
  if PM.apply("hotkeys", item.name) then
    PM.set_active("hotkeys", item.name)
  end
end

local function edit_bindings()
  local item = S.list[S.sel]
  if not item then return end
  SFX.play("menu_select")
  State.go("workshop_hotkey_edit", { profile = item.name })
end

function S.pad(b)
  if b == IM.A then activate() end
  if b == IM.X then edit_bindings() end
  if b == IM.Y then
    S.expanded = not S.expanded
    SFX.play("menu_toggleoption")
  end
end

function S.hat(dir)
  if     dir == "up"   then move(-1)
  elseif dir == "down" then move(1) end
end

function S.key(k)
  if     k == "up"   then move(-1)
  elseif k == "down" then move(1)
  elseif k == "return" or k == "space" then activate()
  elseif k == "x" then edit_bindings()
  elseif k == "tab" or k == "y" then
    S.expanded = not S.expanded
    SFX.play("menu_toggleoption")
  end
end

function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  Header.draw("HOTKEYS", "hotkeys")

  if #S.list == 0 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 12))
    love.graphics.printf(
      "No hotkey profiles found.\n\nExpected path:\nworkshop/hotkeys/<Name>/",
      0, H/2 - 20, W, "center")
    BI.draw_hint_centered("[B] Back",
      W, H - 22, A.font(th.font_body, 12), th)
    return
  end

  local y = 70
  local t = State.t_ui or 0
  for i, item in ipairs(S.list) do
    local focused = (i == S.sel)
    local x, w, h = 30, W - 60, 44
    local c = parse_hex(item.meta.UI.Color, {0.55, 0.35, 0.95})

    if focused then
      local pulse = 0.5 + 0.5 * math.sin(t * 4)
      D.glow(x + w/2, y + h/2, 60, c, 0.7 + pulse * 0.2)
    end
    love.graphics.setColor(
      focused and c[1]*0.35 or c[1]*0.13,
      focused and c[2]*0.35 or c[2]*0.13,
      focused and c[3]*0.35 or c[3]*0.13, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.55)
    love.graphics.rectangle("fill", x, y, 3, h)

    love.graphics.setColor(c)
    D.rough_rect(x, y, w, h,
        { jitter = focused and 1.2 or 0.8,
          thickness = focused and 2.5 or 1.5, seed = i * 11 })

    Icons.draw(item.meta.UI.Icon or "hotkeys", x + 14, y + 11, 22, c)

    love.graphics.setColor(focused and {1,1,1} or th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 13))
    love.graphics.print(item.name, x + 46, y + 7)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.print(item.meta.Hotkeys.Description or "", x + 46, y + 25)

    local active = PM.active_profile("hotkeys") or "Default"
    if item.name == active then
      local badge = "● ACTIVE"
      local font = A.font(th.font_body_bold, 9)
      local bw = font:getWidth(badge) + 12
      love.graphics.setColor(0.30, 0.80, 0.40, 0.9)
      love.graphics.rectangle("fill", x + w - bw - 10, y + 6, bw, 16, 8, 8)
      love.graphics.setColor(0, 0, 0, 0.9)
      love.graphics.printf(badge, x + w - bw - 10, y + 8, bw, "center")
    end

    if focused then
      love.graphics.setColor(c)
      love.graphics.setFont(A.font(th.font_body_bold, 9))
      love.graphics.print("[X] Edit", x + w - 60, y + 26)
    end

    y = y + h + 6

    if focused and S.expanded then
      local keys = {}
      for k, v in pairs(item.meta.Summary) do
        table.insert(keys, {k, v})
      end
      table.sort(keys, function(a,b) return a[1] < b[1] end)

      local bx = x + 10
      local bw = w - 20
      local lines = math.max(1, #keys)
      local bh = lines * 14 + 16
      love.graphics.setColor(0, 0, 0, 0.7)
      love.graphics.rectangle("fill", bx, y, bw, bh, 3, 3)
      love.graphics.setColor(c[1], c[2], c[3], 0.5)
      D.rough_rect(bx, y, bw, bh,
          { jitter = 0.7, thickness = 1.2, seed = i * 17 })

      if #keys == 0 then
        love.graphics.setColor(0.55, 0.55, 0.62)
        love.graphics.setFont(A.font(th.font_body, 10))
        love.graphics.print("(no summary available)", bx + 12, y + 8)
      else
        local ky = y + 8
        love.graphics.setFont(A.font(th.font_body, 10))
        for _, kv in ipairs(keys) do
          love.graphics.setColor(0.60, 0.60, 0.70)
          love.graphics.print(kv[1], bx + 12, ky)
          love.graphics.setColor(1,1,1)
          love.graphics.print(kv[2], bx + 140, ky)
          ky = ky + 14
        end
      end

      y = y + bh + 6
    end
  end

  BI.draw_hint_centered(
    "[↑↓] Nav   [A] Apply   [X] Edit bindings   [Y] Preview   [B] Back",
    W, H - 22, A.font(th.font_body, 12), th)
end

return S