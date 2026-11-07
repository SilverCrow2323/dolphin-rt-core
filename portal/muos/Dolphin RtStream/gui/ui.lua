-- ui.lua - GameCube 2.5D theme: extruded plates, 3D cube, button icons, animated background.
-- Everything drawn in code except the few PNGs in assets/ and the Orbitron font.
local lg = love.graphics
local M = {}
M.W, M.H = 640, 480
M.fonts = {}

local function v3(h) return { tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255 } end

M.themes = {
  { name = "GAMECUBE", bg = v3("#0a0820"), panel = v3("#1c1745"), line = v3("#5a48a8"),
    text = v3("#e9e7ff"), dim = v3("#8b86b8"), gc = v3("#9f66ff"), wii = v3("#40d9ff"), fav = v3("#ffd24a") },
  { name = "BLAME", bg = {0.020, 0.035, 0.032}, panel = {0.060, 0.105, 0.092}, line = {0.20, 0.42, 0.35},
    text = {0.88, 0.97, 0.92}, dim = {0.46, 0.60, 0.54},
    gc = {0.74, 1.00, 0.30}, wii = {0.20, 0.95, 0.85}, fav = {1.00, 0.82, 0.25} },
  { name = "NEON", bg = {0.030, 0.015, 0.060}, panel = {0.095, 0.050, 0.170}, line = {0.42, 0.20, 0.62},
    text = {0.95, 0.90, 1.00}, dim = {0.58, 0.50, 0.70},
    gc = {1.00, 0.25, 0.75}, wii = {0.20, 0.90, 1.00}, fav = {1.00, 0.85, 0.30} },
  { name = "AMBRA", bg = {0.040, 0.028, 0.012}, panel = {0.110, 0.078, 0.030}, line = {0.50, 0.35, 0.12},
    text = {1.00, 0.90, 0.70}, dim = {0.62, 0.50, 0.32},
    gc = {1.00, 0.70, 0.12}, wii = {1.00, 0.45, 0.15}, fav = {1.00, 0.92, 0.45} },
  { name = "MONO", bg = {0.035, 0.035, 0.040}, panel = {0.105, 0.105, 0.118}, line = {0.36, 0.36, 0.42},
    text = {0.94, 0.94, 0.96}, dim = {0.52, 0.52, 0.58},
    gc = {0.92, 0.92, 0.95}, wii = {0.66, 0.68, 0.74}, fav = {1.00, 0.85, 0.35} },
}
M.th = M.themes[1]
function M.setTheme(i) M.th = M.themes[i] or M.themes[1] end

-- ----------------------------------------------------------------- util
function M.lerp(a, b, t) return a + (b - a) * t end
function M.clamp(v, a, b) return math.max(a, math.min(b, v)) end
function M.mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
function M.outCubic(t) t = 1 - M.clamp(t, 0, 1); return 1 - t * t * t end
function M.inCubic(t) t = M.clamp(t, 0, 1); return t * t * t end
function M.outBack(t) t = M.clamp(t, 0, 1) - 1; return 1 + 2.70158 * t * t * t + 1.70158 * t * t end
function M.outBounce(t)
  t = M.clamp(t, 0, 1)
  if t < 1 / 2.75 then return 7.5625 * t * t
  elseif t < 2 / 2.75 then t = t - 1.5 / 2.75; return 7.5625 * t * t + 0.75
  elseif t < 2.5 / 2.75 then t = t - 2.25 / 2.75; return 7.5625 * t * t + 0.9375 end
  t = t - 2.625 / 2.75; return 7.5625 * t * t + 0.984375
end

local WHITE, BLACK = { 1, 1, 1 }, { 0, 0, 0 }

-- ----------------------------------------------------------------- font e immagini
local imgs = {}
function M.img(name)
  local im = imgs[name]
  if im == nil then
    local ok, r = pcall(lg.newImage, "assets/" .. name)
    if ok then r:setFilter("linear", "linear"); im = r else im = false end
    imgs[name] = im
  end
  return im or nil
