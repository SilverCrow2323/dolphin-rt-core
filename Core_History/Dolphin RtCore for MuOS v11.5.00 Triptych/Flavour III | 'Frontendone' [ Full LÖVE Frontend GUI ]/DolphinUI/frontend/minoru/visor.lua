-- frontend/minoru/visor.lua
-- The emotional oscilloscope.
--
-- Six visor states, each with its own colour, line-shape and
-- pulse behaviour. The line is drawn inside a stencilled glass
-- circle so it never leaks past the bezel.
--
-- This module is purely a renderer; the state comes in from the
-- avatar (which gets it from the persona).

local Shading = require("minoru.shading")

local V = {}

-- ── Palette ──────────────────────────────────────────────────
V.emotions = {
  standard = {
    color      = {0.30, 0.88, 0.45},
    shape      = "flat",
    pulse_hz   = 1.6,
    pulse_amp  = 0.16,
    glow       = 0.55,
  },
  sarcastic = {
    color      = {0.95, 0.32, 0.32},
    shape      = "halfline",
    pulse_hz   = 3.2,
    pulse_amp  = 0.22,
    glow       = 0.70,
  },
  angry = {
    color      = {0.72, 0.12, 0.12},
    shape      = "jagged",
    pulse_hz   = 9.0,
    pulse_amp  = 0.60,
    glow       = 0.85,
  },
  apprehension = {
    color      = {0.32, 0.58, 0.95},
    shape      = "thin_low",
    pulse_hz   = 1.4,
    pulse_amp  = 0.10,
    glow       = 0.40,
  },
  paradox = {
    color      = {0.68, 0.32, 0.92},
    shape      = "paradox",
    pulse_hz   = 5.5,
    pulse_amp  = 0.45,
    glow       = 0.80,
  },
  perplexed = {
    color      = {0.95, 0.82, 0.30},
    shape      = "wave",
    pulse_hz   = 2.2,
    pulse_amp  = 0.35,
    glow       = 0.65,
  },
}

function V.get(name)
  return V.emotions[name] or V.emotions.standard
end

