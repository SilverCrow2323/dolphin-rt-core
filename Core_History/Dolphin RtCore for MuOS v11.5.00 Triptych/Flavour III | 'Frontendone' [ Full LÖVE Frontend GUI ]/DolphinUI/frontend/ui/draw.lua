-- frontend/ui/draw.lua — primitive "rough cyberpunk".
--
-- v0.9.0
--   * D.rough_rect() honours theme.outline_boost. Every rough border
--     in the app is multiplied by the current theme's boost value,
--     so the Wii theme gets chunkier lines without a single screen
--     having to pass a bigger thickness. GC's boost is 1.0, so GC
--     screens are visually unchanged.

local D = {}

local function noise(seed, i, s)
  local v = math.sin((seed + i * 12.9898 + s * 78.233)) * 43758.5453
  return v - math.floor(v)
end

local function theme_boost()
  local ok, State = pcall(require, "state")
  if not ok or not State or not State.theme then return 1.0 end
  return State.theme.outline_boost or 1.0
end

function D.rough_rect(x, y, w, h, opts)
  opts = opts or {}
  local jit   = opts.jitter or 1.2
  local thick = (opts.thickness or 2) * theme_boost()
  local seed  = opts.seed or 1
  local steps = opts.steps or 8
  local cut   = opts.cut or 0

  local pts = {}
  local function push(px, py, i, side)
    local n = (noise(seed, i, side) * 2 - 1) * jit
    if side == 1 or side == 3 then pts[#pts+1] = { px, py + n }
    else pts[#pts+1] = { px + n, py } end
  end

  local x0, x1 = x, x + w
  local y0, y1 = y, y + h
  if cut > 0 then x0 = x0 + cut end
  for i = 0, steps do push(x0 + (x1 - x0) * i / steps, y, i, 1) end
  for i = 0, steps do
    local yy = y + (y1 - y) * i / steps
    if cut > 0 and i == steps then yy = y1 - cut end
    push(x + w, yy, i + steps, 2)
  end
  local bx0 = x + w
  local bx1 = x
  if cut > 0 then bx0 = bx0 - cut end
  for i = 0, steps do
    push(bx0 + (bx1 - bx0) * i / steps, y + h, i + steps*2, 3)
  end
  for i = 0, steps do
    local yy = y + h - (y1 - y) * i / steps
    if cut > 0 and i == steps then yy = y + cut end
    push(x, yy, i + steps*3, 4)
  end
  pts[#pts+1] = pts[1]

  love.graphics.setLineWidth(thick)
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i+1]
    love.graphics.line(a[1], a[2], b[1], b[2])
  end
  love.graphics.setLineWidth(1)
end

function D.cyber_box(x, y, w, h, fill, border, opts)
  opts = opts or {}
  love.graphics.setColor(fill)
  love.graphics.rectangle("fill", x, y, w, h,
    opts.radius or 3, opts.radius or 3)
  if border then
    love.graphics.setColor(border)
    D.rough_rect(x, y, w, h, opts)
  end
  if opts.scanline ~= false then
    love.graphics.setColor(0, 0, 0, 0.06)
    for yy = y + 2, y + h - 2, 3 do
      love.graphics.line(x + 2, yy, x + w - 2, yy)
    end
  end
end

function D.glow(cx, cy, r, col, intensity)
  intensity = intensity or 1
  for i = 4, 1, -1 do
    local t = i / 4
    love.graphics.setColor(col[1], col[2], col[3],
      0.10 * intensity * (1 - t))
    love.graphics.arc("fill", "pie", cx, cy, r * t, 0, math.pi * 2)
  end
end

function D.scanlines(w, h, alpha)
  love.graphics.setColor(0, 0, 0, alpha or 0.07)
  for y = 0, h, 3 do love.graphics.line(0, y, w, y) end
end

function D.vignette(w, h, strength)
  strength = strength or 0.6
  for i = 1, 4 do
    local a = strength * (i / 4) * 0.18
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.rectangle("line", -i*4, -i*4, w + i*8, h + i*8)
  end
end

function D.corner_brackets(x, y, w, h, col, size)
  size = size or 12
  love.graphics.setColor(col)
  love.graphics.setLineWidth(2 * theme_boost())
  love.graphics.line(x, y + size, x, y); love.graphics.line(x, y, x + size, y)
  love.graphics.line(x + w - size, y, x + w, y)
  love.graphics.line(x + w, y, x + w, y + size)
  love.graphics.line(x + w, y + h - size, x + w, y + h)
  love.graphics.line(x + w, y + h, x + w - size, y + h)
  love.graphics.line(x + size, y + h, x, y + h)
  love.graphics.line(x, y + h, x, y + h - size)
  love.graphics.setLineWidth(1)
end

function D.metal_support(x, y, w, h, col)
  love.graphics.setColor(col[1], col[2], col[3], 0.85)
  love.graphics.rectangle("fill", x, y, w, h)
  love.graphics.setColor(
    math.min(1, col[1]*1.3), math.min(1, col[2]*1.3),
    math.min(1, col[3]*1.3), 0.5)
  love.graphics.rectangle("fill", x, y, w, h * 0.15)
  love.graphics.setColor(0, 0, 0, 0.4)
  love.graphics.rectangle("fill", x, y + h - 2, w, 2)
  love.graphics.setColor(0.7, 0.7, 0.75, 0.9)
  local n = math.max(1, math.floor(w / 40))
  for i = 1, n do
    local rx = x + (i - 0.5) * (w / n)
    love.graphics.circle("fill", rx, y + h/2, 2.5)
  end
end

return D