end

function M.loadFonts()
  local f = M.fonts
  local function orb(sz)
    local ok, ft = pcall(lg.newFont, "assets/OrbitronBold.ttf", sz)
    return ok and ft or lg.newFont(sz)
  end
  f.xs, f.s, f.m, f.l = lg.newFont(13), lg.newFont(17), lg.newFont(22), lg.newFont(30)
  f.ot, f.os, f.om, f.ol, f.oxl = orb(13), orb(15), orb(19), orb(28), orb(54)
end

function M.accent(kind)
  local th = M.th
  if kind == "gc" then return th.gc elseif kind == "wii" then return th.wii end
  if kind == "fav" then return th.fav end
  return th.text
end

function M.c(c, a) lg.setColor(c[1], c[2], c[3], a or 1) end

-- ----------------------------------------------------------------- forme
function M.chamfer(mode, x, y, w, h, c)
  c = c or 8
  lg.polygon(mode, x + c, y, x + w, y, x + w, y + h - c, x + w - c, y + h, x, y + h, x, y + c)
end

function M.brackets(x, y, w, h, l)
  l = l or 10
  lg.line(x, y + l, x, y, x + l, y)
  lg.line(x + w - l, y, x + w, y, x + w, y + l)
  lg.line(x + w, y + h - l, x + w, y + h, x + w - l, y + h)
  lg.line(x + l, y + h, x, y + h, x, y + h - l)
end

function M.text(str, x, y, font, col, a)
  lg.setFont(font); M.c(col, a)
  lg.print(str, math.floor(x), math.floor(y))
end

function M.textf(str, x, y, w, align, font, col, a)
  lg.setFont(font); M.c(col, a)
  lg.printf(str, math.floor(x), math.floor(y), w, align)
end

-- testo con ombra scura sotto (leggibile sopra i cubi dello sfondo)
function M.texts(str, x, y, font, col, a)
  lg.setFont(font)
  lg.setColor(0, 0, 0, 0.6 * (a or 1)); lg.print(str, math.floor(x) + 2, math.floor(y) + 2)
  M.c(col, a); lg.print(str, math.floor(x), math.floor(y))
end

function M.fit(str, font, w)
  if font:getWidth(str) <= w then return str end
  while #str > 1 and font:getWidth(str .. "..") > w do str = str:sub(1, -2) end
  return str .. ".."
end

function M.chip(str, x, y, col, a, font)
  local f = font or M.fonts.xs
  local w = f:getWidth(str) + 18
  local h = f:getHeight() + 8
  a = a or 1
  lg.setColor(col[1], col[2], col[3], 0.22 * a); M.chamfer("fill", x, y, w, h, 5)
  lg.setColor(col[1], col[2], col[3], 0.95 * a); lg.setLineWidth(1.5)
  M.chamfer("line", x + 0.5, y + 0.5, w - 1, h - 1, 5)
  lg.setFont(f); lg.printf(str, x, y + 4, w, "center")
  lg.setLineWidth(1)
  return x + w + 8
end

