-- frontend/ui/keyboard_icons.lua — procedural keyboard key badges.
-- Consistent with ui/button_icons.lua: dark theme (GC/RtCore) or light
-- theme (Wii). Each key is drawn as a rounded rectangle with the label
-- centered. Wide keys (Space, Return, etc.) get proportional width.
local A = require("assets")
local K = {}

local PAD_X       = 4
local MIN_W       = 22
local H           = 22
local GAP_AFTER   = 8

-- Human-readable label per LÖVE key name
local LABELS = {
  ["return"]   = "Enter",
  ["escape"]   = "Esc",
  ["space"]    = "Space",
  ["tab"]      = "Tab",
  ["backspace"]= "Bksp",
  ["pageup"]   = "PgUp",
  ["pagedown"] = "PgDn",
  ["home"]     = "Home",
  ["end"]      = "End",
  ["insert"]   = "Ins",
  ["delete"]   = "Del",
  ["up"]       = "↑",
  ["down"]     = "↓",
  ["left"]     = "←",
  ["right"]    = "→",
  ["lshift"]   = "LShift",
  ["rshift"]   = "RShift",
  ["lctrl"]    = "Ctrl",
  ["rctrl"]    = "RCtrl",
  ["lalt"]     = "Alt",
  ["ralt"]     = "AltGr",
  ["kp0"]="Num0",["kp1"]="Num1",["kp2"]="Num2",["kp3"]="Num3",
  ["kp4"]="Num4",["kp5"]="Num5",["kp6"]="Num6",["kp7"]="Num7",
  ["kp8"]="Num8",["kp9"]="Num9",
}

-- Width modifiers (multiplied on base width)
local WIDE_KEYS = {
  ["space"]=3.0, ["return"]=1.8, ["backspace"]=1.8, ["tab"]=1.5,
  ["escape"]=1.4, ["pageup"]=1.4, ["pagedown"]=1.4,
  ["lshift"]=2.0, ["rshift"]=2.0, ["lctrl"]=1.6, ["rctrl"]=1.6,
}

local function label_for(key)
  if LABELS[key] then return LABELS[key] end
  if #key == 1 then return key:upper() end
  if key:match("^f%d+$") then return key:upper() end
  return key
end

local function width_for(key, font)
  local base = font:getWidth(label_for(key)) + PAD_X * 2
  local w = math.max(MIN_W, base)
  local mod = WIDE_KEYS[key]
  if mod then w = math.max(w, MIN_W * mod) end
  return w
end

-- Draw a single key at (x, y). Returns the right edge x.
function K.draw(th, key, x, y, size)
  size = size or H
  local tid = (type(th) == "string" and th)
           or (type(th) == "table" and th.id) or "gc"
  local is_wii = (tid == "wii")

  local font = A.font("assets/fonts/Oxanium-Bold.ttf", 11)
  local w = math.max(MIN_W, font:getWidth(label_for(key)) + PAD_X * 2)
  local mod = WIDE_KEYS[key]
  if mod then w = math.max(w, MIN_W * mod) end

  -- Palette
  local fill, border, text, hi
  if is_wii then
    fill   = {0.99, 1.00, 1.00}
    border = {0.55, 0.62, 0.72}
    text   = {0.10, 0.12, 0.18}
    hi     = {1.00, 1.00, 1.00}
  else
    fill   = {0.16, 0.17, 0.22}
    border = {0.42, 0.45, 0.55}
    text   = {0.90, 0.93, 0.98}
    hi     = {0.32, 0.35, 0.44}
  end

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", x + 1, y + 1.5, w, size, 4, 4)

  -- Body
  love.graphics.setColor(fill[1], fill[2], fill[3], 0.98)
  love.graphics.rectangle("fill", x, y, w, size, 4, 4)

  -- Top highlight
  love.graphics.setColor(hi[1], hi[2], hi[3], 0.55)
  love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, size - 1, 4, 4)

  -- Border
  love.graphics.setColor(border[1], border[2], border[3], 0.95)
  love.graphics.rectangle("line", x, y, w, size, 4, 4)

  -- Label
  love.graphics.setFont(font)
  love.graphics.setColor(text[1], text[2], text[3], 1)
  love.graphics.printf(label_for(key), x, y + math.floor((size - font:getHeight()) / 2) + 1,
    w, "center")

  return x + w
end

-- Width of a single key without drawing it
function K.width(th, key)
  local font = A.font("assets/fonts/Oxanium-Bold.ttf", 11)
  local w = math.max(MIN_W, font:getWidth(label_for(key)) + PAD_X * 2)
  local mod = WIDE_KEYS[key]
  if mod then w = math.max(w, MIN_W * mod) end
  return w
end

-- Draw a "+"-joined combo of keys, e.g. {"ctrl", "s"}
function K.draw_combo(th, keys, x, y, size)
  local cx = x
  for i, k in ipairs(keys) do
    if i > 1 then
      love.graphics.setColor(0.7, 0.7, 0.8)
      love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 11))
      love.graphics.print("+", cx + 2, y + 6)
      cx = cx + 12
    end
    cx = K.draw(th, k, cx, y, size)
  end
  return cx
end

function K.combo_width(th, keys)
  local total = 0
  for i, k in ipairs(keys) do
    if i > 1 then total = total + 12 end
    total = total + K.width(th, k)
  end
  return total
end

return K