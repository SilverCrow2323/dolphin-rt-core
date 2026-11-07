-- screens/workshop_mods.lua — Graphic Mods manager.
-- Scans dolphin-emu/Load/GraphicMods/ and toggles EnableGraphicsMods
-- in GFX.ini. Shell args are shq()-quoted; listings use a 2s timeout.

local A      = require("assets")
local SFX    = require("sfx")
local State  = require("state")
local IM     = require("input_map")
local D      = require("ui.draw")
local BG     = require("ui.bg")
local Header = require("ui.header")
local Icons  = require("ui.icons")
local BI     = require("ui.button_icons")
local Notify = require("notify")

local S = {}
local W, H = 640, 480

S.sel = 1
S.list = {}
S.scroll = 0
S.filter = 0

local GFX_INI  = "dolphin-emu/Config/GFX.ini"
local MODS_DIR = "dolphin-emu/Load/GraphicMods"

local function shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function scan_mods()
  S.list = {}
  local h = io.popen('timeout 2 ls -1 ' .. shq(MODS_DIR) .. ' 2>/dev/null')
  if not h then return end
  for name in h:lines() do
    if name ~= "" and name:sub(1, 1) ~= "." then
      local dir = MODS_DIR .. "/" .. name
      local d = io.popen('timeout 1 [ -d ' .. shq(dir) .. ' ] && echo 1')
      local is_dir = d and d:read("*a"):match("1") ~= nil
      if d then d:close() end
      if is_dir then
        local is_all = name:match("^All Games ") ~= nil
        local display = name:gsub("^All Games ", ""):gsub("^%d+%s*%-%s*", "")
        table.insert(S.list, {
          name = name, display = display,
          is_all = is_all, path = dir,
        })
      end
    end
  end
  h:close()
  table.sort(S.list, function(a, b)
    if a.is_all ~= b.is_all then return a.is_all end
    return a.display:lower() < b.display:lower()
  end)
end

local function read_gfx_lines()
  local lines = {}
  local f = io.open(GFX_INI, "r")
  if not f then return lines end
  for line in f:lines() do table.insert(lines, line) end
  f:close()
  return lines
end

local function write_gfx_lines(lines)
  local tmp = GFX_INI .. ".tmp"
  local w = io.open(tmp, "w")
  if not w then return false end
  for _, l in ipairs(lines) do w:write(l .. "\n") end
  w:close()
  os.remove(GFX_INI)
  os.rename(tmp, GFX_INI)
  return true
end

local function is_enabled()
  for _, line in ipairs(read_gfx_lines()) do
    local k, v = line:match("^%s*([^=]+)%s*=%s*(.*)$")
    if k and k:match("^EnableGraphicsMods") then
      return v:match("^%s*True") ~= nil
    end
  end
  return false
end

local function set_enabled(state)
  local lines = read_gfx_lines()
  local done = false
  local target = state and "True" or "False"

  for i, line in ipairs(lines) do
    if line:match("^%s*EnableGraphicsMods%s*=") then
      lines[i] = "EnableGraphicsMods = " .. target
      done = true
    end
  end

  if not done then
    local section_at = nil
    for i, line in ipairs(lines) do
      if line:match("^%s*%[Hacks%]") then section_at = i break end
    end
    if not section_at then
      for i, line in ipairs(lines) do
        if line:match("^%s*%[Settings%]") then section_at = i break end
      end
    end
    if not section_at then section_at = #lines end
    table.insert(lines, section_at + 1, "EnableGraphicsMods = " .. target)
  end

  return write_gfx_lines(lines)
end

function S.enter() S.sel = 1; S.scroll = 0; scan_mods() end

local function filtered()
  if S.filter == 0 then return S.list end
  local out = {}
  for _, m in ipairs(S.list) do
    if S.filter == 1 and m.is_all then table.insert(out, m) end
    if S.filter == 2 and not m.is_all then table.insert(out, m) end
  end
  return out
end

local function move(delta)
  local n = #filtered()
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.sel + delta))
  if ni ~= S.sel then
    S.sel = ni; SFX.play("menu_move")
    local cell_h = 72
    local vis_h = H - 160
    local top = (S.sel - 1) * cell_h
    if top < S.scroll then S.scroll = top
    elseif top + cell_h > S.scroll + vis_h then
      S.scroll = top + cell_h - vis_h
    end
  end
end

local function toggle_filter()
  S.filter = (S.filter + 1) % 3
  S.sel = 1; S.scroll = 0
  SFX.play("menu_pagescroll")
end

local function activate()
  local list = filtered()
  if not list[S.sel] then return end
  local cur = is_enabled()
  if set_enabled(not cur) then
    Notify.show(not cur and "success" or "info",
      not cur and "Graphics Mods ENABLED" or "Graphics Mods DISABLED")
  else
    Notify.show("error", "Cannot write GFX.ini")
  end
end