-- extruded plate (light from top-left): face + extrusion steps + shadow
function M.plate(x, y, w, h, acc, o)
  o = o or {}
  local th = M.th
  local D, a = o.depth or 6, o.alpha or 1
  local face = o.face or th.panel
  acc = acc or th.line
  lg.setColor(0, 0, 0, 0.34 * a); M.chamfer("fill", x + D + 3, y + D + 4, w, h, 9)
  local lt, dk = M.mix(face, WHITE, 0.10), M.mix(face, BLACK, 0.80)
  for k = D, 1, -1 do
    local c = M.mix(lt, dk, k / D)
    lg.setColor(c[1], c[2], c[3], a); M.chamfer("fill", x + k, y + k, w, h, 9)
  end
  lg.setColor(face[1], face[2], face[3], a); M.chamfer("fill", x, y, w, h, 9)
  if o.glow then
    lg.setColor(acc[1], acc[2], acc[3], o.glow * a); M.chamfer("fill", x, y, w, h, 9)
  end
  local hi = M.mix(acc, WHITE, 0.55)
  lg.setLineWidth(1.5)
  lg.setColor(hi[1], hi[2], hi[3], 0.9 * a); lg.line(x + 9, y + 1, x + w - 1, y + 1)
  lg.setColor(hi[1], hi[2], hi[3], 0.45 * a); lg.line(x + 1, y + 9, x + 1, y + h - 1)
  local ed = M.mix(acc, face, o.sel and 0.1 or 0.5)
  lg.setColor(ed[1], ed[2], ed[3], a); M.chamfer("line", x + 0.5, y + 0.5, w - 1, h - 1, 9)
  lg.setLineWidth(1)
end

-- cover thickness (top and right faces, oblique projection)
function M.slab(x, y, w, h, acc, d, a)
  a = a or 1
  local dx, dy = d, -d * 0.7
  local r, t = M.mix(acc, BLACK, 0.55), M.mix(acc, WHITE, 0.30)
  lg.setColor(r[1], r[2], r[3], a); lg.polygon("fill", x + w, y, x + w + dx, y + dy, x + w + dx, y + h + dy, x + w, y + h)
  lg.setColor(t[1], t[2], t[3], a); lg.polygon("fill", x, y, x + dx, y + dy, x + w + dx, y + dy, x + w, y)
end

