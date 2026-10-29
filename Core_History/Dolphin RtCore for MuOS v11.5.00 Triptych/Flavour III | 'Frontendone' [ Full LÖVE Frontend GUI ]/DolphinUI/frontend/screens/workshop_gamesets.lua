-- screens/workshop_gamesets.lua — per-game settings manager.
-- Two-level UI:
--   Level 1: game IDs with config count
--   Level 2: config variants for one game (active is highlighted)
--
-- Actions on level 2:
--   A      → set as active (copied to dolphin-emu before next launch)
--   X      → rename
--   Y      → delete (with confirm)
--   START  → create new config (from active, or blank)
--
-- v0.5.1 — emoji cleanup
--   * Replaced the 📁 emoji in the level-2 header with a procedural
--     library icon (Icons.draw). The emoji has no glyph in Oxanium.ttf
--     or GameCube.ttf, so on device it rendered as a white box.

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
local GM     = require("gameset_manager")

local S = {}
local W, H = 640, 480

S.level    = 1
S.games    = {}
S.configs  = {}
S.sel      = 1
S.game_id  = nil
S.input    = nil
S.enter_t  = 0

local function reload_level1()
  S.games = GM.list_game_ids()
  S.sel = math.max(1, math.min(#S.games, S.sel))
end

local function reload_level2()
  if not S.game_id then
    S.configs = {}
    return
  end
  S.configs = GM.list_configs(S.game_id)
  S.sel = math.max(1, math.min(#S.configs, S.sel))
end

local function reload()
  if S.level == 1 then reload_level1() else reload_level2() end
end

-- ── Lifecycle ───────────────────────────────────────────────
function S.enter()
  S.level = 1
  S.sel = 1
  S.game_id = nil
  S.input = nil
  S.enter_t = 0
  reload_level1()
  State.raw_input = true
end

function S.leave()
  State.raw_input = false
end

function S.re_enter()
  State.raw_input = true
  if S.level == 1 then reload_level1() else reload_level2() end
end

-- ── Input handling ──────────────────────────────────────────
local function open_text_input(label, initial, on_commit)
  S.input = { label = label, buffer = initial or "", on_commit = on_commit }
  SFX.play("menu_select")
end

local function close_input()
  S.input = nil
  SFX.play("menu_back")
end

local function commit_input()
  if not S.input then return end
  local text = S.input.buffer
  local cb   = S.input.on_commit
  S.input = nil
  SFX.play("menu_select")
  if cb then cb(text) end
end

-- ── Actions level 1 ─────────────────────────────────────────
local function enter_game()
  local g = S.games[S.sel]
  if not g then return end
  S.game_id = g.id
  S.level = 2
  S.sel = 1
  reload_level2()
  SFX.play("menu_select")
end

-- ── Actions level 2 ─────────────────────────────────────────
local function set_active()
  local c = S.configs[S.sel]
  if not c or not S.game_id then return end
  if c.is_active then return end
  if GM.set_active(S.game_id, c.filename) then
    Notify.show("success", "Active: " .. (c.label or c.filename))
  else
    Notify.show("error", "Cannot set active")
  end
  reload_level2()
end

local function rename_focused()
  local c = S.configs[S.sel]
  if not c or not S.game_id then return end
  open_text_input("Rename config",
    c.label or c.filename,
    function(text)
      if text == "" then return end
      local ok, err = GM.rename_config(S.game_id, c.filename, text)
      if ok then
        Notify.show("success", "Renamed")
      else
        Notify.show("error", "Rename: " .. (err or "?"))
      end
      reload_level2()
    end)
end

local function delete_focused()
  local c = S.configs[S.sel]
  if not c or not S.game_id then return end
  Modal.show("Delete config?",
    (c.label or c.filename) ..
    "\n\nThe file will be removed. This cannot be undone.",
    {
      accept_label = "Delete",
      cancel_label = "Cancel",
      color = {0.90, 0.30, 0.30},
      on_accept = function()
        local ok = GM.delete_config(S.game_id, c.filename)
        if ok then
          Notify.show("info", "Deleted")
        else
          Notify.show("error", "Delete failed")
        end
        reload_level2()
      end,
    })
end

local function create_new()
  if not S.game_id then return end

  local src = nil
  local c = S.configs[S.sel]
  if c then src = c.filename end

  open_text_input("New config label", "", function(text)
    if text == "" then return end
    local ok, err = GM.new_config(S.game_id, text, src)
    if ok then
      Notify.show("success", "Created: " .. text)
    else
      Notify.show("error", "Create: " .. (err or "?"))
    end
    reload_level2()
  end)
end

-- ── Input dispatch ──────────────────────────────────────────
local function move(delta)
  local n = (S.level == 1) and #S.games or #S.configs
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.sel + delta))
  if ni ~= S.sel then
    S.sel = ni
    SFX.play("menu_move")
  end
end

local function go_back()
  if S.level == 2 then
    S.level = 1
    S.game_id = nil
    S.sel = 1
    reload_level1()
    SFX.play("menu_back")
  else
    State.raw_input = false
    State.back()
  end
end

function S.pad(b)
  if S.input then
    if b == IM.A then commit_input()
    elseif b == IM.B then close_input() end
    return
  end

  if S.level == 1 then
    if b == IM.A then enter_game()
    elseif b == IM.B then go_back() end
    return
  end

  if     b == IM.A     then set_active()
  elseif b == IM.X     then rename_focused()
  elseif b == IM.Y     then delete_focused()
  elseif b == IM.START then create_new()
  elseif b == IM.B     then go_back() end
end

function S.hat(dir)
  if S.input then return end
  if     dir == "up"   then move(-1)
  elseif dir == "down" then move(1) end
end

function S.key(k)
  if S.input then
    if k == "backspace" then
      S.input.buffer = S.input.buffer:sub(1, -2)
    elseif k == "return" then
      commit_input()
    elseif k == "escape" then
      close_input()
    elseif #k == 1 and k:match("[%w_%-%s%.]") then
      S.input.buffer = S.input.buffer .. k
    end
    return
  end

  if k == "up" then move(-1)
  elseif k == "down" then move(1)
  elseif k == "return" or k == "space" then
    if S.level == 1 then enter_game() else set_active() end
  elseif k == "escape" then
    go_back()
  end
end

function S.update(dt)
  S.enter_t = (S.enter_t or 0) + dt
end

-- ── Rendering: level 1 ──────────────────────────────────────
local function draw_games(th)
  if #S.games == 0 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 12))
    love.graphics.printf(
      "No per-game overrides found.\n\n" ..
      "Create them from the GameSettings editor,\n" ..
      "or import from games_data.json.",
      0, 200, W, "center")
    return
  end

  local y = 92
  local t = State.t_ui or 0
  for i, g in ipairs(S.games) do
    local focused = (i == S.sel)
    local x, w, h = 20, W - 40, 58
    local c = (g.system == "Wii") and {0.20, 0.72, 0.98} or {0.30, 0.80, 0.60}

    if focused then
      local pulse = 0.5 + 0.5 * math.sin(t * 4)
      D.glow(x + w/2, y + h/2, 60, c, 0.7 + pulse * 0.2)
    end
    love.graphics.setColor(focused and c[1]*0.30 or c[1]*0.11,
                           focused and c[2]*0.30 or c[2]*0.11,
                           focused and c[3]*0.30 or c[3]*0.11, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.55)
    love.graphics.rectangle("fill", x, y, 3, h)

    love.graphics.setColor(c)
    D.rough_rect(x, y, w, h,
      { jitter = focused and 1.2 or 0.8,
        thickness = focused and 2.5 or 1.5, seed = i * 11, cut = 12 })

    Icons.draw("save", x + 14, y + 18, 22, c)

    love.graphics.setColor(focused and {1,1,1} or th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 13))
    local name = g.name or g.id
    if #name > 42 then name = name:sub(1, 40) .. "…" end
    love.graphics.print(name, x + 46, y + 8)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print(
      string.format("%s · %s · %s · %d config(s)",
        g.id, g.system, g.region ~= "" and g.region or "—", g.count or 0),
      x + 46, y + 30)

    if g.active and g.active ~= "" then
      local badge = "● " ..
        (g.active:gsub("^" .. g.id .. "%.ini%.?", "") or "default")
      if badge == "● " then badge = "● default" end
      local font = A.font(th.font_body_bold, 9)
      love.graphics.setFont(font)
      local bw = font:getWidth(badge) + 12
      love.graphics.setColor(0.30, 0.80, 0.40, 0.85)
      love.graphics.rectangle("fill", x + w - bw - 10, y + 12, bw, 16, 8, 8)
      love.graphics.setColor(0, 0, 0, 0.9)
      love.graphics.printf(badge, x + w - bw - 10, y + 14, bw, "center")
    end

    y = y + h + 6
  end
end

-- ── Rendering: level 2 ──────────────────────────────────────
local function draw_configs(th)
  if #S.configs == 0 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 12))
    love.graphics.printf(
      "No configs for this game yet.\n\n" ..
      "Press [START] to create one.",
      0, 220, W, "center")
    return
  end

  local y = 118
  local t = State.t_ui or 0
  for i, c in ipairs(S.configs) do
    local focused = (i == S.sel)
    local x, w, h = 20, W - 40, 52
    local accent = c.is_active and {0.30, 0.85, 0.40} or {0.55, 0.55, 0.70}

    if focused then
      local pulse = 0.5 + 0.5 * math.sin(t * 4)
      D.glow(x + w/2, y + h/2, 55, accent, 0.7 + pulse * 0.2)
    end
    love.graphics.setColor(focused and accent[1]*0.28 or accent[1]*0.10,
                           focused and accent[2]*0.28 or accent[2]*0.10,
                           focused and accent[3]*0.28 or accent[3]*0.10, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    love.graphics.setColor(accent[1], accent[2], accent[3],
      focused and 0.95 or 0.55)
    love.graphics.rectangle("fill", x, y, 3, h)

    love.graphics.setColor(accent)
    D.rough_rect(x, y, w, h,
      { jitter = focused and 1.2 or 0.8,
        thickness = focused and 2.5 or 1.5, seed = i * 13, cut = 12 })

    Icons.draw("save", x + 14, y + 15, 22, accent)

    love.graphics.setColor(focused and {1,1,1} or th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 12))
    local lbl = c.label or c.filename
    if #lbl > 44 then lbl = lbl:sub(1, 42) .. "…" end
    love.graphics.print(lbl, x + 46, y + 6)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10))
    love.graphics.print(
      string.format("%s · %d B", c.filename, c.size or 0),
      x + 46, y + 26)

    if c.is_active then
      local badge = "● ACTIVE"
      local font = A.font(th.font_body_bold, 9)
      love.graphics.setFont(font)
      local bw = font:getWidth(badge) + 12
      love.graphics.setColor(0.30, 0.80, 0.40, 0.9)
      love.graphics.rectangle("fill", x + w - bw - 10, y + 12, bw, 16, 8, 8)
      love.graphics.setColor(0, 0, 0, 0.9)
      love.graphics.printf(badge, x + w - bw - 10, y + 14, bw, "center")
    end

    y = y + h + 5
  end