function S.pad(b)
  if b == IM.A then activate() end
  if b == IM.Y then toggle_filter() end
end

function S.hat(dir)
  if dir == "up" then move(-1)
  elseif dir == "down" then move(1)
  elseif dir == "left" or dir == "right" then toggle_filter() end
end

function S.key(k)
  if k == "up" then move(-1)
  elseif k == "down" then move(1)
  elseif k == "left" or k == "right" then toggle_filter()
  elseif k == "return" or k == "space" then activate() end
end

-- ── Rendering ───────────────────────────────────────────────
local function draw_item(item, i, focused, y, th, engine_on)
  local t = State.t_ui or 0
  local pulse = 0.5 + 0.5 * math.sin(t * 4 + i * 0.3)
  local c = item.is_all and {0.20, 0.72, 0.98} or {0.96, 0.50, 0.30}
  local x, w, h = 20, W - 40, 72

  if focused then D.glow(x + w/2, y + h/2, 60, c, 0.9) end
  love.graphics.setColor(focused and c[1]*0.28 or c[1]*0.10,
                         focused and c[2]*0.28 or c[2]*0.10,
                         focused and c[3]*0.28 or c[3]*0.10, 0.95)
  love.graphics.rectangle("fill", x, y, w, h, 3, 3)

  love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.55)
  love.graphics.rectangle("fill", x, y, 3, h)

  love.graphics.setColor(c)
  D.rough_rect(x, y, w, h, { jitter = focused and 1.2 or 0.7,
      thickness = focused and 2.5 or 1.5, seed = i * 13, cut = 18 })
  if focused then D.corner_brackets(x, y, w, h, c, 10) end

  Icons.draw("enhancer", x + 16, y + 22, 26, c)

  love.graphics.setColor(focused and {1,1,1} or th.text)
  love.graphics.setFont(A.font(th.font_body_bold, 13))
  love.graphics.print(item.display, x + 56, y + 10)

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 10))
  love.graphics.print(item.is_all and "GLOBAL MOD" or "GAME-SPECIFIC",
      x + 56, y + 30)

  local label, col
  if engine_on then
    label = "● ACTIVE"; col = {0.30, 0.80, 0.40}
  else
    label = "○ INACTIVE"; col = {0.55, 0.55, 0.62}
  end
  local font = A.font(th.font_body_bold, 10)
  love.graphics.setFont(font)
  local bw = font:getWidth(label) + 14
  love.graphics.setColor(col[1], col[2], col[3], 0.85)
  love.graphics.rectangle("fill", x + w - bw - 12, y + 12, bw, 18, 9, 9)
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.printf(label, x + w - bw - 12, y + 15, bw, "center")

  if focused then
    love.graphics.setColor(c)
    love.graphics.setFont(A.font(th.font_body_bold, 9))
    love.graphics.print("[A] Toggle engine", x + w - 130, y + 48)
  end
end

local function draw_filter_tabs(th, engine_on)
  local tabs = { "ALL", "GLOBAL", "GAME-SPECIFIC" }
  local x = 20
  for i, t in ipairs(tabs) do
    local w = 120
    local active = (S.filter == i - 1)
    love.graphics.setColor(active and th.focus or {0.10,0.11,0.15,0.85})
    love.graphics.rectangle("fill", x, 58, w, 22, 3, 3)
    love.graphics.setColor(active and {1,1,1} or th.text_dim)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.printf(t, x, 63, w, "center")
    x = x + w + 6
  end
  love.graphics.setColor(engine_on and {0.30, 0.80, 0.40} or {0.55, 0.55, 0.62})
  love.graphics.setFont(A.font(th.font_body_bold, 10))
  love.graphics.printf(">> ENGINE: " .. (engine_on and "ON" or "OFF"),
      0, 63, W - 20, "right")
end

function S.draw()
  local th = State.theme
  BG.draw_hexgrid(W, H, love.timer.getDelta(), {0.20, 0.72, 0.98})
  local engine_on = is_enabled()
  Header.draw("GENERAL MODS", "enhancer")
  draw_filter_tabs(th, engine_on)

  local list = filtered()
  if #list == 0 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 12))
    love.graphics.printf(
      "No mods installed.\n\nDownload a Graphic Mods Pack from Rt:Enhancer.",
      0, 220, W, "center")
  else
    local top = 88
    local bottom = H - 30
    love.graphics.setScissor(0, top, W, bottom - top)
    local y = top - S.scroll
    for i, item in ipairs(list) do
      if y + 76 > top and y < bottom then
        draw_item(item, i, i == S.sel, y, th, engine_on)
      end
      y = y + 76
    end
    love.graphics.setScissor()
  end

  BI.draw_hint_centered(
    ("[←→/Y] Filter   [↑↓] Nav   [A] Toggle   [B] Back   (%d mods)")
    :format(#list),
    W, H - 22, A.font(th.font_body, 12), th)
end

return S