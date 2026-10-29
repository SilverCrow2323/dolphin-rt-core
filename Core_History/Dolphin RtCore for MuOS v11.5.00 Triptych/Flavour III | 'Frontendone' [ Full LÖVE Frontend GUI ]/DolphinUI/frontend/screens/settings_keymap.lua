-- frontend/screens/settings_keymap.lua — keyboard remapping UI.
-- Two views: GAMEPAD (pad icons per action) and KEYBOARD (bound key icons).
-- Y toggles view, A opens capture popup with 5s countdown.
--
-- Input model:
--   * State.raw_input is held true for the whole lifetime of this screen
--     so that B is delivered to S.pad. S.pad now handles B explicitly.
--   * While the capture popup is open, State.capture_mode = true so
--     main.lua routes raw pad/key events to this screen without any
--     translation. This lets the user bind keys that would otherwise be
--     intercepted (B, SELECT, START, ...).

local A       = require("assets")
local SFX     = require("sfx")
local State   = require("state")
local IM      = require("input_map")
local D       = require("ui.draw")
local BG      = require("ui.bg")
local Header  = require("ui.header")
local Icons   = require("ui.icons")
local BI      = require("ui.button_icons")
local KI      = require("ui.keyboard_icons")
local KB      = require("key_bindings")
local Notify  = require("notify")
local Modal   = require("modal")

local S = {}
local W, H = 640, 480

local TOP_Y     = Header.height() + 8
local BOTTOM_Y  = H - 40
local ROW_H     = 32

S.view     = "gamepad"
S.sel      = 1
S.scroll   = 0
S.capture  = nil
local CAPTURE_DUR = 5.0

function S.enter()
  S.sel = math.max(1, math.min(#KB.actions(), S.sel or 1))
  S.scroll = 0
  S.view = S.view or "gamepad"
  S.capture = nil
  State.capture_mode = false
  State.raw_input = true
end

function S.leave()
  State.raw_input = false
  State.capture_mode = false
end

function S.re_enter()
  State.raw_input = true
  State.capture_mode = false
end

local function actions() return KB.actions() end

local function ensure_visible()
  local vis_h = BOTTOM_Y - TOP_Y
  local y0 = (S.sel - 1) * ROW_H
  if y0 < S.scroll then S.scroll = y0
  elseif y0 + ROW_H > S.scroll + vis_h then
    S.scroll = y0 + ROW_H - vis_h
  end
end

local function move(delta)
  local n = #actions()
  if n == 0 then return end
  local ni = math.max(1, math.min(n, S.sel + delta))
  if ni ~= S.sel then
    S.sel = ni
    SFX.play("menu_move")
    ensure_visible()
  end
end

local function toggle_view()
  S.view = (S.view == "gamepad") and "keyboard" or "gamepad"
  SFX.play("menu_toggleoption")
end

local function open_capture()
  local a = actions()[S.sel]
  if not a then return end
  S.capture = {
    action_id = a.id,
    label = a.label,
    t = 0,
    dur = CAPTURE_DUR,
    sfx_played = false,
  }
  State.capture_mode = true
  SFX.play("menu_select")
end

local function close_capture()
  S.capture = nil
  State.capture_mode = false
  SFX.play("menu_back")
end

local function commit_capture(key)
  if not S.capture then return end
  local action_id = S.capture.action_id
  if KB.set(action_id, key) then
    Notify.show("success", ("%s  →  %s"):format(S.capture.label, key))
    SFX.play("menu_toggleoption")
  end
  S.capture = nil
  State.capture_mode = false
end

function S.pad(b)
  if S.capture then
    -- Durante capture_mode main.lua passa il raw button number.
    -- IM.B e' la stringa "b", quindi non basta: serve anche il raw 4.
    if b == IM.B or b == 4 then close_capture() end
    return
  end
  if b == IM.A then open_capture()
  elseif b == IM.Y then toggle_view()
  elseif b == IM.B then
    State.raw_input = false
    State.back()
  end
end

function S.hat(dir)
  if S.capture then return end
  if dir == "up" then move(-1)
  elseif dir == "down" then move(1) end
end

function S.key(k)
  if S.capture then
    if k == "escape" then close_capture()
    else commit_capture(k) end
    return
  end
  if k == "up" then move(-1)
  elseif k == "down" then move(1)
  elseif k == "return" or k == "space" then open_capture()
  elseif k == "y" then toggle_view()
  elseif k == "escape" then
    State.raw_input = false
    State.back()
  end
end

function S.update(dt)
  if S.capture then
    S.capture.t = S.capture.t + dt
    if not S.capture.sfx_played and S.capture.t > 0.15 then
      S.capture.sfx_played = true
      SFX.play("menu_flip")
    end
    if S.capture.t >= S.capture.dur then
      close_capture()
    end
  end
end

-- ── Row rendering ─────────────────────────────────────────────
local function draw_row(th, a, i, y, focused)
  local x, w, h = 24, W - 48, ROW_H - 4
  local accent = {0.20, 0.72, 0.98}

  if focused then
    local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 4)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.18)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(accent[1], accent[2], accent[3],
      0.55 + pulse * 0.35)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    love.graphics.setLineWidth(1)
  end

  love.graphics.setColor(focused and {1, 1, 1} or th.text)
  love.graphics.setFont(A.font(th.font_body_bold, 13))
  love.graphics.print(a.label, x + 12, y + math.floor((h - 16) / 2))

  local pad_size = 20
  local key_h = 20

  if S.view == "gamepad" then
    local px = x + w - 12 - pad_size
    BI.draw(th, a.pad_equiv, px, y + (h - pad_size) / 2, pad_size)
  else
    local key = KB.get(a.id)
    if key then
      local kw = KI.width(th, key)
      KI.draw(th, key, x + w - 12 - kw, y + (h - key_h) / 2, key_h)
    else
      love.graphics.setColor(th.text_dim)
      love.graphics.setFont(A.font(th.font_body, 11))
      love.graphics.printf("(unbound)", x, y + 6, w - 12, "right")
    end
  end
