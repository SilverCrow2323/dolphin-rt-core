-- screens/rom_paths.lua — manage ROM paths per system (GameCube / Wii).
-- Multi-path, add/edit/remove. Edit/Add open the File Grid-Diver.
-- Every successful add/edit/remove triggers an async ROM rescan.

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
local Store  = require("settings_store")

local S = {}
local W, H = 640, 480

local SYSTEMS = {
  { key = "gc",  label = "GAMECUBE", color = {0.55, 0.35, 0.95} },
  { key = "wii", label = "WII",      color = {0.20, 0.72, 0.98} },
}

S.sys_idx  = 1
S.sel      = 1     -- 1..N = path entries, N+1 = "Add"
S.paths    = {}
S.enter_t  = 0

-- ── Helpers ─────────────────────────────────────────────────
local function current_system()
  return SYSTEMS[S.sys_idx].key
end

local function current_color()
  return SYSTEMS[S.sys_idx].color
end

local function reload()
  S.paths = Store.get_paths(current_system())
  local maxi = #S.paths + 1     -- +1 for "Add" row
  S.sel = math.max(1, math.min(maxi, S.sel))
end

local function system_label()
  return SYSTEMS[S.sys_idx].label
end

-- ── Lifecycle ───────────────────────────────────────────────
function S.enter()
  S.sel = 1
  S.enter_t = 0
  reload()
end

-- Called by main.lua on State.back() when returning to this screen.
function S.re_enter()
  reload()
end

-- ── Navigation ──────────────────────────────────────────────
local function move(delta)
  local n = #S.paths + 1
  local ni = math.max(1, math.min(n, S.sel + delta))
  if ni ~= S.sel then
    S.sel = ni
    SFX.play("menu_move")
  end
end

local function change_system(delta)
  S.sys_idx = ((S.sys_idx - 1 + delta) % #SYSTEMS) + 1
  S.sel = 1
  reload()
  SFX.play("menu_pagescroll")
end

-- ── Actions ─────────────────────────────────────────────────
local function browse_start_for_add()
  local list = S.paths
  if #list > 0 then
    return list[#list]
  end
  return "/mnt"
end

local function open_add()
  State.go("file_explorer", {
    start_path = browse_start_for_add(),
    on_select  = function(chosen)
      local ok, err = Store.add_path(current_system(), chosen)
      if ok then
        Store.save()
        Notify.show("success", "Added: " .. chosen)
        State.rescan_roms_async()
      else
        Notify.show("warning", "Not added: " .. (err or "?"))
      end
    end,
  })
end

local function open_edit(index)
  local cur = S.paths[index]
  if not cur then return end
  State.go("file_explorer", {
    start_path = cur,
    on_select  = function(chosen)
      local ok, err = Store.set_path(current_system(), index, chosen)
      if ok then
        Store.save()
        Notify.show("success", "Updated: " .. chosen)
        State.rescan_roms_async()
      else
        Notify.show("warning", "Not updated: " .. (err or "?"))
      end
    end,
  })
end

local function request_remove(index)
  local p = S.paths[index]
  if not p then return end
  Modal.show("Remove path?",
    p .. "\n\nThe folder itself is not deleted.",
    {
      accept_label = "Remove",
      cancel_label = "Cancel",
      color = {0.90, 0.30, 0.30},
      on_accept = function()
        Store.remove_path(current_system(), index)
        Store.save()
        Notify.show("info", "Removed: " .. p)
        reload()
        State.rescan_roms_async()
      end,
    })
end

local function activate()
  if S.sel > #S.paths then
    open_add()
    return
  end
  open_edit(S.sel)
end

-- ── Input ───────────────────────────────────────────────────
function S.pad(b)
  if     b == IM.A  then activate()
  elseif b == IM.X  and S.sel <= #S.paths then request_remove(S.sel)
  elseif b == IM.Y  then open_add()
  elseif b == IM.L1 then change_system(-1)
  elseif b == IM.R1 then change_system(1) end
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
  elseif k == "x" and S.sel <= #S.paths then request_remove(S.sel)
  elseif k == "y" then open_add() end
end

function S.update(dt)
  S.enter_t = (S.enter_t or 0) + dt
end

-- ── Rendering ───────────────────────────────────────────────
local function draw_tabs(th)
  local x = 20
  local y = 58
  for i, sys in ipairs(SYSTEMS) do
    local active = (i == S.sys_idx)
    local c = sys.color
    local w = 160
    love.graphics.setColor(
      active and c[1]*0.35 or 0.08,
      active and c[2]*0.35 or 0.09,
      active and c[3]*0.35 or 0.12, 0.95)
    love.graphics.rectangle("fill", x, y, w, 26, 4, 4)
    love.graphics.setColor(active and {1,1,1} or th.text_dim)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.printf(sys.label, x, y + 6, w, "center")
    if active then
      love.graphics.setColor(c)
      D.rough_rect(x, y, w, 26,
        { jitter = 0.6, thickness = 1.8, seed = i * 7 })
      D.corner_brackets(x, y, w, 26, c, 6)
    end
    x = x + w + 8
  end
end

local function draw_path_row(p, i, focused, y)
  local th = State.theme
  local c = current_color()
  local x, w, h = 20, W - 40, 44

  if focused then D.glow(x + w/2, y + h/2, 60, c, 0.8) end

  love.graphics.setColor(
    focused and c[1]*0.28 or c[1]*0.10,
    focused and c[2]*0.28 or c[2]*0.10,
    focused and c[3]*0.28 or c[3]*0.10, 0.95)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)

  love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.55)
  love.graphics.rectangle("fill", x, y, 3, h)

  love.graphics.setColor(c)
  D.rough_rect(x, y, w, h,
    { jitter = focused and 1.2 or 0.8,
      thickness = focused and 2.5 or 1.5, seed = i * 11, cut = 12 })

  Icons.draw("library", x + 14, y + 10, 22, c)

  love.graphics.setColor(focused and {1,1,1} or th.text)
  love.graphics.setFont(A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10))
  local disp = p
  local font = love.graphics.getFont()
  while font:getWidth(disp) > w - 100 and #disp > 8 do
    disp = "…" .. disp:sub(5)
  end
  love.graphics.print(disp, x + 46, y + 8)

  if focused then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.print("[A] Edit   [X] Remove", x + 46, y + 25)
  end
