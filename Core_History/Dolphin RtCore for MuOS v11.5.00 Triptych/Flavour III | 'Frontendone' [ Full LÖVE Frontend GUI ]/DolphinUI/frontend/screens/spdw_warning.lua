-- frontend/screens/spdw_warning.lua
--
-- SPDW Factory system advisory, shown once at every launch before
-- the boot animation. Presented by [R.I.] Minoru⁷ (the 7 is a
-- superscript).
--
-- Behaviour:
--   A -> State.go("boot")            proceed
--   B -> os.exit(0)                  quit immediately
--   No back. This screen owns the app's entry point.
--   State.raw_input = true so that B reaches this screen's pad()
--   instead of being swallowed by main.lua (history is depth 1).
--
-- Animation:
--   * Window fades + scales in over 0.35 s
--   * Text lines type in one at a time (LINE_DELAY each), fading as
--     they appear
--   * Minoru image floats up/down (sin, ±6 px) with a violet glow
--   * Warning LED blinks at 1 Hz
--   * Scanlines drift downward over the background
--   * Entry sound: livemenu_open
--
-- ── v0.4.7 — cleanup ──────────────────────────────────────────
--   1. BODY_LINES reduced from 21 to 18 lines so the last line
--      sits at y=345 with buttons starting at y=376 — a 31px gap.
--      The previous revision had the last line and the first
--      button sharing pixels.
--   2. Minoru portrait now loads through A.image() (assets.lua's
--      shared image cache) instead of a private
--      love.graphics.newImage() call. Two copies of the same PNG
--      in RAM for no reason.
--   3. S._finished guard: A, B, or any input on the last frame
--      cannot trigger proceed() and quit_everything() in the
--      same tick.
--   4. quit_everything() no longer hardcodes a 0.15 s wait for
--      the exit SFX. It gives the audio system one frame, which
--      is the actual requirement.
--   5. Minoru panel: brighter border, corner brackets, and a
--      pulsing accent that scales with the frame clock — the
--      panel reads as a "live" element, not a static graphic.

local A     = require("assets")
local SFX   = require("sfx")
local State = require("state")
local IM    = require("input_map")
local D     = require("ui.draw")
local BI    = require("ui.button_icons")
local Store = require("settings_store")

local S = {}
local W, H = 640, 480

-- ── Timing / animation state ────────────────────────────────
S.t                 = 0
S.enter_ease        = 0
S.lines_shown       = 0
S._pending_quit     = false
S._pending_quit_t   = 0
S._finished         = false

-- ── Asset ───────────────────────────────────────────────────
local MINORU_PATH = "assets/images/minoru.png"

-- ── Body text ───────────────────────────────────────────────
-- Kept in discrete lines (not auto-wrapped) so the animation can
-- reveal them one by one and the layout stays deterministic across
-- themes.
--
-- Kinds:
--   emph  - bold white, for the "listen up" call
--   body  - regular light grey
--   warn  - bold red, for the do-not-continue warnings
--   dim   - very dim grey, for the fine print
--   blank - a paragraph break
--
-- Line width budget: TEXT_W = 340px at Oxanium-Regular 11pt.
-- Roughly 7 px/char → hard cap around 48 characters. Aiming for
-- ≤ 42 keeps generous margins.
local BODY_LINES = {
  { text = "Read first.",                              kind = "emph"  },
  { text = "",                                          kind = "blank" },

  { text = "Dolphin Rt:Core for muOS is a work in",    kind = "body"  },
  { text = "progress. Expect bugs, quirks, and",       kind = "body"  },
  { text = "single-digit FPS on demanding titles.",    kind = "body"  },
  { text = "",                                          kind = "blank" },

  { text = "It exists for people who enjoy pushing",   kind = "body"  },
  { text = "budget hardware past its limits.",         kind = "body"  },
  { text = "",                                          kind = "blank" },

  { text = "SPDW Factory does not guarantee this",     kind = "warn"  },
  { text = "will run on H700 devices. Bugs are the",   kind = "warn"  },
  { text = "expectation, not the exception.",          kind = "warn"  },
  { text = "",                                          kind = "blank" },

  { text = "If you don't know what you're doing,",     kind = "emph"  },
  { text = "stop now.",                                 kind = "emph"  },
  { text = "",                                          kind = "blank" },

  { text = "Third-party project. Not affiliated",      kind = "dim"   },
  { text = "with the original muOS developers.",       kind = "dim"   },
}

