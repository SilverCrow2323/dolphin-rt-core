-- frontend/ui/button_icons.lua — procedural button badges + rich text.
--
-- v0.5.0 — flush footer anchoring
--   * flush_footer_top() now ignores the caller's y entirely and
--     always returns (screen_h - 28). Previous min(y-6, gh-28) logic
--     silently raised the bar when a screen passed y = H-30 or
--     y = H-40, producing the "footer floats above the bottom" bug.
--
-- Shapes:
--   * circle    — GC face buttons A/B/X/Y/Z (colored per button)
--   * pill      — Wii 1/2/+/- numbers
--   * shoulder  — L1 / R1 (grey flat rounded rect)
--   * trigger   — L2 / R2 (taller silhouette, distinct from L1/R1)
--   * system    — START / SELECT / HOME / MENU (small circle + label below)
--   * dpad      — D-pad cross with 4 arrows (readable)
--   * default   — generic dark pill with letter
--
-- Rich text:
--   BI.draw_rich_text(str, x, y, max_w, font, th, badge_size)
--   Turns "[A] Download   [B] Cancel" into badge+text, word-wrapped.
--   Only whitelisted keys become badges; [Core]/[Hacks]/etc stay literal.

local A = require("assets")
local B = {}

local GLYPH = {
  a = "A", b = "B", x = "X", y = "Y", z = "Z",
  one = "1", two = "2",
  plus = "+", minus = "-",
}

local GC_FACE = {
  a = { color = {0.92, 0.16, 0.16}, letter = {1, 1, 1} },
  b = { color = {0.98, 0.82, 0.16}, letter = {0.15, 0.10, 0.05} },
  x = { color = {0.18, 0.48, 0.94}, letter = {1, 1, 1} },
  y = { color = {0.20, 0.78, 0.32}, letter = {1, 1, 1} },
  z = { color = {0.55, 0.30, 0.85}, letter = {1, 1, 1} },
}

local KEY_ALIAS = {
  ["A"]="a", ["B"]="b", ["X"]="x", ["Y"]="y", ["Z"]="z",
  ["L1"]="l1", ["R1"]="r1", ["L2"]="l2", ["R2"]="r2",
  ["L"]="l1", ["R"]="r1",
  ["START"]="start", ["SELECT"]="select", ["MENU"]="menu",
  ["HOME"]="home", ["+"]="plus", ["-"]="minus",
  ["1"]="one", ["2"]="two",
  ["↑↓"]="dpad", ["←→"]="dpad", ["↑↓←→"]="dpad",
  ["←→↑↓"]="dpad", ["↑↓/←→"]="dpad",
  ["↑"]="dpad", ["↓"]="dpad", ["←"]="dpad", ["→"]="dpad",
  ["D-Pad"]="dpad", ["Dpad"]="dpad", ["D-PAD"]="dpad",
}

local function theme_id_from(th)
  if type(th) == "string" then return th end
  if type(th) == "table" and th.id then return th.id end
  return "gc"
end

local function theme_table_from(th)
  if type(th) == "table" and th.text_dim then return th end
  return nil
end

-- ═════════════════════════════════════════════════════════════
-- SHAPE HELPERS
-- ═════════════════════════════════════════════════════════════

local function draw_dpad(cx, cy, r, is_wii)
  local bg_col = is_wii and {0.94, 0.96, 0.99} or {0.18, 0.19, 0.24}
  local bd_col = is_wii and {0.05, 0.55, 0.88} or {0.42, 0.45, 0.55}
  local mid_col = is_wii and {0.30, 0.65, 0.90} or {0.72, 0.75, 0.82}
  local arr_col = is_wii and {0.05, 0.42, 0.82} or {0.98, 0.99, 1.00}

  love.graphics.setColor(bg_col)
  love.graphics.rectangle("fill", cx - r, cy - r, r*2, r*2, 3, 3)
  love.graphics.setColor(bd_col)
  love.graphics.setLineWidth(1.2)
  love.graphics.rectangle("line", cx - r, cy - r, r*2, r*2, 3, 3)
  love.graphics.setLineWidth(1)

  local arm = r * 0.42
  local len = r * 0.86
  love.graphics.setColor(mid_col)
  love.graphics.rectangle("fill", cx - arm, cy - len, arm*2, len*2, 2, 2)
  love.graphics.rectangle("fill", cx - len, cy - arm, len*2, arm*2, 2, 2)

  local a = arm * 0.55
  love.graphics.setColor(arr_col)
  love.graphics.polygon("fill",
    cx, cy - len + 1,
    cx - a, cy - len + a*1.6,
    cx + a, cy - len + a*1.6)
  love.graphics.polygon("fill",
    cx, cy + len - 1,
    cx - a, cy + len - a*1.6,
    cx + a, cy + len - a*1.6)
  love.graphics.polygon("fill",
    cx - len + 1, cy,
    cx - len + a*1.6, cy - a,
    cx - len + a*1.6, cy + a)
  love.graphics.polygon("fill",
    cx + len - 1, cy,
    cx + len - a*1.6, cy - a,
    cx + len - a*1.6, cy + a)