end

-- ── Rendering: input overlay ────────────────────────────────
local function draw_input_overlay(th)
  if not S.input then return end
  local bw, bh = 460, 130
  local bx = (W - bw) / 2
  local by = (H - bh) / 2

  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, 0, W, H)

  love.graphics.setColor(0.06, 0.07, 0.10, 0.98)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
  love.graphics.setColor(th.focus)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
  love.graphics.setLineWidth(1)

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.print(S.input.label or "Value", bx + 20, by + 16)

  love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.12)
  love.graphics.rectangle("fill", bx + 16, by + 40, bw - 32, 34, 4, 4)
  love.graphics.setColor(th.text)
  love.graphics.setFont(A.font(th.font_body_bold, 14))
  local cursor = (math.floor((State.t_ui or 0) * 2) % 2 == 0) and "_" or " "
  love.graphics.print(S.input.buffer .. cursor, bx + 28, by + 48)

  BI.draw_hint_centered("[Enter] OK   [Esc] Cancel",
    W, by + bh + 8, A.font(th.font_body, 11), th)
end

function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  Header.draw("GAMESETTINGS", "save")

  if S.level == 1 then
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print("Games with overrides — press [A] to enter", 20, 62)

    if #S.games > 0 then
      love.graphics.setFont(A.font(th.font_body_bold, 10))
      love.graphics.setColor(0.55, 0.58, 0.68)
      love.graphics.printf(("%d game(s)"):format(#S.games),
        0, 62, W - 20, "right")
    end
  else
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", 20, 60, W - 40, 26, 4, 4)
    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.45)
    love.graphics.rectangle("line", 20, 60, W - 40, 26, 4, 4)

    local g = nil
    for _, gg in ipairs(S.games) do
      if gg.id == S.game_id then g = gg break end
    end
    local title = (g and g.name) or S.game_id or "?"

    -- Procedural library icon in place of the old 📁 emoji, which
    -- has no glyph in Oxanium.ttf / GameCube.ttf.
    Icons.draw("library", 30, 64, 18, th.accent)

    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 12))
    love.graphics.print(S.game_id .. "  ·  " .. title, 54, 65)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.printf(("%d config(s)"):format(#S.configs),
      0, 65, W - 30, "right")

    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print(
      "A = set active   X = rename   Y = delete   START = new",
      20, 94)
  end

  if S.level == 1 then draw_games(th) else draw_configs(th) end

  if not S.input then
    local hints
    if S.level == 1 then
      hints = "[↑↓] Navigate   [A] Enter   [B] Back"
    else
      hints = "[↑↓] Navigate   [A] Activate   [X] Rename   [Y] Delete   " ..
              "[START] New   [B] Back"
    end
    BI.draw_hint_centered(hints, W, H - 22, A.font(th.font_body, 11), th)
  end

  draw_input_overlay(th)
  Modal.draw()
end

return S