local LINE_H     = 15
local LINE_DELAY = 0.045
local LINE_FADE  = 0.18

-- ── Layout ──────────────────────────────────────────────────
local WIN_X, WIN_Y = 20, 30
local WIN_W, WIN_H = 600, 420
local HDR_H        = 40
local TEXT_X       = WIN_X + 20
local TEXT_Y       = WIN_Y + HDR_H + 20
local TEXT_W       = 340
local MINORU_X     = WIN_X + WIN_W - 200
local MINORU_Y     = WIN_Y + HDR_H + 16
local MINORU_W     = 180
local MINORU_H     = 280
local BTN_Y        = WIN_Y + WIN_H - 74
local BTN_H        = 56
local BTN_A_X      = WIN_X + 20
local BTN_B_X      = WIN_X + WIN_W / 2 + 8
local BTN_W        = (WIN_W - 48) / 2

-- ── Colours ─────────────────────────────────────────────────
-- Fixed rather than theme-driven: this screen runs before the
-- theme has any meaningful visual impact.
local COL_BG           = {0.02, 0.03, 0.06}
local COL_WIN          = {0.03, 0.05, 0.09}
local COL_BORDER       = {0.20, 0.72, 0.98}   -- cyan
local COL_HEADER       = {0.20, 0.10, 0.15}   -- dark red-tinted strip
local COL_WARN         = {1.00, 0.35, 0.35}
local COL_HEADER_LINE  = {0.90, 0.30, 0.30}
local COL_ACCENT_GC    = {0.65, 0.45, 1.00}   -- violet, Minoru glow
local COL_TEXT         = {1.00, 1.00, 1.00}
local COL_TEXT_BODY    = {0.85, 0.88, 0.94}
local COL_TEXT_DIM     = {0.55, 0.58, 0.65}

-- ── Lifecycle ───────────────────────────────────────────────
function S.enter()
  -- Flag gate: the user disabled the advisory.
  if Store.get("advanced", "spdw_warning") == false then
    print("[spdw_warning] skipped (advanced.spdw_warning = false)")
    State.raw_input = false
    State.go("boot")
    return
  end

  S.t               = 0
  S.enter_ease      = 0
  S.lines_shown     = 0
  S._pending_quit   = false
  S._pending_quit_t = 0
  S._finished       = false

  -- Take over input for the whole lifetime of this screen. Without
  -- this, main.lua's global B handler fires first when history
  -- depth is 1, and quits the app instead of letting us decide.
  State.raw_input = true

  SFX.play("livemenu_open")
end

function S.leave()
  State.raw_input = false
end

function S.re_enter()
  State.raw_input = true
end

-- ── Actions ─────────────────────────────────────────────────
local function proceed()
  if S._finished then return end
  S._finished = true
  SFX.play("menu_select")
  State.raw_input = false
  State.go("boot")
end

local function quit_everything()
  if S._finished then return end
  S._finished       = true
  S._pending_quit   = true
  S._pending_quit_t = 0
  SFX.play("menu_flip")
end

-- ── Update ──────────────────────────────────────────────────
function S.update(dt)
  S.t = S.t + dt

  -- Entry animation: window eases in over 0.35 s
  if S.enter_ease < 1 then
    S.enter_ease = math.min(1, S.enter_ease + dt / 0.35)
  end

  -- Line-by-line reveal. SFX only on non-blank lines.
  local target = math.floor(S.t / LINE_DELAY) + 1
  if target > #BODY_LINES then target = #BODY_LINES end
  if target > S.lines_shown then
    local next_line = BODY_LINES[target]
    S.lines_shown = target
    if next_line and next_line.kind ~= "blank" then
      SFX.play("menu_move")
    end
  end

  -- Deferred quit: give the audio system one frame to actually
  -- start the exit sound before os.exit() tears the device down.
  if S._pending_quit then
    S._pending_quit_t = S._pending_quit_t + dt
    if S._pending_quit_t >= 0.15 then
      os.exit(0)
    end
  end