end

local function draw_add_row(focused, y)
  local th = State.theme
  local c = current_color()
  local x, w, h = 20, W - 40, 44

  if focused then D.glow(x + w/2, y + h/2, 60, c, 0.8) end

  love.graphics.setColor(
    focused and c[1]*0.28 or 0.05,
    focused and c[2]*0.28 or 0.06,
    focused and c[3]*0.28 or 0.09, 0.95)
  love.graphics.rectangle("fill", x, y, w, h, 4, 4)

  love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.35)
  love.graphics.setLineWidth(1.8)
  love.graphics.rectangle("line", x, y, w, h, 4, 4)
  love.graphics.setLineWidth(1)

  love.graphics.setColor(c)
  love.graphics.setFont(A.font(th.font_body_bold, 18))
  love.graphics.print("+", x + 18, y + 9)

  love.graphics.setColor(focused and {1,1,1} or th.text)
  love.graphics.setFont(A.font(th.font_body_bold, 12))
  love.graphics.print("Add new path…", x + 46, y + 12)
end

function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  Header.draw("ROM PATHS", "settings")

  draw_tabs(th)

  local y = 98
  if #S.paths == 0 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.printf("No paths configured for " .. system_label(),
      0, 110, W, "center")
    y = 140
  else
    for i, p in ipairs(S.paths) do
      local focused = (S.sel == i)
      draw_path_row(p, i, focused, y)
      y = y + 48
    end
  end

  -- Add row
  draw_add_row(S.sel > #S.paths, y)

  BI.draw_hint_centered(
    "[↑↓] Nav   [A] Edit   [X] Remove   [Y] Add   [L1/R1] System   [B] Back",
    W, H - 22, A.font(th.font_body, 11), th)

  Modal.draw()
end

return S