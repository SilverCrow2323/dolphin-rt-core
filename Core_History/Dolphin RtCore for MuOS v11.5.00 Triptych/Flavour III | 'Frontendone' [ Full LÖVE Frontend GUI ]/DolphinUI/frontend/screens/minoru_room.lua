-- frontend/screens/minoru_room.lua
-- "Minoru Room" — observation + chat.
--
-- Layout (640x480):
--   Header            y 0..58
--   Minoru's world    y 58..258   (backdrop, avatar, workspace HUD)
--   Chat log          y 258..410  (~10 lines, auto-scrolling)
--   Input field       y 410..452
--   Footer            y 452..480
--
-- Input:
--   * On PC, keyboard letters go straight into the buffer.
--   * Enter sends. Backspace deletes. Escape clears the buffer.
--   * START toggles an on-screen keyboard for controller-only play.
--   * R1 / L1 scroll the chat log.
--   * B exits (back to wherever the room was opened from).
--
-- Responses are classified by minoru/chat.lua and spoken through
-- the engine, so his visor and history react automatically.

local A       = require("assets")
local SFX     = require("sfx")
local State   = require("state")
local IM      = require("input_map")
local D       = require("ui.draw")
local Header  = require("ui.header")
local BI      = require("ui.button_icons")
local Notify  = require("notify")

local Minoru  = require("minoru")
local Chat    = require("minoru.chat")
local Lines   = require("minoru.lines")

local S = {}
local W, H = 640, 480

-- ── Layout ──────────────────────────────────────────────────
local HEADER_H   = 58
local WORLD_H    = 200
local INPUT_H    = 42
local FOOTER_H   = 28
local CHAT_Y     = HEADER_H + WORLD_H
local CHAT_H     = H - HEADER_H - WORLD_H - INPUT_H - FOOTER_H
local INPUT_Y    = CHAT_Y + CHAT_H
local FOOTER_Y   = H - FOOTER_H

-- ── Palette ─────────────────────────────────────────────────
local COL = {
  chat_bg       = {0.03, 0.04, 0.06, 0.96},
  chat_border   = {0.30, 0.85, 1.00, 0.30},
  user_col      = {0.95, 0.82, 0.40},
  minoru_col    = {0.30, 0.85, 1.00},
  sys_col       = {0.55, 0.62, 0.72},
  input_bg      = {0.05, 0.06, 0.09, 0.98},
  input_border  = {0.30, 0.85, 1.00, 0.65},
  input_text    = {0.95, 0.98, 1.00},
  caret         = {0.30, 0.85, 1.00},
}

-- ── Runtime ─────────────────────────────────────────────────
S.minoru         = nil
S.chat_log       = {}          -- { author, text, emotion, t }
S.input_buffer   = ""
S.input_active   = true
S.scroll_offset  = 0            -- 0 = bottom, positive = scrolled up
S.pending        = nil          -- delayed response
S.onscreen_kb    = false
S.kb_pos         = { x = 1, y = 1 }
S._last_logged   = nil
S._blink_t       = 0
S._delayed_queue = {}           -- queue of {t, fn}

local MAX_LOG = 60

