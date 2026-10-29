-- frontend/minoru/world.lua
-- Minoru's home environment. Cel-shaded backdrop + props + lighting.
--
-- Every visual element uses shading.lua so the whole scene shares
-- Minoru's hand-drawn ink look: flat tones, thick irregular
-- outlines that boil at ~8 Hz.
--
-- Owns:
--   * backdrop  — gradient bands, distant neon signs, pipes
--   * floor     — receding perspective grid
--   * props     — desk, monitor, shelf, mug, lamp (each optional)
--   * ambient   — dust motes, scanlines, vignette
--
-- Nothing here talks to State or the screen registry.

local Shading = require("minoru.shading")
local A       = require("assets")

local World = {}
World.__index = World

-- Palette: muted industrial. Matches Minoru's body and visor.
local P = {
  bg_top      = {0.055, 0.062, 0.075},
  bg_bottom   = {0.020, 0.025, 0.032},
  wall_panel  = {0.095, 0.105, 0.120},
  wall_line   = {0.060, 0.068, 0.080},
  floor_line  = {0.100, 0.115, 0.135},
  pipe_fill   = {0.150, 0.165, 0.185},
  pipe_shadow = {0.055, 0.062, 0.075},
  outline     = {0.015, 0.018, 0.022},
  neon_1      = {0.85, 0.20, 0.50},
  neon_2      = {0.20, 0.75, 0.95},
  neon_3      = {0.95, 0.78, 0.22},
  neon_4      = {0.55, 0.35, 0.95},
}

local DEFAULT_PROPS = {
  { key = "desk",    rel = {0.02, 0.74, 0.96, 0.20} },
  { key = "monitor", rel = {0.66, 0.44, 0.26, 0.28} },
  { key = "shelf",   rel = {0.03, 0.14, 0.22, 0.34} },
  { key = "mug",     rel = {0.60, 0.80, 0.07, 0.09} },
  { key = "lamp",    rel = {0.90, 0.32, 0.08, 0.16} },
}

function World.new(opts)
  opts = opts or {}
  local self = setmetatable({}, World)
  self.visible_props = opts.props or { "desk", "monitor", "shelf", "mug", "lamp" }
  self.ambient       = opts.ambient ~= false
  self.t             = 0
  self._img_cache    = {}
  return self
end

function World:_img(path)
  if not path then return nil end
  local c = self._img_cache[path]
  if c ~= nil then return c or nil end
  local img = A.image(path)
  self._img_cache[path] = img or false
  return img or nil
end

function World:update(dt)
  self.t = self.t + dt
end