-- ── Drawing ──────────────────────────────────────────────────
-- draw(cx, cy, r, emotion_name, t)
--   cx, cy = visor centre
--   r      = visor radius
--   t      = time in seconds (for the pulse)
local function line_points(shape, cx, cy, half, amp, t, pulse)
  local pts = {}
  local n = 40

  if shape == "flat" then
    for i = 0, n do
      local u = i / n
      pts[#pts + 1] = cx - half + 2 * half * u
      pts[#pts + 1] = cy + math.sin(u * math.pi) * amp * 0.15
    end

  elseif shape == "halfline" then
    -- Smirk: dips in the middle.
    for i = 0, n do
      local u = i / n
      pts[#pts + 1] = cx - half + 2 * half * u
      pts[#pts + 1] = cy + math.sin(u * math.pi) * amp * 1.1
    end

  elseif shape == "jagged" then
    local jitter_amp = amp * (0.7 + 0.5 * math.abs(pulse))
    for i = 0, n do
      local u = i / n
      local zig = ((i % 2 == 0) and 1 or -1)
      local tt  = t * 12
      pts[#pts + 1] = cx - half + 2 * half * u
      pts[#pts + 1] = cy + zig * jitter_amp * (0.4 + 0.6 * math.abs(math.sin(tt)))
    end

  elseif shape == "thin_low" then
    local y = cy + amp * 1.6
    pts[#pts + 1] = cx - half + 6
    pts[#pts + 1] = y
    pts[#pts + 1] = cx + half - 6
    pts[#pts + 1] = y

  elseif shape == "wave" then
    for i = 0, n do
      local u = i / n
      pts[#pts + 1] = cx - half + 2 * half * u
      pts[#pts + 1] = cy + math.sin(u * math.pi * 2 + t * 2.2) * amp * 1.4
    end

  elseif shape == "paradox" then
    for i = 0, n do
      local u = i / n
      pts[#pts + 1] = cx - half + 2 * half * u
      pts[#pts + 1] = cy + math.sin(u * math.pi * 4 + t * 3.0) * amp * 0.35
    end
  end

  return pts
end

function V.draw(cx, cy, r, emotion_name, t)
  local em = V.get(emotion_name)
  local col = em.color

  -- ── Bezel (dark ring) ────────────────────────────────────
  Shading.irregular_circle(cx, cy, r + r * 0.10,
    {0.06, 0.07, 0.09}, nil, 0, 300, 1.2, 20)

  -- ── Glass (very dark teal) ───────────────────────────────
  Shading.irregular_circle(cx, cy, r,
    {0.02, 0.06, 0.05}, nil, 0, 301, 1.0, 24)

  -- ── Glass inner tint (the "always-on" glow) ──────────────
  love.graphics.setColor(col[1] * 0.10, col[2] * 0.10, col[3] * 0.10, 1)
  love.graphics.circle("fill", cx, cy, r * 0.96)

  -- ── Top-left glass highlight ─────────────────────────────
  Shading.clipped_arc_highlight(cx, cy, r * 0.94,
    {0.15, 0.20, 0.19, 0.55})

  -- ── The line, clipped to the glass ───────────────────────
  local pulse = math.sin(t * em.pulse_hz)
  local amp   = r * 0.25 * (1 + pulse * em.pulse_amp)
  local half  = r * 0.78

  love.graphics.stencil(function()
    love.graphics.circle("fill", cx, cy, r * 0.94)
  end, "replace", 1)
  love.graphics.setStencilTest("greater", 0)

  local pts = line_points(em.shape, cx, cy, half, amp, t, pulse)

  -- Glow behind
  love.graphics.setLineWidth(math.max(6, r * 0.24))
  love.graphics.setColor(col[1], col[2], col[3], 0.30)
  love.graphics.line(pts)
  love.graphics.setLineWidth(math.max(3, r * 0.14))
  love.graphics.setColor(col[1], col[2], col[3], 0.65)
  love.graphics.line(pts)

  -- Core
  love.graphics.setLineWidth(math.max(2, r * 0.085))
  love.graphics.setColor(col[1], col[2], col[3], 1)
  love.graphics.line(pts)

  -- Paradox: extra ghost dashes
  if em.shape == "paradox" and math.floor(t * 8) % 3 == 0 then
    love.graphics.setColor(1, 1, 1, 0.65)
    love.graphics.setLineWidth(math.max(2, r * 0.09))
    local dx = (Shading.hash(math.floor(t * 8), 7) * 2 - 1) * r * 0.9
    love.graphics.line(cx + dx - r * 0.20, cy,
                       cx + dx + r * 0.20, cy)
  end

  love.graphics.setStencilTest()
  love.graphics.setLineWidth(1)

  -- ── Outer visor glow (leaks a bit for atmosphere) ────────
  local glow_pulse = 0.5 + 0.5 * math.sin(t * em.pulse_hz * 0.5)
  local D = require("ui.draw")
  D.glow(cx, cy, r * 1.7, col,
    em.glow * (0.35 + glow_pulse * 0.35))

  -- ── Rim highlight on top of the bezel ────────────────────
  love.graphics.setColor(0.55, 0.58, 0.62, 0.45)
  love.graphics.setLineWidth(math.max(1, r * 0.05))
  love.graphics.arc("line", "open", cx, cy, r + r * 0.055,
    math.rad(200), math.rad(340))
  love.graphics.setLineWidth(1)

  -- ── Bezel outline ────────────────────────────────────────
  local outer_pts = Shading.irregular_circle_pts(
    cx, cy, r + r * 0.10, 302, 1.4, 24)
  love.graphics.setColor(0.02, 0.02, 0.03, 1)
  love.graphics.setLineWidth(math.max(2, r * 0.06))
  love.graphics.polygon("line", outer_pts)
  love.graphics.setLineWidth(1)
end

return V