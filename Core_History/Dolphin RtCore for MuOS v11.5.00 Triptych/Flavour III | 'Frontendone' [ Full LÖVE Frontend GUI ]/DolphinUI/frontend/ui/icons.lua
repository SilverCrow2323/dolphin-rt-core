-- frontend/ui/icons.lua
-- Theme-aware icon resolver.
--   1. theme.icon_<key>              (e.g. theme.icon_library)
--   2. assets/images/icons/<key>.png (generic fallback)
--   3. ASCII glyph (last resort)
-- Always drawn with "contain" (aspect-preserving, centered).

local A = require("assets")
local Icons = {}

local GLYPHS = {
  general = "o", roms = "#", theme = "*",
  ui = "[", sfx = "~", advanced = "+",
  library = "=", homebrew = "H", enhancer = "@",
  workshop = "W", settings = "S", logout = "X",
  saves = "v", cheats = "*", play = ">",
  profile = "P", controller = "C", logging = "L",
  info = "i", about = "?", manual = "M",
  external = "E", app = "A",
  battery_full = "#", battery_low = "_",
  wifi = "|", update = "^",
  balanced = "=", speed = ">>", target = "O",
  zap = "/", star = "*", fire = "^",
  skull = "X", wrench = "+",
  hotkeys = "K", debugger = "G", wiimote = "O",
  save = "S", off = "o",
}

local function resolve(key)
  local ok, State = pcall(require, "state")
  if ok and State and State.theme then
    local themed = State.theme["icon_" .. key]
    if themed then
      local img = A.image(themed)
      if img then return img end
    end
  end
  local generic = A.image("assets/images/icons/" .. key .. ".png")
  if generic then return generic end
  return nil
end

function Icons.draw(key, x, y, size, col)
  local img = resolve(key)
  if img then
    local iw, ih = img:getWidth(), img:getHeight()
    local scale = size / math.max(iw, ih)
    local w, h  = iw * scale, ih * scale
    local ox = x + (size - w) / 2
    local oy = y + (size - h) / 2
    love.graphics.setColor(col)
    love.graphics.draw(img, ox, oy, 0, scale, scale)
    return
  end
  local glyph = GLYPHS[key] or "."
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", math.floor(size)))
  love.graphics.setColor(col)
  love.graphics.print(glyph, x, y)
end

function Icons.width(key, size) return size end

return Icons