end

-- ── Capture popup (cyberpunk HUD) ─────────────────────────────
local function draw_capture(th)
  local c = S.capture
  if not c then return end

  local ease = math.min(1, c.t / 0.22)
  ease = 1 - (1 - ease)^3

  love.graphics.setColor(0, 0, 0, 0.82 * ease)
  love.graphics.rectangle("fill", 0, 0, W, H)

  local bw, bh = 480, 240
  local bx = (W - bw) / 2
  local by = (H - bh) / 2 + (1 - ease) * 40

  local accent = {0.20, 0.90, 1.00}

  D.glow(bx + bw/2, by + bh/2, 260 * ease, accent, 0.55 * ease)

  love.graphics.setColor(0.03, 0.04, 0.07, 0.98 * ease)
  love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)

  love.graphics.setColor(0, 0, 0, 0.15 * ease)
  for yy = by + 4, by + bh - 4, 3 do
    love.graphics.line(bx + 6, yy, bx + bw - 6, yy)
  end

  local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 6)
  love.graphics.setColor(accent[1], accent[2], accent[3], 0.85 * ease)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)
  love.graphics.setColor(accent[1], accent[2], accent[3],
    (0.55 + pulse * 0.45) * ease)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", bx + 4, by + 4, bw - 8, bh - 8, 6, 6)
  love.graphics.setLineWidth(1)

  D.corner_brackets(bx, by, bw, bh, accent, 18)

  love.graphics.setColor(accent[1], accent[2], accent[3], 0.15 * ease)
  love.graphics.rectangle("fill", bx, by, bw, 34, 8, 8)
  love.graphics.setColor(accent)
  love.graphics.setFont(A.font(th.font_body_bold, 12))
  love.graphics.printf(":: REMAP BINDING ::", bx, by + 10, bw, "center")

  love.graphics.setColor(0.85, 0.90, 0.95, ease)
  love.graphics.setFont(A.font(th.font_title, 20))
  love.graphics.printf(c.label, bx, by + 60, bw, "center")

  love.graphics.setColor(accent[1], accent[2], accent[3],
    (0.7 + pulse * 0.3) * ease)
  love.graphics.setFont(A.font(th.font_body_bold, 14))
  love.graphics.printf("Press a key to bind it", bx, by + 100, bw, "center")

  local p = 1 - math.min(1, c.t / c.dur)
  local bar_x, bar_y = bx + 40, by + 150
  local bar_w, bar_h = bw - 80, 10
  love.graphics.setColor(0.10, 0.14, 0.20, ease)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 5, 5)
  love.graphics.setColor(
    p > 0.5 and 0.20 or 0.90,
    p > 0.5 and 0.90 or 0.30,
    p > 0.5 and 0.60 or 0.30, ease)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w * p, bar_h, 5, 5)

  local secs = math.max(0, math.ceil(c.dur - c.t))
  love.graphics.setColor(0.9, 0.95, 1.0, ease)
  love.graphics.setFont(A.font(th.font_body_bold, 13))
  love.graphics.printf(string.format("TIMEOUT IN %d s", secs),
    bx, by + 168, bw, "center")

  BI.draw_hint_centered("[ESC] Cancel", W, by + bh - 18,
    A.font(th.font_body, 10), th)