end

local function draw_circle_badge(cx, cy, r, fill, border, letter, letter_col, gloss)
  love.graphics.setColor(0, 0, 0, 0.40)
  love.graphics.circle("fill", cx + 1, cy + 1.5, r)

  love.graphics.setColor(fill[1], fill[2], fill[3], 1)
  love.graphics.circle("fill", cx, cy, r)

  if gloss then
    love.graphics.setColor(gloss[1], gloss[2], gloss[3], gloss[4] or 0.35)
    love.graphics.arc("fill", "pie", cx, cy, r - 1, math.pi, math.pi * 2)
  end

  love.graphics.setColor(border[1], border[2], border[3], 1)
  love.graphics.setLineWidth(1.4)
  love.graphics.circle("line", cx, cy, r)
  love.graphics.setLineWidth(1)

  if letter then
    local fsize = math.max(9, math.floor(r * 1.15))
    local font = A.font("assets/fonts/Oxanium-Bold.ttf", fsize)
    love.graphics.setFont(font)
    local lw = font:getWidth(letter)
    local lh = font:getHeight()
    love.graphics.setColor(0, 0, 0, 0.20)
    love.graphics.print(letter,
      math.floor(cx - lw / 2),
      math.floor(cy - lh / 2) + 1)
    love.graphics.setColor(letter_col[1], letter_col[2], letter_col[3], 1)
    love.graphics.print(letter,
      math.floor(cx - lw / 2),
      math.floor(cy - lh / 2))
  end
end

local function draw_shoulder(cx, cy, r, label, is_wii)
  local w = r * 2.0
  local h = r * 1.1
  local fill   = is_wii and {0.94, 0.96, 0.99} or {0.30, 0.32, 0.40}
  local border = is_wii and {0.05, 0.55, 0.88} or {0.55, 0.58, 0.68}
  local text   = is_wii and {0.05, 0.42, 0.82} or {0.95, 0.97, 1.00}

  local bx = cx - w / 2
  local by = cy - h / 2

  love.graphics.setColor(0, 0, 0, 0.40)
  love.graphics.rectangle("fill", bx + 1, by + 1.5, w, h, 4, 4)
  love.graphics.setColor(fill)
  love.graphics.rectangle("fill", bx, by, w, h, 4, 4)
  love.graphics.setColor(border)
  love.graphics.setLineWidth(1.2)
  love.graphics.rectangle("line", bx, by, w, h, 4, 4)
  love.graphics.setLineWidth(1)

  local font = A.font("assets/fonts/Oxanium-Bold.ttf",
    math.max(9, math.floor(h * 0.75)))
  love.graphics.setFont(font)
  love.graphics.setColor(text)
  love.graphics.printf(label, bx,
    by + math.floor((h - font:getHeight()) / 2) + 1, w, "center")
end

