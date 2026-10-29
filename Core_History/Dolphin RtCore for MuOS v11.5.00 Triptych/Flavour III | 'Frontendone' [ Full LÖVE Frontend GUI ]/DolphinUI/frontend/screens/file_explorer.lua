-- screens/file_explorer.lua — "File Grid-Diver"
-- Grid-based folder picker for choosing ROM paths.
--
-- Enter with:
--   State.go("file_explorer", {
--       start_path = "/mnt/sdcard",
--       on_select  = function(chosen_path) ... end,
--   })
--
-- Controls:
--   D-pad     navigate grid
--   A         enter focused folder
--   B         go up one level (or cancel if at root)
--   Y         select CURRENT folder (finish)
--   START     select CURRENT folder (alt)
--   L1 / R1   jump 4 pages up / down
--
-- State.raw_input is set true in enter() so that B is delivered to
-- S.pad instead of being consumed by main.lua as a global "back".
--
-- Header title image: assets/images/menu/screen_titles/file_griddiver.png

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

local TOP_Y     = 92
local BOTTOM_Y  = H - 42
local COLS      = 4
local ROWS_VIS  = 3
local TILE_W    = 138
local TILE_H    = 100
local TILE_GAP  = 8
local GRID_X    = (W - (COLS * TILE_W + (COLS - 1) * TILE_GAP)) / 2

S.path       = "/mnt"
S.folders    = {}
S.focus      = 1
S.scroll     = 0
S.on_select  = nil
S.enter_t    = 0
S.locked     = false

local function shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function normalize(p)
  if not p or p == "" then return "/" end
  p = p:gsub("/+$", "")
  if p == "" then return "/" end
  return p
end

local function parent_of(p)
  p = normalize(p)
  if p == "/" then return "/" end
  local par = p:match("^(.+)/[^/]+$")
  if not par or par == "" then return "/" end
  return par
end

local function is_dir(p)
  local h = io.popen('timeout 1 [ -d ' .. shq(p) .. ' ] && echo 1 2>/dev/null')
  if not h then return false end
  local r = h:read("*a"); h:close()
  return r:match("1") ~= nil
end

local function ensure_valid(p)
  p = normalize(p)
  while p ~= "/" and not is_dir(p) do
    p = parent_of(p)
  end
  if not is_dir(p) then p = "/mnt" end
  if not is_dir(p) then p = "/" end
  return p
end

local function list_dirs(path)
  local out = {}
  local cmd = "timeout 2 find -L " .. shq(path) ..
              " -maxdepth 1 -mindepth 1 -type d 2>/dev/null"
  local h = io.popen(cmd)
  if not h then return out end
  for line in h:lines() do
    local name = line:match("([^/]+)$")
    if name and name ~= "" and name:sub(1, 1) ~= "." then
      table.insert(out, { name = name, path = line })
    end
  end
  h:close()
  table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
  return out
end

function S.enter(params)
  params = params or {}
  S.on_select = params.on_select
  S.path      = ensure_valid(params.start_path or "/mnt")
  S.folders   = list_dirs(S.path)
  S.focus     = 1
  S.scroll    = 0
  S.enter_t   = 0
  S.locked    = false
  State.raw_input = true
end

function S.leave()
  State.raw_input = false
  S.locked = true
end

function S.re_enter()
  State.raw_input = true
  S.locked = false
  S.folders = list_dirs(S.path)
  S.enter_t = 0
end

local function clamp_scroll()
  local vis = COLS * ROWS_VIS
  local f = S.focus - 1
  local page_top = math.floor(f / vis) * vis
  S.scroll = page_top
end

local function move(dx, dy)
  local n = #S.folders
  if n == 0 then return end
  local fx = (S.focus - 1) % COLS
  local fy = math.floor((S.focus - 1) / COLS)
  local nx = math.max(0, math.min(COLS - 1, fx + dx))
  local ny = math.max(0, fy + dy)
  local ni = ny * COLS + nx + 1
  if ni > n then ni = n end
  if ni ~= S.focus then
    S.focus = ni
    SFX.play("menu_move")
    clamp_scroll()
  end
end

local function enter_dir()
  local f = S.folders[S.focus]
  if not f then return end
  S.path = f.path
  S.folders = list_dirs(S.path)
  S.focus = 1
  S.scroll = 0
  S.enter_t = 0
  SFX.play("menu_select")
end

local function go_up()
  if S.path == "/" then
    State.raw_input = false
    State.back()
    return
  end
  local parent = parent_of(S.path)
  S.path = parent
  S.folders = list_dirs(S.path)
  S.focus = 1
  S.scroll = 0
  S.enter_t = 0
  SFX.play("menu_back")
end

local function select_current()
  if S.locked then return end
  S.locked = true
  local cb   = S.on_select
  local path = S.path
  SFX.play("menu_flip")
  State.raw_input = false
  State.back()
  if cb then pcall(cb, path) end
end

function S.pad(b)
  if S.locked then return end
  if     b == IM.A     then enter_dir()
  elseif b == IM.Y     then select_current()
  elseif b == IM.START then select_current()
  elseif b == IM.B     then go_up() end
end

function S.hat(dir)
  if S.locked then return end
  if     dir == "up"    then move(0, -1)
  elseif dir == "down"  then move(0,  1)
  elseif dir == "left"  then move(-1, 0)
  elseif dir == "right" then move( 1, 0) end
end