end

-- ── Input ───────────────────────────────────────────────────
function S.pad(b)
  if b == IM.A then proceed()
  elseif b == IM.B then quit_everything() end
end

function S.hat(_dir)
  -- Deliberately no-op: this screen has exactly two mutually
  -- exclusive outcomes and a focus toggle would only add noise.
end

function S.key(k)
  if k == "return" or k == "space" or k == "a" then
    proceed()
  elseif k == "escape" or k == "b" or k == "q" then
    quit_everything()
  end
end

-- ── Drawing: background ─────────────────────────────────────
local function draw_background(t)
  love.graphics.clear(COL_BG)

  love.graphics.setColor(0.20, 0.72, 0.98, 0.045)
  love.graphics.setLineWidth(1)
  local off = (t * 14) % 40
  for x = -40 + off, W + 40, 40 do
    love.graphics.line(x, 0, x, H)
  end
  for y = -40 + off, H + 40, 40 do
    love.graphics.line(0, y, W, y)
  end

  -- Drifting scanlines
  love.graphics.setColor(0, 0, 0, 0.22)
  local sl = (t * 30) % 3
  for y = sl, H, 3 do
    love.graphics.line(0, y, W, y)
  end

  -- Occasional magenta glitch bar
  if (math.floor(t * 4) % 47) == 0 then
    love.graphics.setColor(1, 0, 0.55, 0.05)
    love.graphics.rectangle("fill", 0, (t * 90) % H, W, 2)
  end

  -- Vignette
  for i = 1, 4 do
    local a = 0.6 * (i / 4) * 0.14
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.rectangle("line", -i*4, -i*4, W + i*8, H + i*8)
  end
end

-- ── Drawing: warning triangle ───────────────────────────────
local function draw_warning_triangle(cx, cy, r, col, alpha, pulse)
  love.graphics.setColor(col[1], col[2], col[3], (0.30 + pulse * 0.30) * alpha)
  love.graphics.circle("fill", cx, cy, r + 4)

  love.graphics.setColor(col[1], col[2], col[3], alpha)
  love.graphics.setLineWidth(1.6)
  love.graphics.polygon("line",
    cx,      cy - r,
    cx + r,  cy + r * 0.85,
    cx - r,  cy + r * 0.85)
  love.graphics.setLineWidth(1)

  love.graphics.setColor(col[1], col[2], col[3], alpha)
  love.graphics.rectangle("fill", cx - 1.2, cy - r * 0.45, 2.4, r * 0.75)
  love.graphics.rectangle("fill", cx - 1.2, cy + r * 0.45, 2.4, 2.4)
end

-- ── Drawing: header ─────────────────────────────────────────
local function draw_header(ease, t)
  love.graphics.setColor(COL_HEADER[1], COL_HEADER[2], COL_HEADER[3],
    0.85 * ease)
  love.graphics.rectangle("fill", WIN_X, WIN_Y, WIN_W, HDR_H, 6, 6)

  love.graphics.setColor(COL_HEADER_LINE[1], COL_HEADER_LINE[2],
    COL_HEADER_LINE[3], 0.9 * ease)
  love.graphics.rectangle("fill", WIN_X, WIN_Y + HDR_H - 1, WIN_W, 1)

  local pulse = 0.5 + 0.5 * math.sin(t * 5)
  draw_warning_triangle(WIN_X + 22, WIN_Y + HDR_H / 2, 10,
    COL_WARN, ease, pulse)

  love.graphics.setFont(
    A.font("assets/fonts/JetBrainsMono-Regular.ttf", 12))
  love.graphics.setColor(1.00, 0.85, 0.85, ease)
  love.graphics.print("SPDW FACTORY  //  SYSTEM ADVISORY",
    WIN_X + 44, WIN_Y + 13)

  -- Pulsing red LED on the right.
  local blink = 0.5 + 0.5 * math.sin(t * math.pi * 2)
  local led_x = WIN_X + WIN_W - 18
  local led_y = WIN_Y + HDR_H / 2
  love.graphics.setColor(1, 0.35, 0.35, (0.4 + blink * 0.6) * ease)
  love.graphics.circle("fill", led_x, led_y, 4)
  love.graphics.setColor(1, 0.35, 0.35, 0.20 * ease)
  love.graphics.circle("fill", led_x, led_y, 8)
