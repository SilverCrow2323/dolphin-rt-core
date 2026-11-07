-- frontend/ui/glyph.lua
-- Procedural drawing of small UI symbols so we never depend on a
-- character being present in the active font.
--
-- v0.9.0 — outlined_printf_wrapped
--   * Nuova funzione M.outlined_printf_wrapped(text, x, y, w, font,
--     fill, outline, ow, align, seed) che disegna testo multi-riga
--     con outline dirty-brush. Usata da compatibility detail popup.
--
-- v0.8.0 — outlined text helpers
--   * M.outlined_print / M.outlined_printf draw text with a "dirty
--     brush" black outline: the glyph is stamped 8 times around the
--     final position with slightly jittered offsets (deterministic
--     via a seed), then drawn in colour on top.

local M = {}

local function set(col, a)
  love.graphics.setColor(col[1], col[2], col[3], a or 1)
end

-- ── Directional triangles ───────────────────────────────────
function M.triangle_right(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.polygon("fill",
    cx - r * 0.55, cy - r,
    cx + r * 0.75, cy,
    cx - r * 0.55, cy + r)
end

function M.triangle_left(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.polygon("fill",
    cx + r * 0.55, cy - r,
    cx - r * 0.75, cy,
    cx + r * 0.55, cy + r)
end

function M.triangle_down(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.polygon("fill",
    cx - r, cy - r * 0.55,
    cx + r, cy - r * 0.55,
    cx,     cy + r * 0.75)
end

function M.triangle_up(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.polygon("fill",
    cx - r, cy + r * 0.55,
    cx + r, cy + r * 0.55,
    cx,     cy - r * 0.75)
end

function M.diamond(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.polygon("fill",
    cx,     cy - r,
    cx + r, cy,
    cx,     cy + r,
    cx - r, cy)
end

function M.square(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.rectangle("fill", cx - r, cy - r, r * 2, r * 2)
end

function M.ring(cx, cy, r, col, alpha, thickness)
  set(col, alpha)
  love.graphics.setLineWidth(thickness or 1.4)
  love.graphics.circle("line", cx, cy, r)
  love.graphics.setLineWidth(1)
end

function M.dot(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.circle("fill", cx, cy, r)
end

function M.check(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.setLineWidth(math.max(1.4, r * 0.45))
  love.graphics.line(
    cx - r * 0.70, cy + r * 0.05,
    cx - r * 0.15, cy + r * 0.60,
    cx + r * 0.80, cy - r * 0.70)
  love.graphics.setLineWidth(1)
end

function M.cross(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.setLineWidth(math.max(1.4, r * 0.45))
  love.graphics.line(cx - r * 0.70, cy - r * 0.70,
    cx + r * 0.70, cy + r * 0.70)
  love.graphics.line(cx + r * 0.70, cy - r * 0.70,
    cx - r * 0.70, cy + r * 0.70)
  love.graphics.setLineWidth(1)
end

function M.pencil(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.setLineWidth(math.max(1.2, r * 0.30))
  love.graphics.line(cx - r * 0.60, cy + r * 0.60, cx + r * 0.60, cy - r * 0.60)
  love.graphics.setLineWidth(math.max(1.0, r * 0.22))
  love.graphics.line(cx - r * 0.72, cy + r * 0.72, cx - r * 0.30, cy + r * 0.30)
  love.graphics.setLineWidth(1)
end

function M.arrow_right(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.setLineWidth(math.max(1.3, r * 0.28))
  love.graphics.line(cx - r, cy, cx + r * 0.55, cy)
  love.graphics.line(cx + r * 0.55, cy, cx + r * 0.05, cy - r * 0.60)
  love.graphics.line(cx + r * 0.55, cy, cx + r * 0.05, cy + r * 0.60)
  love.graphics.setLineWidth(1)
end

function M.arrow_left(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.setLineWidth(math.max(1.3, r * 0.28))
  love.graphics.line(cx + r, cy, cx - r * 0.55, cy)
  love.graphics.line(cx - r * 0.55, cy, cx - r * 0.05, cy - r * 0.60)
  love.graphics.line(cx - r * 0.55, cy, cx - r * 0.05, cy + r * 0.60)
  love.graphics.setLineWidth(1)
end

function M.chevrons(cx, cy, r, col, alpha)
  set(col, alpha)
  love.graphics.setLineWidth(math.max(1.2, r * 0.30))
  love.graphics.line(cx - r, cy - r * 0.6, cx - r * 0.4, cy)
  love.graphics.line(cx - r * 0.4, cy, cx - r, cy + r * 0.6)
  love.graphics.line(cx + r * 0.4, cy - r * 0.6, cx + r, cy)
  love.graphics.line(cx + r, cy, cx + r * 0.4, cy + r * 0.6)
  love.graphics.setLineWidth(1)
end

-- ═════════════════════════════════════════════════════════════
--  OUTLINED TEXT
-- ═════════════════════════════════════════════════════════════
local OUTLINE_OFFS = {
  { -1, -1 }, { 0, -1 }, { 1, -1 },
  { -1,  0 },            { 1,  0 },
  { -1,  1 }, { 0,  1 }, { 1,  1 },
}

local function jitter(seed, idx)
  local v = math.sin((seed + idx) * 12.9898 + idx * 78.233) * 43758.5453
  return (v - math.floor(v)) * 2 - 1
end

function M.outlined_print(text, x, y, font, fill, outline, w, seed)
  if not text then return end
  love.graphics.setFont(font)
  outline = outline or { 0, 0, 0 }
  w       = w or 1.6
  seed    = seed or 0

  love.graphics.setColor(outline[1], outline[2], outline[3], 1)
  for i, off in ipairs(OUTLINE_OFFS) do
    local dx = off[1] * w + jitter(seed, i * 3 + 1) * 0.9
    local dy = off[2] * w + jitter(seed, i * 3 + 2) * 0.9
    love.graphics.print(text, x + dx, y + dy)
  end

  love.graphics.setColor(fill[1], fill[2], fill[3], 1)
  love.graphics.print(text, x, y)
end

function M.outlined_printf(text, x, y, w, font, fill, outline, ow, align, seed)
  if not text then return end
  love.graphics.setFont(font)
  local tw = font:getWidth(text)
  local tx
  if align == "center" then tx = x + (w - tw) / 2
  elseif align == "right" then tx = x + w - tw
  else tx = x end
  M.outlined_print(text, tx, y, font, fill, outline, ow, seed)
end

-- Nuova utility: outlined text multi-riga (usa printf per il wrap).
function M.outlined_printf_wrapped(text, x, y, w, font, fill, outline, ow, align, seed)
  if not text then return end
  love.graphics.setFont(font)
  outline = outline or { 0, 0, 0 }
  ow      = ow or 1.6
  align   = align or "left"
  seed    = seed or 0

  love.graphics.setColor(outline[1], outline[2], outline[3], 1)
  for i, off in ipairs(OUTLINE_OFFS) do
    local dx = off[1] * ow + jitter(seed, i * 3 + 1) * 0.9
    local dy = off[2] * ow + jitter(seed, i * 3 + 2) * 0.9
    love.graphics.printf(text, x + dx, y + dy, w, align)
  end

  love.graphics.setColor(fill[1], fill[2], fill[3], 1)
  love.graphics.printf(text, x, y, w, align)
end

return M