-- ── Backdrop ─────────────────────────────────────────────────
function World:_draw_backdrop(x, y, w, h)
  -- Flat two-tone gradient in 6 bands — no smooth fade.
  local bands = 6
  for i = 0, bands - 1 do
    local p = i / (bands - 1)
    love.graphics.setColor(
      P.bg_top[1] + (P.bg_bottom[1] - P.bg_top[1]) * p,
      P.bg_top[2] + (P.bg_bottom[2] - P.bg_top[2]) * p,
      P.bg_top[3] + (P.bg_bottom[3] - P.bg_top[3]) * p, 1)
    local bh = h / bands
    love.graphics.rectangle("fill",
      x, y + i * bh, w, math.ceil(bh) + 1)
  end

  -- Back-wall industrial panels (grid of rectangles).
  love.graphics.setColor(P.wall_panel)
  for px = x, x + w, 80 do
    love.graphics.rectangle("fill", px, y + h * 0.30, 78, h * 0.32)
  end
  love.graphics.setColor(P.wall_line)
  love.graphics.setLineWidth(1)
  for px = x, x + w, 80 do
    love.graphics.rectangle("line", px, y + h * 0.30, 78, h * 0.32)
  end
  for py = y + h * 0.30, y + h * 0.62, 30 do
    love.graphics.line(x, py, x + w, py)
  end

  -- Distant neon signs — flat colours, boiling outlines.
  local seed = 4242
  local neons = {
    { x = 0.08, y = 0.10, w = 0.14, h = 0.012, c = P.neon_1 },
    { x = 0.72, y = 0.14, w = 0.18, h = 0.010, c = P.neon_2 },
    { x = 0.24, y = 0.22, w = 0.10, h = 0.008, c = P.neon_3 },
    { x = 0.60, y = 0.28, w = 0.14, h = 0.010, c = P.neon_4 },
  }
  for i, n in ipairs(neons) do
    local nx = x + n.x * w
    local ny = y + n.y * h
    local nw = n.w * w
    local nh = n.h * h

    -- Soft glow (kept, but small — the outline does the work).
    for gi = 3, 1, -1 do
      love.graphics.setColor(n.c[1], n.c[2], n.c[3], 0.08 * (4 - gi))
      love.graphics.rectangle("fill",
        nx - gi * 4, ny - gi * 3,
        nw + gi * 8, nh + gi * 6, 2, 2)
    end

    -- Core
    love.graphics.setColor(n.c)
    love.graphics.rectangle("fill", nx, ny, nw, nh, 2, 2)

    -- Boiling outline
    Shading.irregular_segment(nx, ny, nx + nw, ny, 2,
      nil, P.outline, 1.5, seed + i * 7)
    Shading.irregular_segment(nx, ny + nh, nx + nw, ny + nh, 2,
      nil, P.outline, 1.5, seed + i * 7 + 3)
  end

  -- Ceiling pipe, thick with irregular outline.
  local pipe_y = y + h * 0.05
  local pipe_h = h * 0.022
  Shading.irregular_segment(x, pipe_y, x + w, pipe_y, pipe_h,
    P.pipe_fill, P.outline, 2.5, 9001)
  -- Shadow edge under the pipe.
  love.graphics.setColor(P.pipe_shadow)
  love.graphics.rectangle("fill", x, pipe_y + pipe_h / 2 - 1, w, 2)
  -- Joint rings every 80 px.
  for rx = x + 40, x + w, 80 do
    Shading.irregular_segment(rx, pipe_y - 2, rx, pipe_y + pipe_h + 2,
      6, nil, P.outline, 1.5, 9001 + rx)
  end
end

-- ── Floor ────────────────────────────────────────────────────
function World:_draw_floor(x, y, w, h)
  local horizon = y + h * 0.68
  -- Horizon line
  Shading.irregular_segment(x, horizon, x + w, horizon, 2,
    nil, P.outline, 2, 7777)

  -- Perspective lines
  love.graphics.setColor(P.floor_line)
  love.graphics.setLineWidth(1)
  local vp_x = x + w * 0.5
  for fx = -w, x + w * 2, 56 do
    love.graphics.line(fx, y + h, vp_x, horizon)
  end
  -- Horizontal tiers, denser toward the horizon
  for i = 0, 10 do
    local p = i / 10
    local yy = horizon + (y + h - horizon) * (p ^ 1.7)
    love.graphics.line(x, yy, x + w, yy)
  end
  love.graphics.setLineWidth(1)
end

-- ── Props ────────────────────────────────────────────────────
function World:_draw_prop(prop, x, y, w, h)
  local px = x + prop.rel[1] * w
  local py = y + prop.rel[2] * h
  local pw = prop.rel[3] * w
  local ph = prop.rel[4] * h

  -- Optional PNG override
  local img = self:_img("minoru/assets/props/" .. prop.key .. ".png")
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    local sc = math.min(pw / iw, ph / ih)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, px, py, 0, sc, sc)
    return
  end

  -- Procedural prop. Cel-shaded, thick irregular outlines.
  if prop.key == "desk" then
    self:_draw_desk(px, py, pw, ph)
  elseif prop.key == "monitor" then
    self:_draw_monitor(px, py, pw, ph)
  elseif prop.key == "shelf" then
    self:_draw_shelf(px, py, pw, ph)
  elseif prop.key == "mug" then
    self:_draw_mug(px, py, pw, ph)
  elseif prop.key == "lamp" then
    self:_draw_lamp(px, py, pw, ph)
  end
end