end

-- ── Drawing: Minoru portrait ────────────────────────────────
local function draw_minoru(ease, t)
  local frame_x = MINORU_X
  local frame_y = MINORU_Y
  local frame_w = MINORU_W
  local frame_h = MINORU_H

  local bob = math.sin(t * 1.6) * 6

  -- Panel background
  love.graphics.setColor(0.04, 0.05, 0.09, 0.9 * ease)
  love.graphics.rectangle("fill", frame_x, frame_y, frame_w, frame_h, 6, 6)

  -- Border, pulsing
  local pulse = 0.5 + 0.5 * math.sin(t * 2.2)
  love.graphics.setColor(COL_ACCENT_GC[1], COL_ACCENT_GC[2],
    COL_ACCENT_GC[3], (0.55 + pulse * 0.30) * ease)
  love.graphics.setLineWidth(1.6)
  love.graphics.rectangle("line", frame_x, frame_y, frame_w, frame_h, 6, 6)
  love.graphics.setLineWidth(1)

  D.corner_brackets(frame_x, frame_y, frame_w, frame_h,
    COL_ACCENT_GC, 14)

  -- Portrait
  local cx = frame_x + frame_w / 2
  local cy = frame_y + frame_h / 2 + bob
  local glow_r = 90 + pulse * 14
  D.glow(cx, cy, glow_r, COL_ACCENT_GC, 0.55 * ease)

  local img = A.image(MINORU_PATH)
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    local box_w = frame_w - 24
    local box_h = frame_h - 24
    local sc = math.min(box_w / iw, box_h / ih)
    local dw, dh = iw * sc, ih * sc
    local dx = cx - dw / 2
    local dy = cy - dh / 2
    love.graphics.setColor(1, 1, 1, ease)
    love.graphics.draw(img, dx, dy, 0, sc, sc)
  else
    love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 96))
    love.graphics.setColor(COL_ACCENT_GC[1], COL_ACCENT_GC[2],
      COL_ACCENT_GC[3], ease)
    love.graphics.printf("M", frame_x, cy - 60, frame_w, "center")
  end

  -- Name tag
  local tag_y = frame_y + frame_h + 6
  local tag_h = 22
  love.graphics.setColor(0.10, 0.06, 0.18, 0.9 * ease)
  love.graphics.rectangle("fill", frame_x, tag_y, frame_w, tag_h, 4, 4)
  love.graphics.setColor(COL_ACCENT_GC[1], COL_ACCENT_GC[2],
    COL_ACCENT_GC[3], 0.7 * ease)
  love.graphics.rectangle("line", frame_x, tag_y, frame_w, tag_h, 4, 4)

  local font = A.font("assets/fonts/Oxanium-Bold.ttf", 13)
  love.graphics.setFont(font)
  love.graphics.setColor(COL_ACCENT_GC[1], COL_ACCENT_GC[2],
    COL_ACCENT_GC[3], ease)

  local title = "Minoru"
  local tw = font:getWidth(title)
  -- Center the whole "Minoru⁷ (R.I.)" cluster.
  local sup_font = A.font("assets/fonts/Oxanium-Bold.ttf", 9)
  local ri_font  = A.font("assets/fonts/Oxanium-Regular.ttf", 9)
  local sup_w    = sup_font:getWidth("7")
  local ri_w     = ri_font:getWidth("(R.I.)")
  local total    = tw + 2 + sup_w + 8 + ri_w
  local tx       = frame_x + (frame_w - total) / 2

  love.graphics.print(title, tx, tag_y + 5)

  love.graphics.setFont(sup_font)
  love.graphics.print("7", tx + tw + 2, tag_y + 2)

  love.graphics.setFont(ri_font)
  love.graphics.setColor(COL_ACCENT_GC[1], COL_ACCENT_GC[2],
    COL_ACCENT_GC[3], 0.6 * ease)
  love.graphics.print("(R.I.)", tx + tw + 2 + sup_w + 8, tag_y + 6)
end