local function draw_trigger(cx, cy, r, label, is_wii)
  local w = r * 1.9
  local h = r * 1.5
  local fill   = is_wii and {0.86, 0.90, 0.95} or {0.24, 0.26, 0.34}
  local border = is_wii and {0.05, 0.55, 0.88} or {0.50, 0.53, 0.62}
  local text   = is_wii and {0.05, 0.42, 0.82} or {0.95, 0.97, 1.00}

  local bx = cx - w / 2
  local by = cy - h / 2

  love.graphics.setColor(0, 0, 0, 0.40)
  love.graphics.rectangle("fill", bx + 1, by + 1.5, w, h, 8, 4)
  love.graphics.setColor(fill)
  love.graphics.rectangle("fill", bx, by, w, h, 8, 4)
  love.graphics.setColor(border)
  love.graphics.setLineWidth(1.2)
  love.graphics.rectangle("line", bx, by, w, h, 8, 4)
  love.graphics.setLineWidth(1)

  love.graphics.setColor(border[1], border[2], border[3], 0.5)
  love.graphics.line(bx + 4, by + h * 0.5, bx + w - 4, by + h * 0.5)

  local font = A.font("assets/fonts/Oxanium-Bold.ttf",
    math.max(8, math.floor(h * 0.55)))
  love.graphics.setFont(font)
  love.graphics.setColor(text)
  love.graphics.printf(label, bx,
    by + math.floor((h - font:getHeight()) / 2) + 1, w, "center")
end

local function draw_system(cx, cy, r, label, is_wii)
  local btn_r  = r * 0.55
  local btn_cy = cy - r * 0.30

  local fill   = is_wii and {1.00, 1.00, 1.00} or {0.36, 0.38, 0.46}
  local border = is_wii and {0.05, 0.55, 0.88} or {0.62, 0.65, 0.74}
  local text   = is_wii and {0.05, 0.42, 0.82} or {0.98, 0.99, 1.00}

  love.graphics.setColor(0, 0, 0, 0.40)
  love.graphics.circle("fill", cx + 0.8, btn_cy + 1.2, btn_r)
  love.graphics.setColor(fill)
  love.graphics.circle("fill", cx, btn_cy, btn_r)
  love.graphics.setColor(border)
  love.graphics.setLineWidth(1.2)
  love.graphics.circle("line", cx, btn_cy, btn_r)
  love.graphics.setLineWidth(1)

  local font = A.font("assets/fonts/Oxanium-Bold.ttf", 7)
  love.graphics.setFont(font)
  love.graphics.setColor(text)
  local lw = font:getWidth(label)
  love.graphics.print(label,
    math.floor(cx - lw / 2),
    math.floor(btn_cy + btn_r + 1))
end

local function draw_pill(cx, cy, r, letter, is_wii)
  local w = r * 1.6
  local h = r * 1.4
  local bx = cx - w / 2
  local by = cy - h / 2
  local fill   = is_wii and {1, 1, 1} or {0.30, 0.32, 0.40}
  local border = is_wii and {0.05, 0.55, 0.88} or {0.55, 0.58, 0.68}
  local text   = is_wii and {0.05, 0.42, 0.82} or {0.98, 0.99, 1.00}

  love.graphics.setColor(0, 0, 0, 0.40)
  love.graphics.rectangle("fill", bx + 1, by + 1.5, w, h, h / 2)
  love.graphics.setColor(fill)
  love.graphics.rectangle("fill", bx, by, w, h, h / 2)
  love.graphics.setColor(border)
  love.graphics.setLineWidth(1.2)
  love.graphics.rectangle("line", bx, by, w, h, h / 2)
  love.graphics.setLineWidth(1)

  local font = A.font("assets/fonts/Oxanium-Bold.ttf",
    math.max(9, math.floor(h * 0.7)))
  love.graphics.setFont(font)
  love.graphics.setColor(text)
  love.graphics.printf(letter, bx,
    by + math.floor((h - font:getHeight()) / 2) + 1, w, "center")
end

-- Final fallback. Guard against multi-byte UTF-8 keys: slicing
-- `:sub(1,2)` on a non-ASCII string would truncate a code point
-- and produce a decoding error in love.graphics.print.
local function draw_default(cx, cy, r, letter, is_wii)
  local fill   = is_wii and {1, 1, 1} or {0.30, 0.32, 0.40}
  local border = is_wii and {0.05, 0.55, 0.88} or {0.55, 0.58, 0.68}
  local text   = is_wii and {0.05, 0.42, 0.82} or {0.98, 0.99, 1.00}
  if type(letter) == "string" and #letter > 0
     and letter:byte(1) and letter:byte(1) >= 128 then
    letter = "?"
  end
  draw_circle_badge(cx, cy, r, fill, border, letter, text,
    is_wii and {1, 1, 1, 0.40} or nil)
end