function World:_draw_desk(px, py, pw, ph)
  local top_h = ph * 0.18
  -- Top surface (cel-flat, two-tone)
  Shading.irregular_circle(0, 0, 0, nil, nil, 0, 0) -- warmup, unused
  local pts = { px, py, px + pw, py, px + pw, py + top_h, px, py + top_h }
  love.graphics.setColor(0.170, 0.130, 0.100)
  love.graphics.polygon("fill", pts)
  love.graphics.setColor(0.110, 0.080, 0.060)
  love.graphics.rectangle("fill", px, py + top_h - 2, pw, 2)

  -- Boiling outline
  Shading.irregular_segment(px, py, px + pw, py, 2,
    nil, P.outline, 2.2, 1201)
  Shading.irregular_segment(px, py + top_h, px + pw, py + top_h, 2,
    nil, P.outline, 2.2, 1202)
  Shading.irregular_segment(px, py, px, py + top_h, 2,
    nil, P.outline, 2.2, 1203)
  Shading.irregular_segment(px + pw, py, px + pw, py + top_h, 2,
    nil, P.outline, 2.2, 1204)

  -- Wood grain (short strokes)
  love.graphics.setColor(0.080, 0.055, 0.040, 0.55)
  for gx = px + 8, px + pw - 8, 34 do
    local gy = py + 4 + (gx % 7)
    love.graphics.rectangle("fill", gx, gy, 24, 1)
  end
end

function World:_draw_monitor(px, py, pw, ph)
  local body_h = ph * 0.72
  -- Monitor shell
  love.graphics.setColor(0.095, 0.105, 0.120)
  love.graphics.rectangle("fill", px, py, pw, body_h, 3, 3)
  -- Glass screen
  love.graphics.setColor(0.030, 0.075, 0.085)
  love.graphics.rectangle("fill",
    px + 6, py + 6, pw - 12, body_h - 12, 2, 2)
  -- Faint content: three blinking lines
  local blink = 0.5 + 0.5 * math.sin(self.t * 2.4)
  love.graphics.setColor(0.30, 0.85, 1.00, 0.35 + blink * 0.35)
  love.graphics.rectangle("fill", px + 14, py + 20, 26, 2)
  love.graphics.rectangle("fill", px + 14, py + 28, 42, 2)
  love.graphics.rectangle("fill", px + 14, py + 36, 20, 2)
  -- Cursor
  if math.floor(self.t * 2) % 2 == 0 then
    love.graphics.setColor(0.30, 0.85, 1.00, 0.9)
    love.graphics.rectangle("fill", px + 14, py + 50, 6, 8)
  end
  -- Shell outline (irregular)
  Shading.irregular_segment(px, py, px + pw, py, 2,
    nil, P.outline, 2.4, 1301)
  Shading.irregular_segment(px, py + body_h, px + pw, py + body_h, 2,
    nil, P.outline, 2.4, 1302)
  Shading.irregular_segment(px, py, px, py + body_h, 2,
    nil, P.outline, 2.4, 1303)
  Shading.irregular_segment(px + pw, py, px + pw, py + body_h, 2,
    nil, P.outline, 2.4, 1304)
  -- Stand
  love.graphics.setColor(0.095, 0.105, 0.120)
  love.graphics.rectangle("fill",
    px + pw * 0.45, py + body_h, pw * 0.10, ph * 0.10)
  love.graphics.rectangle("fill",
    px + pw * 0.28, py + body_h + ph * 0.10,
    pw * 0.44, ph * 0.03, 2, 2)
  Shading.irregular_segment(px + pw * 0.28, py + body_h + ph * 0.13,
    px + pw * 0.72, py + body_h + ph * 0.13, 3,
    nil, P.outline, 2, 1305)
end