end

-- ── Main draw ─────────────────────────────────────────────────
function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  Header.draw("KEYMAP", "hotkeys")

  local view_label, view_color
  if S.view == "gamepad" then
    view_label = (State.theme_name == "wii") and "VIEW: WII PAD" or "VIEW: GC PAD"
    view_color = (State.theme_name == "wii")
      and {0.20, 0.72, 0.98} or {0.55, 0.35, 0.95}
  else
    view_label = "VIEW: KEYBOARD"
    view_color = {0.30, 0.80, 0.60}
  end

  local pill_font = A.font(th.font_body_bold, 10)
  love.graphics.setFont(pill_font)
  local tw = pill_font:getWidth(view_label) + 18
  local px = W - tw - 20
  local py = Header.height() + 6
  love.graphics.setColor(view_color[1], view_color[2], view_color[3], 0.35)
  love.graphics.rectangle("fill", px, py, tw, 20, 10, 10)
  love.graphics.setColor(view_color)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", px, py, tw, 20, 10, 10)
  love.graphics.printf(view_label, px, py + 4, tw, "center")

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 10))
  love.graphics.print("[Y] Switch view", 20, py + 6)

  love.graphics.setScissor(0, TOP_Y, W, BOTTOM_Y - TOP_Y)
  local y = TOP_Y - S.scroll
  local list = actions()
  for i, a in ipairs(list) do
    if y + ROW_H >= TOP_Y and y <= BOTTOM_Y then
      draw_row(th, a, i, y, i == S.sel)
    end
    y = y + ROW_H
  end
  love.graphics.setScissor()

  local total_h = #list * ROW_H
  local vis_h = BOTTOM_Y - TOP_Y
  if total_h > vis_h then
    local rail_x = W - 6
    love.graphics.setColor(0.30, 0.30, 0.35, 0.55)
    love.graphics.rectangle("fill", rail_x, TOP_Y, 3, vis_h, 1, 1)
    local ratio = vis_h / total_h
    local bar_h = math.max(20, vis_h * ratio)
    local span = total_h - vis_h
    local bar_y = TOP_Y + (span > 0 and (S.scroll / span) * (vis_h - bar_h) or 0)
    love.graphics.setColor(th.accent)
    love.graphics.rectangle("fill", rail_x, bar_y, 3, bar_h, 1, 1)
  end

  if not S.capture then
    BI.draw_footer(th, {
      { key = "dpad", label = "Navigate" },
      { key = "a",    label = "Remap"    },
      { key = "y",    label = "View"     },
      { key = "b",    label = "Back"     },
    }, W, H - 22, A.font(th.font_body, 12))
  end

  draw_capture(th)
  Modal.draw()
end

return S