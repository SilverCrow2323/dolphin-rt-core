-- frontend/minoru/shading.lua
-- Cel-shading + irregular ("hand-drawn") outlines.
--
-- The whole Minoru look is procedural. This module owns the two
-- primitives everything else is built from:
--
--   1. Boiling jitter — a low-frequency noise that updates ~8 Hz,
--      giving outlines that "boil" like traditional 2D animation.
--      Every shape asks for its own seed so different outlines
--      boil independently.
--
--   2. Irregular strokes — polygon outlines whose vertices are
--      offset perpendicular to the edge by a jittered amount,
--      producing thick, slightly uneven black borders.

local S = {}

-- ── Deterministic hash ────────────────────────────────────────
-- Returns a value in [0, 1] from (seed, index). Same input =
-- same output, so a shape keeps its character frame to frame.
local function hash(seed, i)
  local v = math.sin(seed * 12.9898 + i * 78.233) * 43758.5453
  return v - math.floor(v)
end
S.hash = hash

-- Same hash but mapped to [-1, 1].
local function hash_signed(seed, i)
  return hash(seed, i) * 2 - 1
end

-- ── Boiling seed ─────────────────────────────────────────────
-- The "boil" updates a quantised time value. Any stroke that
-- asks for its seed via this function will visually "redo itself"
-- BOIL_HZ times per second, like a pencil that keeps re-drawing.
local _t = 0
local BOIL_HZ = 8

function S.update(dt)
  _t = _t + dt
end

function S.boil_seed(base_seed)
  return (base_seed or 0) + math.floor(_t * BOIL_HZ) * 7.13
end

-- ── Irregular circle path ────────────────────────────────────
-- Returns a table of {x1, y1, x2, y2, …} polygon points.
-- `jitter` is the max perpendicular deviation in pixels.
function S.irregular_circle_pts(cx, cy, r, seed, jitter, segments)
  segments = segments or 32
  jitter   = jitter   or 1.4
  local pts = {}
  local s   = S.boil_seed(seed)
  for i = 0, segments - 1 do
    local a = (i / segments) * math.pi * 2
    local j = hash_signed(s, i) * jitter
    local rad = r + j
    pts[#pts + 1] = cx + math.cos(a) * rad
    pts[#pts + 1] = cy + math.sin(a) * rad
  end
  return pts
end

-- Irregular circle: fill + outline in one call.
-- Returns the points so callers can re-use them for shading.
function S.irregular_circle(cx, cy, r, fill_col, stroke_col,
                            stroke_w, seed, jitter, segments)
  local pts = S.irregular_circle_pts(cx, cy, r, seed, jitter, segments)
  if fill_col then
    love.graphics.setColor(fill_col)
    love.graphics.polygon("fill", pts)
  end
  if stroke_col and stroke_w and stroke_w > 0 then
    love.graphics.setColor(stroke_col)
    love.graphics.setLineWidth(stroke_w)
    love.graphics.polygon("line", pts)
    love.graphics.setLineWidth(1)
  end
  return pts
end

-- ── Irregular segment (limb bone) ────────────────────────────
-- Draws a thick line with slightly irregular sides. Two parallel
-- strokes offset by ±half-thickness, each jittered.
function S.irregular_segment(x1, y1, x2, y2, thickness,
                             fill_col, stroke_col, stroke_w, seed)
  local dx = x2 - x1
  local dy = y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.01 then return end

  -- Perpendicular unit vector
  local nx = -dy / len
  local ny =  dx / len

  local half = thickness * 0.5
  local s    = S.boil_seed(seed)
  local j1   = hash_signed(s, 1) * 0.9
  local j2   = hash_signed(s, 2) * 0.9
  local j3   = hash_signed(s, 3) * 0.9
  local j4   = hash_signed(s, 4) * 0.9

  -- Four corners of the limb quad, jittered slightly.
  local ax = x1 + nx * (half + j1)
  local ay = y1 + ny * (half + j1)
  local bx = x2 + nx * (half + j2)
  local by = y2 + ny * (half + j2)
  local cx = x2 - nx * (half + j3)
  local cy = y2 - ny * (half + j3)
  local dx2 = x1 - nx * (half + j4)
  local dy2 = y1 - ny * (half + j4)

  local quad = { ax, ay, bx, by, cx, cy, dx2, dy2 }

  if fill_col then
    love.graphics.setColor(fill_col)
    love.graphics.polygon("fill", quad)
  end
  if stroke_col and stroke_w and stroke_w > 0 then
    love.graphics.setColor(stroke_col)
    love.graphics.setLineWidth(stroke_w)
    love.graphics.polygon("line", quad)
    love.graphics.setLineWidth(1)
  end
end

-- ── Cel-shaded band ──────────────────────────────────────────
-- A flat tinted band clipped to a circular region. Used for the
-- sphere's top highlight and bottom shadow — the "two-tone"
-- effect that reads as cel-shading.
function S.circular_band(cx, cy, r, y_top, y_bottom, col)
  love.graphics.setColor(col)
  love.graphics.arc("fill", "pie", cx, cy, r,
    math.rad(0), math.rad(360))
  love.graphics.rectangle("fill", cx - r, y_top, r * 2, y_bottom - y_top)
end

-- Draws a horizontal flat band inside a circle (used for shadow).
-- Clips to the circle first.
function S.clipped_band(cx, cy, r, band_y, band_h, col)
  love.graphics.stencil(function()
    love.graphics.circle("fill", cx, cy, r)
  end, "replace", 1)
  love.graphics.setStencilTest("greater", 0)
  love.graphics.setColor(col)
  love.graphics.rectangle("fill", cx - r - 2, band_y, r * 2 + 4, band_h)
  love.graphics.setStencilTest()
end

-- Draws a top-left highlight arc clipped to the circle.
function S.clipped_arc_highlight(cx, cy, r, col)
  love.graphics.stencil(function()
    love.graphics.circle("fill", cx, cy, r)
  end, "replace", 1)
  love.graphics.setStencilTest("greater", 0)
  love.graphics.setColor(col)
  love.graphics.arc("fill", "pie",
    cx - r * 0.20, cy - r * 0.20, r * 1.05,
    math.rad(180), math.rad(310))
  love.graphics.setStencilTest()
end

return S