-- ═════════════════════════════════════════════════════════════
-- PUBLIC: draw one badge
-- ═════════════════════════════════════════════════════════════
function B.draw(th, key, x, y, size)
  size = size or 22
  key  = tostring(key or ""):lower()
  local tid    = theme_id_from(th)
  local is_wii = (tid == "wii")

  local cx = x + size / 2
  local cy = y + size / 2
  local r  = size / 2 - 1

  if key == "dpad" then
    draw_dpad(cx, cy, r, is_wii)
    return x + size
  end

  if key == "start" or key == "select" or key == "menu" or key == "home" then
    draw_system(cx, cy, r, key:upper(), is_wii)
    return x + size
  end

  if key == "l1" or key == "r1" then
    draw_shoulder(cx, cy, r, key:upper(), is_wii)
    return x + size
  end

  if key == "l2" or key == "r2" then
    draw_trigger(cx, cy, r, key:upper(), is_wii)
    return x + size
  end

  if key == "one" or key == "two" or key == "plus" or key == "minus" then
    draw_pill(cx, cy, r, GLYPH[key] or key, is_wii)
    return x + size
  end

  if GC_FACE[key] and not is_wii then
    local face = GC_FACE[key]
    local border = { face.color[1]*0.6, face.color[2]*0.6, face.color[3]*0.6 }
    draw_circle_badge(cx, cy, r, face.color, border,
      GLYPH[key] or key:upper(), face.letter,
      {1, 1, 1, 0.30})
    return x + size
  end

  local letter
  if type(key) == "string" and #key > 0
     and key:byte(1) and key:byte(1) >= 128 then
    letter = "?"
  else
    letter = GLYPH[key] or key:upper():sub(1, 2)
  end
  draw_default(cx, cy, r, letter, is_wii)
  return x + size
end