function S.key(k)
  if S.locked then return end
  if     k == "up"    then move(0, -1)
  elseif k == "down"  then move(0,  1)
  elseif k == "left"  then move(-1, 0)
  elseif k == "right" then move( 1, 0)
  elseif k == "return" or k == "space" then enter_dir()
  elseif k == "y" then select_current()
  elseif k == "backspace" then go_up()
  elseif k == "escape" then
    State.raw_input = false
    State.back()
  end
end

function S.update(dt)
  S.enter_t = (S.enter_t or 0) + dt
end

local function draw_breadcrumb(th)
  local y = 62
  love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
  love.graphics.rectangle("fill", 16, y, W - 32, 24, 3, 3)
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.45)
  love.graphics.rectangle("line", 16, y, W - 32, 24, 3, 3)

  local txt = S.path
  local font = A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10)
  love.graphics.setFont(font)
  while font:getWidth(txt) > W - 60 and #txt > 6 do
    txt = "…" .. txt:sub(5)
  end

  love.graphics.setColor(th.text)
  love.graphics.print("📁 " .. txt, 26, y + 6)
end

local function draw_tile(f, i, focused, x, y, th, t)
  local stagger = (i - 1) * 0.025
  local ease = math.max(0, math.min(1, ((S.enter_t or 0) - stagger) / 0.25))
  ease = 1 - (1 - ease) ^ 3
  if ease <= 0.01 then return end

  local sx = x + (1 - ease) * 20
  local sy = y + (1 - ease) * 12

  local c = focused and th.focus or {0.35, 0.55, 0.85}
  local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 4 + i * 0.4)

  if focused then
    D.glow(sx + TILE_W/2, sy + TILE_H/2, 70 + pulse * 20, c, 1.0)
  end

  love.graphics.setColor(
    focused and c[1]*0.28 or 0.06,
    focused and c[2]*0.28 or 0.07,
    focused and c[3]*0.28 or 0.10,
    ease * 0.98)
  love.graphics.rectangle("fill", sx, sy, TILE_W, TILE_H, 6, 6)

  if focused then
    love.graphics.setColor(1, 1, 1, (0.5 + pulse * 0.5) * ease)
    D.rough_rect(sx - 2, sy - 2, TILE_W + 4, TILE_H + 4,
      { jitter = 1.2, thickness = 2, seed = i * 11 })
    love.graphics.setColor(c[1], c[2], c[3], ease)
    D.rough_rect(sx, sy, TILE_W, TILE_H,
      { jitter = 1.0, thickness = 2.5, seed = i * 13, cut = 10 })
    D.corner_brackets(sx, sy, TILE_W, TILE_H, c, 10)
  else
    love.graphics.setColor(c[1], c[2], c[3], 0.5 * ease)
    D.rough_rect(sx, sy, TILE_W, TILE_H,
      { jitter = 0.7, thickness = 1.2, seed = i * 13, cut = 10 })
  end

  local ix = sx + TILE_W/2
  local iy = sy + 36
  love.graphics.setColor(c[1], c[2], c[3], 0.9 * ease)
  love.graphics.rectangle("fill", ix - 22, iy - 12, 44, 26, 3, 3)
  love.graphics.rectangle("fill", ix - 22, iy - 16, 20, 6, 2, 2)
  love.graphics.setColor(0, 0, 0, 0.25 * ease)
  love.graphics.rectangle("fill", ix - 20, iy - 10, 40, 2, 1, 1)

  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.setColor(focused and {1,1,1} or th.text)
  local name = f.name
  if #name > 16 then name = name:sub(1, 15) .. "…" end
  love.graphics.printf(name, sx, sy + TILE_H - 24, TILE_W, "center")
end

local function draw_empty(th)
  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 12))
  love.graphics.printf(
    "No subfolders.\n\nPress [Y] to select this folder.",
    0, H/2 - 20, W, "center")
end

function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  -- Third arg: title image key in assets/images/menu/screen_titles/
  Header.draw("FILE GRID-DIVER", "library", "file_griddiver")

  draw_breadcrumb(th)

  if #S.folders == 0 then
    draw_empty(th)
  else
    love.graphics.setScissor(0, TOP_Y, W, BOTTOM_Y - TOP_Y)

    local visible_top = S.scroll
    local visible_count = COLS * ROWS_VIS
    for idx = visible_top + 1,
        math.min(#S.folders, visible_top + visible_count) do
      local f = S.folders[idx]
      local rel = idx - visible_top - 1
      local col = rel % COLS
      local row = math.floor(rel / COLS)
      local x = GRID_X + col * (TILE_W + TILE_GAP)
      local y = TOP_Y + row * (TILE_H + TILE_GAP)
      draw_tile(f, idx, idx == S.focus, x, y, th, State.t_ui)
    end

    love.graphics.setScissor()

    if #S.folders > COLS * ROWS_VIS then
      local pages = math.ceil(#S.folders / (COLS * ROWS_VIS))
      local cur   = math.floor(S.scroll / (COLS * ROWS_VIS)) + 1
      love.graphics.setFont(A.font(th.font_body_bold, 9))
      love.graphics.setColor(th.text_dim)
      love.graphics.printf(
        ("page %d/%d"):format(cur, pages),
        0, BOTTOM_Y + 4, W - 14, "right")
    end
  end

  BI.draw_hint_centered(
    ("[A] Enter   [B] Up   [Y] Select THIS folder   ·   %d folders")
    :format(#S.folders),
    W, H - 22, A.font(th.font_body, 11), th)
end

return S