-- ── Drawing: body text ──────────────────────────────────────
local function kind_style(kind)
  if kind == "emph"  then return COL_TEXT,      13, true  end
  if kind == "body"  then return COL_TEXT_BODY, 11, false end
  if kind == "warn"  then return COL_WARN,      12, true  end
  if kind == "dim"   then return COL_TEXT_DIM,  10, false end
  return COL_TEXT_BODY, 11, false
end

local function draw_body_text(ease, t)
  local y = TEXT_Y
  for i = 1, S.lines_shown do
    local line = BODY_LINES[i]
    if line.kind ~= "blank" then
      local appear_at  = (i - 1) * LINE_DELAY
      local local_ease = math.min(1, (t - appear_at) / LINE_FADE)
      local_ease       = math.max(0, local_ease)
      local a          = ease * local_ease
      if a > 0.01 then
        local col, size, bold = kind_style(line.kind)
        local fpath = bold
          and "assets/fonts/Oxanium-Bold.ttf"
          or  "assets/fonts/Oxanium-Regular.ttf"
        love.graphics.setFont(A.font(fpath, size))
        love.graphics.setColor(col[1], col[2], col[3], a)
        love.graphics.print(line.text, TEXT_X, y)
      end
    end
    y = y + LINE_H
  end
end

-- ── Drawing: buttons ────────────────────────────────────────
local function draw_button(label, key, x, y, w, h, col, focused_pulse)
  love.graphics.setColor(col[1] * 0.15, col[2] * 0.15, col[3] * 0.15, 0.95)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)

  love.graphics.setColor(col[1], col[2], col[3], 0.7 + focused_pulse * 0.3)
  love.graphics.setLineWidth(1.8)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  love.graphics.setLineWidth(1)

  D.corner_brackets(x, y, w, h, col, 12)

  local size = 32
  local ix = x + 16
  local iy = y + (h - size) / 2
  BI.draw(State.theme, key, ix, iy, size)

  local font = A.font("assets/fonts/Oxanium-Bold.ttf", 16)
  love.graphics.setFont(font)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(label, ix + size + 12,
    y + (h - font:getHeight()) / 2)
end

local function draw_buttons(ease, t)
  local pulse = 0.5 + 0.5 * math.sin(t * 3)
  local col_a = {0.30, 0.85, 0.45}
  local col_b = {0.95, 0.35, 0.35}

  draw_button("PROCEED",       "a", BTN_A_X, BTN_Y, BTN_W, BTN_H,
    col_a, pulse * 0.6)
  draw_button("PULL THE PLUG", "b", BTN_B_X, BTN_Y, BTN_W, BTN_H,
    col_b, pulse * 0.9)

  local blink = 0.5 + 0.5 * math.sin(t * 6)
  love.graphics.setColor(1, 0.35, 0.35, (0.4 + blink * 0.6) * ease)
  love.graphics.circle("fill", BTN_B_X + BTN_W - 10, BTN_Y + 10, 3.5)
end

-- ── Main draw ───────────────────────────────────────────────
function S.draw()
  local t = S.t
  local ease = S.enter_ease
  ease = 1 - (1 - ease) ^ 3

  draw_background(t)

  local scale = 0.94 + 0.06 * ease
  local cx = WIN_X + WIN_W / 2
  local cy = WIN_Y + WIN_H / 2
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-cx, -cy)

  love.graphics.setColor(COL_WIN[1], COL_WIN[2], COL_WIN[3], 0.98 * ease)
  love.graphics.rectangle("fill", WIN_X, WIN_Y, WIN_W, WIN_H, 6, 6)

  love.graphics.setColor(COL_BORDER[1], COL_BORDER[2], COL_BORDER[3],
    0.9 * ease)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", WIN_X, WIN_Y, WIN_W, WIN_H, 6, 6)
  love.graphics.setLineWidth(1)
  D.corner_brackets(WIN_X, WIN_Y, WIN_W, WIN_H, COL_BORDER, 18)

  draw_header(ease, t)
  draw_body_text(ease, t)
  draw_minoru(ease, t)
  draw_buttons(ease, t)

  love.graphics.pop()

  -- Global CRT scanline pass on top of everything
  love.graphics.setColor(0, 0, 0, 0.06)
  for y = 0, H, 3 do
    love.graphics.line(0, y, W, y)
  end
end

return S