-- ── On-screen keyboard layout ───────────────────────────────
local KB_ROWS = {
  { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
  { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" },
  { "A", "S", "D", "F", "G", "H", "J", "K", "L", "_" },
  { "Z", "X", "C", "V", "B", "N", "M", ",", ".", "?" },
  { "SPACE", "DEL", "SEND", "ESC" },
}

-- ── Log helpers ─────────────────────────────────────────────
local function push_log(author, text, emotion)
  table.insert(S.chat_log, {
    author  = author,
    text    = tostring(text or ""),
    emotion = emotion,
    t       = State.t_ui or 0,
  })
  while #S.chat_log > MAX_LOG do
    table.remove(S.chat_log, 1)
  end
  S.scroll_offset = 0   -- snap to bottom
end

-- ── Delayed execution (soft timing) ─────────────────────────
local function delay(seconds, fn)
  table.insert(S._delayed_queue, { t = seconds, fn = fn })
end

local function update_delayed(dt)
  local q = S._delayed_queue
  for i = #q, 1, -1 do
    q[i].t = q[i].t - dt
    if q[i].t <= 0 then
      local fn = q[i].fn
      table.remove(q, i)
      pcall(fn)
    end
  end
end

-- ── Sending a message ───────────────────────────────────────
local function send_message()
  local text = (S.input_buffer or ""):match("^%s*(.-)%s*$")
  S.input_buffer = ""
  if text == "" then return end

  SFX.play("menu_select")
  push_log("you", text)

  -- Log the raw message as a persona event so his history sees it.
  if S.minoru then
    S.minoru:observe("chat_message", { text = text, silent = true })
  end

  local category = Chat.classify(text)
  if not category then return end

  local resp = Chat.respond(category)
  local wait = Chat.think_time(category)

  -- Fire the response after a short delay so it feels considered.
  delay(wait, function()
    if not S.minoru then return end
    if resp.pre then
      S.minoru:say(resp.pre, { silent = true })
    end
    S.minoru:say(resp.main)
    if resp.post then
      S.minoru:say(resp.post)
    end
  end)
end

-- ── Lifecycle ───────────────────────────────────────────────
function S.enter()
  S.chat_log      = {}
  S.input_buffer  = ""
  S.input_active  = true
  S.scroll_offset = 0
  S.pending       = nil
  S.onscreen_kb   = false
  S._delayed_queue = {}

  S.minoru = Minoru.new({
    screen   = "minoru_room",
    form     = "desk_lamp",
    anchors  = { left = 200, center = 320, right = 420 },
    on_say   = function(_, info)
      -- Log what Minoru just said. The engine reports it once per
      -- bubble via the on_say hook.
      if info and info.text and info.text ~= "" then
        push_log("minoru", info.text, info.emotion)
      end
    end,
  })

  -- The world is quiet in a room — disable the auto-idle chatter.
  S.minoru.hold_after_done = 0.35

  push_log("sys", "Minoru Room — type below and press Enter to send.")
  push_log("minoru", "Oh, look. A visitor.", "sarcastic")

  State.raw_input = true
end

function S.leave()
  State.raw_input = false
  if S.minoru then
    S.minoru:flush()
    S.minoru = nil
  end
end

function S.re_enter()
  State.raw_input = true
  -- Returning to the room doesn't reset the log — it's a room,
  -- not a new instance.
end

function S.update(dt)
  S._blink_t = S._blink_t + dt
  update_delayed(dt)
  if S.minoru then
    S.minoru:update(dt)
    -- Suppress the engine's idle autonomous speech in the room:
    -- the room is a conversation, not a monologue.
    if S.minoru.bubble == nil then
      S.minoru._idle_t = 0
    end
  end
end

-- ── Input ───────────────────────────────────────────────────
local function kb_press()
  local row = KB_ROWS[S.kb_pos.y]
  if not row then return end
  local key = row[S.kb_pos.x]
  if not key then return end

  if key == "SPACE" then
    S.input_buffer = S.input_buffer .. " "
    SFX.play("menu_move")
  elseif key == "DEL" then
    S.input_buffer = S.input_buffer:sub(1, -2)
    SFX.play("menu_move")
  elseif key == "SEND" then
    send_message()
    S.onscreen_kb = false
  elseif key == "ESC" then
    S.onscreen_kb = false
    SFX.play("menu_back")
  else
    S.input_buffer = S.input_buffer .. key
    SFX.play("menu_move")
  end
end

local function kb_move(dx, dy)
  local row = KB_ROWS[S.kb_pos.y]
  if not row then return end
  if dx ~= 0 then
    local nx = S.kb_pos.x + dx
    nx = math.max(1, math.min(#row, nx))
    S.kb_pos.x = nx
  end
  if dy ~= 0 then
    local ny = S.kb_pos.y + dy
    ny = math.max(1, math.min(#KB_ROWS, ny))
    S.kb_pos.y = ny
    local newrow = KB_ROWS[ny]
    if S.kb_pos.x > #newrow then S.kb_pos.x = #newrow end
  end
  SFX.play("menu_move")
end

function S.pad(b)
  if S.onscreen_kb then
    if     b == IM.A     then kb_press()
    elseif b == IM.B     then
      S.onscreen_kb = false; SFX.play("menu_back")
    elseif b == IM.START then
      S.onscreen_kb = false; SFX.play("menu_back")
    end
    return
  end

  if     b == IM.START then
    S.onscreen_kb = true
    S.kb_pos = { x = 1, y = 2 }   -- start on the Q row
    SFX.play("menu_select")
  elseif b == IM.Y then
    send_message()
  elseif b == IM.X then
    S.input_buffer = ""
    SFX.play("menu_back")
  elseif b == IM.R1 then
    -- Scroll the chat up.
    S.scroll_offset = math.min(#S.chat_log - 1,
      S.scroll_offset + 3)
    SFX.play("menu_pagescroll")
  elseif b == IM.L1 then
    S.scroll_offset = math.max(0, S.scroll_offset - 3)
    SFX.play("menu_pagescroll")
  elseif b == IM.B then
    State.raw_input = false
    State.back()
  end
end

function S.hat(dir)
  if S.onscreen_kb then
    if     dir == "up"    then kb_move(0, -1)
    elseif dir == "down"  then kb_move(0,  1)
    elseif dir == "left"  then kb_move(-1, 0)
    elseif dir == "right" then kb_move( 1, 0)
    end
  end
end

function S.key(k)
  if S.onscreen_kb then
    if k == "escape" then
      S.onscreen_kb = false
    elseif k == "return" then
      send_message()
      S.onscreen_kb = false
    end
    return
  end

  if k == "return" or k == "kpenter" then
    send_message()
  elseif k == "backspace" then
    S.input_buffer = S.input_buffer:sub(1, -2)
  elseif k == "escape" then
    if #S.input_buffer > 0 then
      S.input_buffer = ""
    else
      State.raw_input = false
      State.back()
    end
  elseif k == "pageup" then
    S.scroll_offset = math.min(#S.chat_log - 1,
      S.scroll_offset + 5)
  elseif k == "pagedown" then
    S.scroll_offset = math.max(0, S.scroll_offset - 5)
  elseif #k == 1 and k:match("[%w%p%s]") then
    S.input_buffer = S.input_buffer .. k
  end
end

-- ══════════════════════════════════════════════════════════════
--  Rendering
-- ══════════════════════════════════════════════════════════════
local function draw_chat(th)
  local y = CHAT_Y
  local h = CHAT_H
  love.graphics.setColor(COL.chat_bg)
  love.graphics.rectangle("fill", 0, y, W, h)
  love.graphics.setColor(COL.chat_border)
  love.graphics.rectangle("line", 0.5, y + 0.5, W - 1, h - 1)

  local font_body = A.font(
    "assets/fonts/Oxanium-Regular.ttf", 11)
  local font_bold = A.font(
    "assets/fonts/Oxanium-Bold.ttf", 11)
  local font_mono = A.font(
    "assets/fonts/JetBrainsMono-Regular.ttf", 10)

  -- Build render lines by wrapping each entry.
  local lines = {}
  for _, entry in ipairs(S.chat_log) do
    local prefix = (entry.author == "you") and "> YOU  "
                or (entry.author == "minoru") and "  MINORU  "
                or "  —  "
    local prefix_w = font_bold:getWidth(prefix) + 8
    local wrap_w   = W - 24 - prefix_w
    local wrapped  = {}
    local remaining = entry.text
    while #remaining > 0 do
      local chunk, rest = remaining:match("^(.-)(%s+%S.*)$")
      if not chunk then
        chunk = remaining
        rest = ""
      end
      if font_body:getWidth(chunk) <= wrap_w then
        table.insert(wrapped, chunk)
        remaining = rest:gsub("^%s+", "")
      else
        -- Hard split
        local cut = 1
        while cut < #remaining and
              font_body:getWidth(remaining:sub(1, cut + 1)) <= wrap_w do
          cut = cut + 1
        end
        table.insert(wrapped, remaining:sub(1, cut))
        remaining = remaining:sub(cut + 1)
      end
    end
    if #wrapped == 0 then wrapped = { "" } end
    for i, w in ipairs(wrapped) do
      table.insert(lines, {
        prefix  = (i == 1) and prefix or string.rep(" ", #prefix),
        text    = w,
        author  = entry.author,
        emotion = entry.emotion,
      })
    end
  end

  local line_h = 15
  local visible = math.floor((h - 8) / line_h)
  local total   = #lines
  local top_idx = math.max(1, total - visible - S.scroll_offset + 1)
  local bottom_idx = math.min(total, top_idx + visible - 1)

  local yy = y + 4
  for i = top_idx, bottom_idx do
    local l = lines[i]
    if not l then break end

    -- Author prefix coloured by role/emotion.
    local pcol
    if l.author == "you" then
      pcol = COL.user_col
    elseif l.author == "minoru" then
      pcol = Lines.emotions[l.emotion or "standard"] or COL.minoru_col
      pcol = { pcol.r, pcol.g, pcol.b }
    else
      pcol = COL.sys_col
    end
    love.graphics.setFont(font_bold)
    love.graphics.setColor(pcol)
    love.graphics.print(l.prefix, 12, yy)

    -- Body text.
    love.graphics.setColor(l.author == "minoru"
      and {0.90, 0.94, 0.98} or {0.85, 0.88, 0.94})
    love.graphics.setFont(font_mono)
    love.graphics.print(l.text, 12 + font_bold:getWidth(l.prefix) + 8, yy + 1)

    yy = yy + line_h
  end

  -- Scroll indicator
  if S.scroll_offset > 0 then
    love.graphics.setColor(0.55, 0.62, 0.72, 0.85)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.printf("[L1/R1] scroll",
      0, y + h - 14, W - 10, "right")
  end
end

local function draw_input(th)
  local y = INPUT_Y
  local h = INPUT_H
  love.graphics.setColor(COL.input_bg)
  love.graphics.rectangle("fill", 0, y, W, h)
  love.graphics.setColor(COL.input_border)
  love.graphics.rectangle("line", 0.5, y + 0.5, W - 1, h - 1)

  -- Label
  love.graphics.setFont(A.font(
    "assets/fonts/Oxanium-Bold.ttf", 9))
  love.graphics.setColor(0.55, 0.65, 0.78)
  love.graphics.print("MESSAGE", 12, y + 6)

  -- Buffer
  local font = A.font(
    "assets/fonts/JetBrainsMono-Regular.ttf", 12)
  love.graphics.setFont(font)
  love.graphics.setColor(COL.input_text)
  local text_x = 70
  love.graphics.print(S.input_buffer, text_x, y + 12)

  -- Blinking caret
  if math.floor(S._blink_t * 2) % 2 == 0 then
    local tw = font:getWidth(S.input_buffer)
    love.graphics.setColor(COL.caret)
    love.graphics.rectangle("fill", text_x + tw + 1, y + 12, 7, 14)
  end

  -- Hint on the right
  love.graphics.setFont(A.font(th.font_body, 9))
  love.graphics.setColor(0.55, 0.65, 0.78)
  love.graphics.printf("[ENTER] send   [START] virtual keyboard",
    0, y + 14, W - 12, "right")
end

local function draw_onscreen_keyboard()
  if not S.onscreen_kb then return end

  local bw, bh = 560, 180
  local bx = (W - bw) / 2
  local by = (H - bh) / 2
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", 0, 0, W, H)
  love.graphics.setColor(0.04, 0.05, 0.09, 0.98)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
  love.graphics.setColor(0.30, 0.85, 1.00, 0.75)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
  love.graphics.setLineWidth(1)

  love.graphics.setColor(0.30, 0.85, 1.00)
  love.graphics.setFont(A.font(
    "assets/fonts/Oxanium-Bold.ttf", 10))
  love.graphics.print("MINORU ROOM  ·  VIRTUAL KEYBOARD", bx + 12, by + 8)

  -- Buffer preview
  love.graphics.setColor(0.05, 0.06, 0.10, 1)
  love.graphics.rectangle("fill", bx + 12, by + 28, bw - 24, 22, 3, 3)
  love.graphics.setColor(0.90, 0.94, 0.98)
  love.graphics.setFont(A.font(
    "assets/fonts/JetBrainsMono-Regular.ttf", 11))
  love.graphics.print(S.input_buffer, bx + 18, by + 32)

  -- Keys
  local key_w = 44
  local key_h = 24
  local gap_x = 4
  local gap_y = 6
  local top = by + 60

  for ry, row in ipairs(KB_ROWS) do
    local total_w = #row * key_w + (#row - 1) * gap_x
    local start_x = bx + (bw - total_w) / 2
    for rx, label in ipairs(row) do
      local kx = start_x + (rx - 1) * (key_w + gap_x)
      local ky = top + (ry - 1) * (key_h + gap_y)
      local focused = (S.kb_pos.x == rx and S.kb_pos.y == ry)

      love.graphics.setColor(
        focused and 0.30 or 0.10,
        focused and 0.70 or 0.12,
        focused and 0.95 or 0.16, 0.98)
      love.graphics.rectangle("fill", kx, ky, key_w, key_h, 3, 3)
      love.graphics.setColor(
        focused and 0.55 or 0.30,
        focused and 0.90 or 0.35,
        focused and 1.00 or 0.42, 0.9)
      love.graphics.rectangle("line", kx, ky, key_w, key_h, 3, 3)

      love.graphics.setColor(focused and {1,1,1} or {0.85,0.90,0.95})
      love.graphics.setFont(A.font(
        "assets/fonts/Oxanium-Bold.ttf", 11))
      love.graphics.printf(label, kx, ky + 6, key_w, "center")
    end
  end

  love.graphics.setColor(0.55, 0.65, 0.78)
  love.graphics.setFont(A.font(
    "assets/fonts/Oxanium-Regular.ttf", 9))
  love.graphics.printf(
    "[D-PAD] navigate   [A] press   [B] close",
    bx, by + bh - 18, bw, "center")
end

function S.draw()
  local th = State.theme
  love.graphics.clear(0.02, 0.03, 0.05)
  Header.draw("MINORU ROOM", "info")

  -- World
  if S.minoru then
    S.minoru:draw(0, HEADER_H, W, WORLD_H)
  end

  draw_chat(th)
  draw_input(th)

  BI.draw_footer(th, {
    { key = "dpad",  label = "Browse"   },
    { key = "a",     label = "Send"     },
    { key = "start", label = "Keyboard" },
    { key = "x",     label = "Clear"    },
    { key = "b",     label = "Leave"    },
  }, W, FOOTER_Y + 6, A.font(th.font_body, 10))

  draw_onscreen_keyboard()
end

return S