-- zig-zag bolt (boot)
function M.bolt(x1, y1, x2, y2, seg, jit, seed)
  local pts = { x1, y1 }
  local rnd = love.math.newRandomGenerator(seed or 1)
  for i = 1, seg - 1 do
    local t = i / seg
    pts[#pts + 1] = x1 + (x2 - x1) * t + (rnd:random() - 0.5) * jit
    pts[#pts + 1] = y1 + (y2 - y1) * t + (rnd:random() - 0.5) * jit
  end
  pts[#pts + 1], pts[#pts + 2] = x2, y2
  lg.line(pts)
end

-- ----------------------------------------------------------------- cubo 3D che ruota
local CV = { { -1, -1, -1 }, { 1, -1, -1 }, { 1, 1, -1 }, { -1, 1, -1 }, { -1, -1, 1 }, { 1, -1, 1 }, { 1, 1, 1 }, { -1, 1, 1 } }
local CF = { { { 1, 2, 3, 4 }, { 0, 0, -1 } }, { { 5, 6, 7, 8 }, { 0, 0, 1 } }, { { 1, 2, 6, 5 }, { 0, -1, 0 } },
  { { 3, 4, 8, 7 }, { 0, 1, 0 } }, { { 2, 3, 7, 6 }, { 1, 0, 0 } }, { { 1, 4, 8, 5 }, { -1, 0, 0 } } }
function M.cube3d(cx, cy, s, ay, ax, base, a)
  ax = ax or 0.55
  base = base or M.th.gc
  a = a or 1
  local ca, sa, cxx, sx = math.cos(ay), math.sin(ay), math.cos(ax), math.sin(ax)
  local function rot(x, y, z)
    local x1, z1 = x * ca + z * sa, -x * sa + z * ca
    return x1, y * cxx - z1 * sx, y * sx + z1 * cxx
  end
  local pts = {}
  for i, v in ipairs(CV) do local x, y, z = rot(v[1], v[2], v[3]); pts[i] = { x, y, z } end
  local faces = {}
  for _, f in ipairs(CF) do
    local nx, ny, nz = rot(f[2][1], f[2][2], f[2][3])
    if nz > 0 then
      local br = 0.42 + 0.58 * math.max(0, nx * -0.45 + ny * -0.65 + nz * 0.62)
      faces[#faces + 1] = { nz, f[1], br }
    end
  end
  table.sort(faces, function(p, q) return p[1] < q[1] end)
  local edge = M.mix(base, WHITE, 0.65)
  for _, f in ipairs(faces) do
    local poly = {}
    for _, i in ipairs(f[2]) do poly[#poly + 1] = cx + pts[i][1] * s; poly[#poly + 1] = cy + pts[i][2] * s end
    local c = M.mix(BLACK, base, math.min(1, f[3] * 1.12))
    lg.setColor(c[1], c[2], c[3], a); lg.polygon("fill", poly)
    if f[3] > 0.85 then
      local g = M.mix(c, WHITE, 0.30)
      lg.setColor(g[1], g[2], g[3], 0.8 * a)
      lg.polygon("fill", poly[1], poly[2], (poly[1] + poly[3]) / 2, (poly[2] + poly[4]) / 2,
        (poly[1] + poly[7]) / 2, (poly[2] + poly[8]) / 2)
    end
    lg.setColor(edge[1], edge[2], edge[3], a); lg.setLineWidth(math.max(1.5, s / 18)); lg.polygon("line", poly)
  end
  lg.setLineWidth(1)
end

-- ----------------------------------------------------------------- icone azione
local star = {}
for i = 0, 9 do
  local r = (i % 2 == 0) and 1 or 0.42
  local a = -math.pi / 2 + i * math.pi / 5
  star[#star + 1] = math.cos(a) * r
  star[#star + 1] = math.sin(a) * r
end
local starTris
local function getStarTris()
  if not starTris then
    local ok, tr = pcall(love.math.triangulate, star)
    starTris = (ok and tr) or {}
  end
  return starTris
end

local function ln(w) lg.setLineWidth(w) end
local I = {}

function I.dot(x, y, s) lg.circle("fill", x, y, s * 0.3) end
function I.search(x, y, s)
  ln(1.8)
  lg.circle("line", x - s * 0.2, y - s * 0.2, s * 0.65)
  lg.line(x + s * 0.25, y + s * 0.25, x + s * 0.85, y + s * 0.85)
  ln(1.5)
end
function I.play(x, y, s) lg.polygon("fill", x - s * 0.5, y - s * 0.75, x - s * 0.5, y + s * 0.75, x + s * 0.8, y) end
function I.chevron(x, y, s)
  ln(2.6)
  lg.line(x - s * 0.4, y - s, x + s * 0.6, y, x - s * 0.4, y + s)
  ln(1.5)
end
function I.back(x, y, s)
  ln(2); lg.line(x + s * 0.8, y, x - s * 0.6, y)
  lg.line(x - s * 0.1, y - s * 0.7, x - s * 0.8, y, x - s * 0.1, y + s * 0.7); ln(1.5)
end
function I.close(x, y, s)
  ln(2); lg.line(x - s * 0.7, y - s * 0.7, x + s * 0.7, y + s * 0.7)
  lg.line(x - s * 0.7, y + s * 0.7, x + s * 0.7, y - s * 0.7); ln(1.5)
end
function I.check(x, y, s) ln(2.2); lg.line(x - s * 0.8, y, x - s * 0.2, y + s * 0.6, x + s * 0.8, y - s * 0.6); ln(1.5) end
function I.menu(x, y, s)
  ln(2)
  for k = -1, 1 do lg.line(x - s * 0.8, y + k * s * 0.6, x + s * 0.8, y + k * s * 0.6) end
  ln(1.5)
end
function I.star(x, y, s, on)
  lg.push(); lg.translate(x, y); lg.scale(s * 1.05)
  if on then
    for _, tri in ipairs(getStarTris()) do lg.polygon("fill", tri) end
  else
    ln(1.6 / (s * 1.05)); lg.polygon("line", star)
  end
  lg.pop(); ln(1.5)
end
function I.sync(x, y, s)
  local r = s * 0.8
  ln(1.8)
  for k = 0, 1 do
    local a0 = k * math.pi + 0.3
    local a1 = a0 + math.pi * 0.75
    lg.arc("line", "open", x, y, r, a0, a1, 12)
    local px, py = x + math.cos(a1) * r, y + math.sin(a1) * r
    local tx, ty = -math.sin(a1), math.cos(a1)
    local nx, ny = math.cos(a1), math.sin(a1)
    lg.polygon("fill", px + tx * s * 0.55, py + ty * s * 0.55, px + nx * s * 0.45, py + ny * s * 0.45,
      px - nx * s * 0.45, py - ny * s * 0.45)
  end
  ln(1.5)
end
function I.swap(x, y, s)
  ln(1.8)
  lg.line(x - s * 0.8, y - s * 0.45, x + s * 0.5, y - s * 0.45)
  lg.polygon("fill", x + s * 0.95, y - s * 0.45, x + s * 0.3, y - s * 0.95, x + s * 0.3, y + s * 0.05)
  lg.line(x + s * 0.8, y + s * 0.45, x - s * 0.5, y + s * 0.45)
  lg.polygon("fill", x - s * 0.95, y + s * 0.45, x - s * 0.3, y - s * 0.05, x - s * 0.3, y + s * 0.95)
  ln(1.5)
end
function I.updown(x, y, s)
  lg.polygon("fill", x, y - s, x - s * 0.6, y - s * 0.15, x + s * 0.6, y - s * 0.15)
  lg.polygon("fill", x, y + s, x - s * 0.6, y + s * 0.15, x + s * 0.6, y + s * 0.15)
end
function I.page(x, y, s)
  ln(2)
  lg.line(x - s * 0.7, y - s * 0.9, x, y - s * 0.2, x + s * 0.7, y - s * 0.9)
  lg.line(x - s * 0.7, y + s * 0.1, x, y + s * 0.8, x + s * 0.7, y + s * 0.1)
  ln(1.5)
end
function I.info(x, y, s)
  ln(1.6); lg.circle("line", x, y, s)
  lg.line(x, y - s * 0.05, x, y + s * 0.5); lg.circle("fill", x, y - s * 0.45, 1.4); ln(1.5)
end
function I.gear(x, y, s)
  ln(2.4)
  for k = 0, 7 do
    local a = k * math.pi / 4
    lg.line(x + math.cos(a) * s * 0.65, y + math.sin(a) * s * 0.65, x + math.cos(a) * s, y + math.sin(a) * s)
  end
  ln(1.6); lg.circle("line", x, y, s * 0.62); lg.circle("fill", x, y, s * 0.2); ln(1.5)
end
function I.screen(x, y, s)
  ln(1.6); lg.rectangle("line", x - s, y - s * 0.8, s * 2, s * 1.35, 2, 2)
  lg.line(x, y + s * 0.55, x, y + s * 0.9); lg.line(x - s * 0.5, y + s * 0.9, x + s * 0.5, y + s * 0.9); ln(1.5)
end
function I.grid(x, y, s)
  local h = s * 0.8
  lg.rectangle("fill", x - s, y - s, h, h); lg.rectangle("fill", x + s - h, y - s, h, h)
  lg.rectangle("fill", x - s, y + s - h, h, h); lg.rectangle("fill", x + s - h, y + s - h, h, h)
end
function I.list(x, y, s)
  ln(2)
  for k = -1, 1 do
    lg.circle("fill", x - s * 0.8, y + k * s * 0.7, 1.4)
    lg.line(x - s * 0.4, y + k * s * 0.7, x + s * 0.9, y + k * s * 0.7)
  end
  ln(1.5)
end
function I.wrench(x, y, s)
  ln(3); lg.line(x - s * 0.8, y + s * 0.8, x + s * 0.2, y - s * 0.2)
  ln(2); lg.circle("line", x + s * 0.45, y - s * 0.45, s * 0.5); ln(1.5)
end
function I.chart(x, y, s)
  lg.rectangle("fill", x - s * 0.9, y + s * 0.1, s * 0.5, s * 0.9)
  lg.rectangle("fill", x - s * 0.25, y - s * 0.4, s * 0.5, s * 1.4)
  lg.rectangle("fill", x + s * 0.4, y - s * 0.9, s * 0.5, s * 1.9)
end
function I.sort(x, y, s)
  ln(2.4)
  lg.line(x - s * 0.9, y - s * 0.7, x + s * 0.9, y - s * 0.7)
  lg.line(x - s * 0.9, y, x + s * 0.4, y)
  lg.line(x - s * 0.9, y + s * 0.7, x - s * 0.1, y + s * 0.7); ln(1.5)
end
function I.link(x, y, s)
  ln(1.8); lg.circle("line", x - s * 0.45, y, s * 0.55); lg.circle("line", x + s * 0.45, y, s * 0.55); ln(1.5)
end
function I.trash(x, y, s)
  ln(1.8); lg.line(x - s * 0.9, y - s * 0.6, x + s * 0.9, y - s * 0.6)
  lg.line(x - s * 0.3, y - s * 0.6, x - s * 0.3, y - s * 0.95, x + s * 0.3, y - s * 0.95, x + s * 0.3, y - s * 0.6)
  lg.rectangle("line", x - s * 0.7, y - s * 0.6, s * 1.4, s * 1.6); ln(1.5)
end
function I.keyboard(x, y, s)
  ln(1.6); lg.rectangle("line", x - s, y - s * 0.6, s * 2, s * 1.2, 2, 2)
  for k = -1, 1 do lg.circle("fill", x + k * s * 0.55, y - s * 0.15, 1.2) end
  lg.line(x - s * 0.5, y + s * 0.3, x + s * 0.5, y + s * 0.3); ln(1.5)
end
function I.wifi(x, y, s)
  ln(1.8)
  for k = 1, 3 do lg.arc("line", "open", x, y + s * 0.7, s * 0.5 * k, -math.pi * 0.85, -math.pi * 0.15, 10) end
  lg.circle("fill", x, y + s * 0.7, 1.6); ln(1.5)
end
function I.clock(x, y, s)
  ln(1.6); lg.circle("line", x, y, s); lg.line(x, y, x, y - s * 0.65); lg.line(x, y, x + s * 0.45, y + s * 0.2); ln(1.5)
end
function I.disc(x, y, s)
  ln(1.6); lg.circle("line", x, y, s); lg.circle("line", x, y, s * 0.3); ln(1.5)
end
function I.gamepad(x, y, s)
  ln(1.8)
  lg.polygon("line", x - s, y - s * 0.45, x + s, y - s * 0.45, x + s * 1.1, y + s * 0.5, x + s * 0.55, y + s * 0.7,
    x + s * 0.25, y + s * 0.2, x - s * 0.25, y + s * 0.2, x - s * 0.55, y + s * 0.7, x - s * 1.1, y + s * 0.5)
  lg.line(x - s * 0.6, y - s * 0.2, x - s * 0.6, y + s * 0.1); lg.line(x - s * 0.75, y - s * 0.05, x - s * 0.45, y - s * 0.05)
  lg.circle("fill", x + s * 0.55, y - s * 0.12, 1.4); lg.circle("fill", x + s * 0.8, y + s * 0.05, 1.4)
  ln(1.5)
end
function I.bolt(x, y, s)
  ln(2); lg.line(x + s * 0.3, y - s, x - s * 0.5, y + s * 0.1, x + s * 0.2, y + s * 0.1, x - s * 0.3, y + s); ln(1.5)
end

-- icona generica: nome, centro, "raggio", colore, alpha, stato on
function M.icon(name, x, y, s, col, a, on)
  s = s or 10
  M.c(col or M.th.text, a)
  lg.setLineWidth(1.8)
  local f = I[name] or I.dot
  f(x, y, s, on)
  lg.setLineWidth(1)
end

-- ----------------------------------------------------------------- icone tasti (grandi)
local FACE = { A = {0.35, 0.90, 0.45}, B = {0.95, 0.38, 0.38}, X = {0.38, 0.66, 1.00}, Y = {1.00, 0.80, 0.28} }
local KR, KH = 13, 26     -- raggio tasto tondo, altezza pillola

function M.key(name, x, cy, dry)
  local f = M.fonts.xs
  if FACE[name] then
    if not dry then
      local c = FACE[name]
      lg.setColor(c[1], c[2], c[3], 0.28); lg.circle("fill", x + KR, cy, KR)
      lg.setColor(c[1], c[2], c[3], 1); lg.setLineWidth(2); lg.circle("line", x + KR, cy, KR); lg.setLineWidth(1)
      lg.setFont(M.fonts.ot); lg.setColor(1, 1, 1, 1); lg.printf(name, x, cy - M.fonts.ot:getHeight() / 2, KR * 2, "center")
    end
    return KR * 2
  elseif name == "DPAD" or name == "DPADV" or name == "DPADH" then
    if not dry then
      local cx = x + KR
      M.c(M.th.dim, 1)
      lg.rectangle("fill", cx - 4.5, cy - KR, 9, KR * 2, 2, 2); lg.rectangle("fill", cx - KR, cy - 4.5, KR * 2, 9, 2, 2)
      M.c(M.th.text, 1)
      if name ~= "DPADH" then lg.rectangle("fill", cx - 4.5, cy - KR, 9, 9); lg.rectangle("fill", cx - 4.5, cy + KR - 9, 9, 9) end
      if name ~= "DPADV" then lg.rectangle("fill", cx - KR, cy - 4.5, 9, 9); lg.rectangle("fill", cx + KR - 9, cy - 4.5, 9, 9) end
    end
    return KR * 2
  end
  local w = math.max(34, f:getWidth(name) + 18)
  if not dry then
    lg.setColor(1, 1, 1, 0.14); lg.rectangle("fill", x, cy - KH / 2, w, KH, KH / 2, KH / 2)
    M.c(M.th.text, 0.95); lg.setLineWidth(1.8); lg.rectangle("line", x, cy - KH / 2, w, KH, KH / 2, KH / 2); lg.setLineWidth(1)
    lg.setFont(f); lg.printf(name, x, cy - f:getHeight() / 2, w, "center")
  end
  return w
end

-- footer: items = { {k = {"A"}, p = "play", on = bool}, ... }  (si rimpicciolisce da solo se troppo largo)
function M.footer(items, cy)
  cy = cy or 453
  local GK, GI, PICT = 4, 14, 26
  local f = M.fonts.xs
  -- misura larghezza etichetta: icona (PICT) o testo (it.txt)
  local function labelW(it)
    if it.txt then return f:getWidth(it.txt) + 6 end
    return PICT
  end
  local total = 0
  for idx, it in ipairs(items) do
    local w = 0
    for k, kn in ipairs(it.k) do w = w + M.key(kn, 0, 0, true) + (k > 1 and GK or 0) end
    total = total + w + 7 + labelW(it) + (idx > 1 and GI or 0)
  end
  local sc = math.min(1, 622 / total)
  lg.push()
  lg.translate(M.W / 2, cy); lg.scale(sc); lg.translate(-total / 2, 0)
  local x = 0
  for idx, it in ipairs(items) do
    if idx > 1 then
      lg.setColor(1, 1, 1, 0.14); lg.rectangle("fill", x + GI / 2 - 0.5, -11, 1, 22)
      x = x + GI
    end
    for k, kn in ipairs(it.k) do
      if k > 1 then x = x + GK end
      x = x + M.key(kn, x, 0)
    end
    if it.txt then
      lg.setFont(f); M.c(it.col or M.th.text, it.on and 0.6 or 0.97)
      lg.print(it.txt, x + 7, -f:getHeight() / 2)
    else
      M.icon(it.p, x + 7 + PICT / 2, 0, 10, it.col or M.th.text, 0.97, it.on)
    end
    x = x + 7 + labelW(it)
  end
  lg.pop()
end

-- ----------------------------------------------------------------- background: gradient, perspective floor, cubes
local cubes = {}
function M.initBg()
  local r = love.math.newRandomGenerator(11)
  local tints = { "violet", "indigo", "silver", "cyan", "rt", "indigo", "violet" }
  local sizes = { 24, 40, 64, 96 }
  for i = 1, 14 do
    local size = sizes[r:random(1, 4)]
    cubes[i] = { x = r:random(), y = r:random() * 1.2, size = size, tint = tints[r:random(1, #tints)],
      sp = 0.012 + size / 96 * 0.040, ph = r:random() * 6.3, amp = 8 + size / 6 }
  end
end

function M.bg(t, anim, top, bot)
  local th = M.th
  local W, H = M.W, M.H
  for i = 0, 15 do                                  -- vertical gradient by bands
    local k = i / 15
    local c = M.mix(M.mix(th.bg, th.panel, 0.55), th.bg, k)
    lg.setColor(c[1], c[2], c[3], 1); lg.rectangle("fill", 0, i * H / 16, W, H / 16 + 1)
  end
  local vx, vy = W / 2, 150                         -- perspective floor
  lg.setColor(th.line[1], th.line[2], th.line[3], 0.16)
  for i = -12, 12 do lg.line(vx + i * 8, vy, vx + i * 70, H) end
  for k = 1, 9 do
    local y = vy + (H - vy) * (k / 9) ^ 1.9
    lg.setColor(th.line[1], th.line[2], th.line[3], 0.07 + 0.10 * k / 9); lg.line(0, y, W, y)
  end
  for k = 0, 10 do
    lg.setColor(th.line[1], th.line[2], th.line[3], math.max(0, 0.22 - k * 0.02)); lg.rectangle("fill", 0, vy + k, W, 1)
  end
  for _, c in ipairs(cubes) do
    local img = M.img(string.format("cube_%s_%d.png", c.tint, c.size))
    if img then
      local y = anim and ((c.y - t * c.sp) % 1.3 - 0.15) or c.y % 1.0
      local x = c.x * W + (anim and math.sin(t * 0.7 + c.ph) * c.amp or 0)
      lg.setColor(1, 1, 1, 0.55)
      lg.draw(img, x, y * H, 0, 1, 1, c.size / 2, c.size / 2)
    end
  end
end

function M.vignette()
  for i = 0, 9 do
    lg.setColor(0, 0, 0, (10 - i) * 0.03)
    lg.rectangle("fill", i * 4, 0, 4, M.H); lg.rectangle("fill", M.W - (i + 1) * 4, 0, 4, M.H)
  end
end

local scanCanvas
function M.initScan()
  local ok, cv = pcall(lg.newCanvas, M.W, M.H)
  if ok and cv then
    lg.setCanvas(cv); lg.clear(0, 0, 0, 0); lg.setColor(0, 0, 0, 0.10)
    for y = 0, M.H, 3 do lg.rectangle("fill", 0, y, M.W, 1) end
    lg.setCanvas(); scanCanvas = cv
  else
    scanCanvas = false
  end
end
function M.scanlines()
  if scanCanvas then
    lg.setColor(1, 1, 1, 1); lg.draw(scanCanvas)
  else
    lg.setColor(0, 0, 0, 0.07)
    for y = 0, M.H, 3 do lg.rectangle("fill", 0, y, M.W, 1) end
  end
end

return M