function World:_draw_shelf(px, py, pw, ph)
  -- Three shelves
  for i = 0, 2 do
    local sy = py + i * ph / 3
    love.graphics.setColor(0.140, 0.105, 0.080)
    love.graphics.rectangle("fill", px, sy, pw, ph * 0.06)
    Shading.irregular_segment(px, sy, px + pw, sy, 3,
      nil, P.outline, 2, 1401 + i)
  end
  -- A few leaning books
  local book_colors = {
    {0.55, 0.28, 0.30},
    {0.28, 0.35, 0.55},
    {0.35, 0.45, 0.32},
    {0.60, 0.42, 0.22},
  }
  for i = 1, 5 do
    local bx = px + 6 + i * (pw - 12) / 5
    local bh = ph * 0.18 + (i % 3) * 4
    local c  = book_colors[(i % #book_colors) + 1]
    love.graphics.setColor(c)
    love.graphics.rectangle("fill", bx, py + ph / 3 - bh, 8, bh, 1, 1)
    Shading.irregular_segment(bx, py + ph / 3 - bh, bx + 8, py + ph / 3 - bh, 2,
      nil, P.outline, 1.2, 1402 + i)
  end
end

function World:_draw_mug(px, py, pw, ph)
  -- Body
  love.graphics.setColor(0.75, 0.78, 0.82)
  love.graphics.rectangle("fill", px, py, pw, ph, 3, 3)
  -- Rim
  love.graphics.setColor(0.92, 0.94, 0.96)
  love.graphics.rectangle("fill", px, py, pw, 3)
  -- Handle
  love.graphics.setLineWidth(3)
  love.graphics.setColor(0.75, 0.78, 0.82)
  love.graphics.arc("line", "open",
    px + pw, py + ph / 2, ph * 0.30,
    -math.pi / 2, math.pi / 2)
  love.graphics.setLineWidth(1)
  -- Outline
  Shading.irregular_segment(px, py, px + pw, py, 2,
    nil, P.outline, 2, 1501)
  Shading.irregular_segment(px, py + ph, px + pw, py + ph, 2,
    nil, P.outline, 2, 1502)
  Shading.irregular_segment(px, py, px, py + ph, 2,
    nil, P.outline, 2, 1503)
  Shading.irregular_segment(px + pw, py, px + pw, py + ph, 2,
    nil, P.outline, 2, 1504)
  -- Steam
  love.graphics.setColor(0.85, 0.90, 1.00, 0.20)
  for i = 1, 3 do
    local sy = py - 4 - i * 5 + math.sin(self.t * 3 + i) * 2
    love.graphics.circle("fill", px + pw * 0.5, sy, 2)
  end
end

function World:_draw_lamp(px, py, pw, ph)
  -- Vertical stem
  Shading.irregular_segment(px + pw * 0.5, py,
    px + pw * 0.5, py + ph * 0.70, 4,
    {0.24, 0.24, 0.28}, P.outline, 2, 1601)
  -- Conical shade
  love.graphics.setColor(0.24, 0.26, 0.30)
  love.graphics.polygon("fill",
    px, py + ph * 0.70,
    px + pw, py + ph * 0.70,
    px + pw * 0.65, py + ph)
  love.graphics.setColor(P.outline)
  love.graphics.setLineWidth(2)
  love.graphics.polygon("line",
    px, py + ph * 0.70,
    px + pw, py + ph * 0.70,
    px + pw * 0.65, py + ph)
  love.graphics.setLineWidth(1)
  -- Warm glow beneath
  local pulse = 0.6 + 0.4 * math.sin(self.t * 6)
  for i = 4, 1, -1 do
    love.graphics.setColor(1.00, 0.82, 0.50,
      0.06 * (5 - i) * pulse)
    love.graphics.circle("fill",
      px + pw * 0.5, py + ph, i * 8)
  end
end

-- ── Ambient ──────────────────────────────────────────────────
function World:_draw_ambient(x, y, w, h)
  -- Scanlines
  love.graphics.setColor(0, 0, 0, 0.06)
  for yy = y, y + h, 3 do
    love.graphics.rectangle("fill", x, yy, w, 1)
  end

  -- Dust motes: deterministic layout, animated downward.
  local seed = 67890
  for i = 1, 40 do
    local dx = x + Shading.hash(seed, i) * w
    local base_y = Shading.hash(seed, i + 50) * h
    local dy = y + ((base_y + self.t * 8) % h)
    local r  = 0.5 + Shading.hash(seed, i + 100) * 0.8
    love.graphics.setColor(0.85, 0.90, 1.00, 0.10)
    love.graphics.circle("fill", dx, dy, r)
  end

  -- Vignette: 4 layers of irregular rectangles.
  for i = 1, 4 do
    love.graphics.setColor(0, 0, 0, 0.13 * (i / 4))
    love.graphics.rectangle("line",
      x - i * 4, y - i * 4,
      w + i * 8, h + i * 8)
  end
end

-- ── Main draw ────────────────────────────────────────────────
function World:draw(x, y, w, h)
  self:_draw_backdrop(x, y, w, h)
  self:_draw_floor(x, y, w, h)

  for _, prop in ipairs(DEFAULT_PROPS) do
    local enabled = false
    for _, k in ipairs(self.visible_props) do
      if k == prop.key then enabled = true; break end
    end
    if enabled then self:_draw_prop(prop, x, y, w, h) end
  end

  if self.ambient then
    self:_draw_ambient(x, y, w, h)
  end
end

return World