-- ═════════════════════════════════════════════════════════════
-- FOOTER (metal bar on GC, azure chrome on Wii)
-- ═════════════════════════════════════════════════════════════
function B.draw_metal_footer(th, items, screen_w, y_top, height, font)
  if not items or #items == 0 then return end
  height = height or 28
  font   = font   or A.font("assets/fonts/Oxanium-Regular.ttf", 11)

  local tid    = theme_id_from(th)
  local is_wii = (tid == "wii")
  local th_tbl = theme_table_from(th)
  local acc    = (th_tbl and th_tbl.accent) or {0.55, 0.35, 0.95}

  local bar_top, bar_bot, bar_hi, bar_sh
  local chip_bg, chip_hi, chip_lo, label_col, brush_col

  if is_wii then
    bar_top = (th_tbl and th_tbl.footer_bg)     or {0.00, 0.62, 0.90}
    bar_bot = (th_tbl and th_tbl.footer_bg_alt) or {0.00, 0.50, 0.78}
    bar_hi  = {0.55, 0.88, 1.00}
    bar_sh  = {0.00, 0.30, 0.52}
    chip_bg = (th_tbl and th_tbl.footer_chip)    or {0.00, 0.42, 0.68}
    chip_hi = (th_tbl and th_tbl.footer_chip_hi) or {0.30, 0.70, 0.92}
    chip_lo = (th_tbl and th_tbl.footer_chip_lo) or {0.00, 0.28, 0.50}
    label_col = (th_tbl and th_tbl.footer_text) or {1.00, 1.00, 1.00}
    brush_col = {1.00, 1.00, 1.00, 0.06}
  else
    bar_top, bar_bot   = {0.17, 0.17, 0.21}, {0.08, 0.08, 0.10}
    bar_hi,  bar_sh    = {0.42, 0.42, 0.48}, {0.00, 0.00, 0.00}
    chip_bg, chip_hi   = {0.20, 0.20, 0.25}, {0.34, 0.34, 0.40}
    chip_lo            = {0.04, 0.04, 0.06}
    label_col          = {0.86, 0.89, 0.95}
    brush_col          = {1.00, 1.00, 1.00, 0.05}
  end

  local bands  = 6
  local band_h = height / bands
  for i = 0, bands - 1 do
    local p = i / (bands - 1)
    love.graphics.setColor(
      bar_top[1] + (bar_bot[1] - bar_top[1]) * p,
      bar_top[2] + (bar_bot[2] - bar_top[2]) * p,
      bar_top[3] + (bar_bot[3] - bar_top[3]) * p, 1)
    love.graphics.rectangle("fill",
      0, y_top + i * band_h, screen_w, math.ceil(band_h) + 1)
  end

  love.graphics.setColor(bar_hi[1], bar_hi[2], bar_hi[3], 0.9)
  love.graphics.rectangle("fill", 0, y_top, screen_w, 1)
  love.graphics.setColor(acc[1], acc[2], acc[3], is_wii and 0.0 or 0.55)
  love.graphics.rectangle("fill", 0, y_top - 1, screen_w, 1)
  love.graphics.setColor(bar_sh[1], bar_sh[2], bar_sh[3], 0.9)
  love.graphics.rectangle("fill", 0, y_top + height - 1, screen_w, 1)

  love.graphics.setColor(brush_col[1], brush_col[2], brush_col[3], brush_col[4])
  for dy = 3, height - 4, 3 do
    love.graphics.rectangle("fill", 0, y_top + dy, screen_w, 1)
  end

  local badge_size = 22
  local inner_pad  = 6
  local chip_pad_x = 10
  local chip_gap   = 6
  local chip_h     = height - 8
  local chip_y     = y_top + 4

  local widths, total = {}, 0
  for i, it in ipairs(items) do
    local label_w = (it.label and it.label ~= "" and
                     font:getWidth(it.label)) or 0
    local has_badge = (it.key ~= nil) and 1 or 0
    local w = chip_pad_x * 2
      + (has_badge * badge_size)
      + (label_w > 0 and
        ((has_badge == 1 and inner_pad or 0) + label_w) or 0)
    widths[i] = w
    total = total + w + (i < #items and chip_gap or 0)
  end

  local x = math.floor((screen_w - total) / 2)
  for i, it in ipairs(items) do
    local w = widths[i]

    love.graphics.setColor(chip_bg[1], chip_bg[2], chip_bg[3],
      is_wii and 0.98 or 0.95)
    love.graphics.rectangle("fill", x, chip_y, w, chip_h, 4, 4)

    love.graphics.setColor(chip_hi[1], chip_hi[2], chip_hi[3],
      is_wii and 0.65 or 0.75)
    love.graphics.rectangle("line", x + 0.5, chip_y + 0.5,
      w - 1, chip_h - 1, 4, 4)

    love.graphics.setColor(chip_lo[1], chip_lo[2], chip_lo[3], 0.65)
    love.graphics.rectangle("fill", x + 2, chip_y + chip_h - 2, w - 4, 1)

    if is_wii then
      love.graphics.setColor(1, 1, 1, 0.10)
      love.graphics.rectangle("fill",
        x + 2, chip_y + 2, w - 4, math.floor(chip_h * 0.35), 3, 3)
    end

    local cx = x + chip_pad_x
    if it.key then
      B.draw(th, it.key, cx, chip_y + (chip_h - badge_size) / 2, badge_size)
      cx = cx + badge_size
      if it.label and it.label ~= "" then cx = cx + inner_pad end
    end
    if it.label and it.label ~= "" then
      love.graphics.setFont(font)
      love.graphics.setColor(label_col[1], label_col[2], label_col[3], 1)
      love.graphics.print(it.label, cx,
        chip_y + math.floor((chip_h - font:getHeight()) / 2))
    end
    x = x + w + chip_gap
  end
end

-- ═════════════════════════════════════════════════════════════
-- HINT-STRING PARSING + WRAPPERS
-- ═════════════════════════════════════════════════════════════
function B.parse_hint(str)
  local tokens = {}
  if not str or str == "" then return tokens end
  local i, n = 1, #str
  while i <= n do
    while i <= n and str:sub(i, i):match("%s") do i = i + 1 end
    if i > n then break end
    if str:sub(i, i) == "[" then
      local close = str:find("]", i, true)
      if close then
        local key = str:sub(i + 1, close - 1)
        i = close + 1
        while i <= n and str:sub(i, i) == " " do i = i + 1 end
        local label_start = i
        local gap = 0
        while i <= n do
          local c = str:sub(i, i)
          if c == "[" then break end
          if c == " " then gap = gap + 1; if gap >= 3 then break end
          else gap = 0 end
          i = i + 1
        end
        local label = str:sub(label_start, i - 1):match("^%s*(.-)%s*$") or ""
        tokens[#tokens + 1] = { key = key, label = label }
      else
        i = i + 1
      end
    else
      local start = i
      while i <= n and str:sub(i, i) ~= "[" do i = i + 1 end
      local t = str:sub(start, i - 1):match("^%s*(.-)%s*$")
      if t ~= "" then tokens[#tokens + 1] = { label = t } end
    end
  end
  return tokens
end

local function hint_str_to_items(str)
  local items = {}
  for _, tk in ipairs(B.parse_hint(str)) do
    if tk.key then
      local mapped = KEY_ALIAS[tk.key] or tk.key:lower()
      items[#items + 1] = { key = mapped, label = tk.label }
    elseif tk.label and tk.label ~= "" then
      items[#items + 1] = { label = tk.label }
    end
  end
  return items
end

function B.draw_hint_metal(str, screen_w, y_top, th, font)
  font = font or A.font("assets/fonts/Oxanium-Regular.ttf", 11)
  local items = hint_str_to_items(str)
  B.draw_metal_footer(th, items, screen_w, y_top, 28, font)
end

-- Footer/hint anchoring.
-- The bar is always 28 px tall and sits flush with the bottom edge of
-- the screen. We ignore the caller's `y` entirely — screens used to
-- pass a variety of values (H-22, H-30, H-40, H), and the old
-- `min(y-6, gh-28)` logic sometimes left an 8 px gap when callers
-- passed a value greater than H-22.
local function flush_footer_top(_y)
  local _, gh = love.graphics.getDimensions()
  return gh - 28
end

function B.draw_hint_centered(str, screen_w, y, font, th)
  font = font or A.font("assets/fonts/Oxanium-Regular.ttf", 11)
  local _, gh = love.graphics.getDimensions()
  local top = gh - 28
  B.draw_metal_footer(th, hint_str_to_items(str), screen_w, top, 28, font)
end

function B.draw_footer(th, items, screen_w, y, font)
  if not items or #items == 0 then return end
  font = font or A.font("assets/fonts/Oxanium-Regular.ttf", 11)
  B.draw_metal_footer(th, items, screen_w, flush_footer_top(y), 28, font)
end

function B.hint_width(str, font)
  local tokens = B.parse_hint(str)
  local size, inner_pad, pad = 22, 7, 14
  local total = 0
  for i, tk in ipairs(tokens) do
    local w = 0
    if tk.key then
      w = size
      if tk.label and tk.label ~= "" then
        w = w + inner_pad + font:getWidth(tk.label)
      end
    else
      w = font:getWidth(tk.label or "")
    end
    total = total + w + (i < #tokens and pad or 0)
  end
  return total
end

function B.draw_hint(str, x, y, font, th)
  font = font or A.font("assets/fonts/Oxanium-Regular.ttf", 12)
  local tokens = B.parse_hint(str)
  local size, inner_pad, pad = 22, 7, 14
  local th_tbl = theme_table_from(th)
  local label_col = (th_tbl and th_tbl.text_dim) or {0.82, 0.82, 0.90}
  local cx = x
  for i, tk in ipairs(tokens) do
    if tk.key then
      local mapped = KEY_ALIAS[tk.key] or tk.key:lower()
      B.draw(th, mapped, cx, y, size)
      cx = cx + size
      if tk.label and tk.label ~= "" then
        love.graphics.setFont(font)
        love.graphics.setColor(label_col[1], label_col[2], label_col[3], 1)
        love.graphics.print(tk.label, cx + inner_pad,
          y + math.floor((size - font:getHeight()) / 2) + 1)
        cx = cx + inner_pad + font:getWidth(tk.label)
      end
    else
      love.graphics.setFont(font)
      love.graphics.setColor(label_col[1], label_col[2], label_col[3], 1)
      love.graphics.print(tk.label, cx,
        y + math.floor((size - font:getHeight()) / 2) + 1)
      cx = cx + font:getWidth(tk.label)
    end
    if i < #tokens then cx = cx + pad end
  end
  return cx
end

-- ═════════════════════════════════════════════════════════════
-- RICH TEXT — inline badges within prose
-- ═════════════════════════════════════════════════════════════
local RICH_WHITELIST = {
  a=true, b=true, x=true, y=true, z=true,
  l1=true, r1=true, l2=true, r2=true,
  start=true, select=true, menu=true, home=true,
  one=true, two=true, plus=true, minus=true,
  dpad=true,
  ["↑↓"]=true, ["←→"]=true, ["↑↓←→"]=true, ["←→↑↓"]=true,
  ["↑"]=true, ["↓"]=true, ["←"]=true, ["→"]=true,
}

local function parse_rich(str)
  local chunks = {}
  local i, n = 1, #str
  local buf_start = nil

  local function flush(end_pos)
    if buf_start and end_pos > buf_start then
      chunks[#chunks+1] = { kind = "text",
                            value = str:sub(buf_start, end_pos - 1) }
    end
    buf_start = nil
  end

  while i <= n do
    local ch = str:sub(i, i)
    if ch == "[" then
      local close = str:find("]", i, true)
      if close then
        local inner = str:sub(i + 1, close - 1)
        local mapped = KEY_ALIAS[inner] or inner:lower()
        if RICH_WHITELIST[mapped] then
          flush(i)
          chunks[#chunks+1] = { kind = "badge", key = mapped }
          i = close + 1
        else
          if not buf_start then buf_start = i end
          i = i + 1
        end
      else
        if not buf_start then buf_start = i end
        i = i + 1
      end
    else
      if not buf_start then buf_start = i end
      i = i + 1
    end
  end
  flush(n + 1)
  return chunks
end

function B.rich_text_height(str, x, y, max_w, font, th, badge_size)
  local chunks = parse_rich(str)
  badge_size = badge_size or 18
  local gap_x = 4
  local line_h = math.max(font:getHeight(), badge_size) + 2
  local cx, cy = x, y
  local lines = 1

  local function emit(w)
    if cx + w > x + max_w then
      cx = x
      cy = cy + line_h
      lines = lines + 1
    end
    cx = cx + w
  end

  for _, chunk in ipairs(chunks) do
    if chunk.kind == "badge" then
      emit(badge_size + gap_x)
    else
      local s = chunk.value
      local leading = s:match("^(%s+)")
      if leading then emit(font:getWidth(leading)) end
      for word in s:gmatch("[^%s]+") do
        emit(font:getWidth(word))
        local after = s:find("[^%s]", s:find(word, 1, true) + #word)
        if after then emit(font:getWidth(" ")) end
      end
    end
  end
  return cy + line_h - y
end

function B.draw_rich_text(str, x, y, max_w, font, th, badge_size)
  local chunks = parse_rich(str)
  badge_size = badge_size or 18
  local gap_x  = 4
  local line_h = math.max(font:getHeight(), badge_size) + 2

  local th_tbl = theme_table_from(th)
  local text_col = (th_tbl and th_tbl.text) or {1, 1, 1}

  local cx, cy = x, y

  local function place(w, draw_fn)
    if cx + w > x + max_w then
      cx = x
      cy = cy + line_h
    end
    draw_fn(cx, cy)
    cx = cx + w
  end

  for _, chunk in ipairs(chunks) do
    if chunk.kind == "badge" then
      place(badge_size + gap_x, function(px, py)
        B.draw(th, chunk.key, px,
          py + (line_h - badge_size) / 2 - 1, badge_size)
      end)
    else
      local s = chunk.value
      local leading = s:match("^(%s+)")
      if leading then
        local w = font:getWidth(leading)
        place(w, function(px, py)
          love.graphics.setFont(font)
          love.graphics.setColor(text_col[1], text_col[2], text_col[3], 1)
          love.graphics.print(leading, px,
            py + math.floor((line_h - font:getHeight()) / 2))
        end)
      end
      for word in s:gmatch("[^%s]+") do
        local w = font:getWidth(word)
        place(w, function(px, py)
          love.graphics.setFont(font)
          love.graphics.setColor(text_col[1], text_col[2], text_col[3], 1)
          love.graphics.print(word, px,
            py + math.floor((line_h - font:getHeight()) / 2))
        end)
        local after = s:find("[^%s]", s:find(word, 1, true) + #word)
        if after then
          local sp = font:getWidth(" ")
          place(sp, function(px, py)
            love.graphics.setFont(font)
            love.graphics.setColor(text_col[1], text_col[2], text_col[3], 1)
            love.graphics.print(" ", px,
              py + math.floor((line_h - font:getHeight()) / 2))
          end)
        end
      end
    end
  end

  return cy + line_h
end

if not B.draw_icon then
  B.draw_icon = function(key, x, y, size)
    local State = require("state")
    B.draw(State.theme or "gc", key, x, y, size or 22)
    return true
  end
end

return B