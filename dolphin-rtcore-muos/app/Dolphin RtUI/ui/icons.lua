-- frontend/ui/icons.lua
-- Theme-aware icon resolver.
--   1. theme.icon_<key>              (e.g. theme.icon_library)
--   2. assets/images/icons/<key>.png (generic fallback)
--   3. ASCII glyph (last resort)
-- Always drawn with "contain" (aspect-preserving, centered).

local A = require("ui.assets")
local ProcIcons = require("ui.proc_icons")
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
  -- extra fallbacks used by newer screens
  chart = "C", droplet = "D", wave = "~",
  flashback = "F", wizard = "W", import = "I",
  report = "R", dashboard = "D", warning = "!",
  check = "+", cross = "x", pencil = "/",
  arrow_r = ">", arrow_l = "<",
  rt = "R", prime = "P", boost = "B", pure = "U",
}

local function resolve(key)
  local ok, State = pcall(require, "core.state")
  if ok and State and State.theme then
    local themed = State.theme["icon_" .. key]
    if themed then
      local img = A.image(themed)
      if img then return img end
    end
  end
  local generic = A.image("assets/images/icons/" .. key .. ".png")
  if generic then return generic end
  -- Loose PNG at assets/images/<key>.png  (e.g. assets/images/workshop.png)
  local loose = A.image("assets/images/" .. key .. ".png")
  if loose then return loose end
  return nil
end

function Icons.draw(key, x, y, size, col)
  -- 1. PNG specifico del tema
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

  -- 2. Icona procedurale (vettoriale)
  if ProcIcons.has(key) then
    ProcIcons.draw(key, x, y, size, col)
    return
  end

  -- 3. Fallback: lettera
  local _icon_warned = rawget(_G, "_DOLPHIN_ICON_WARNED") or {}
  _G._DOLPHIN_ICON_WARNED = _icon_warned
  local glyph = GLYPHS[key]
  if not glyph then
    if os.getenv("DOLPHINUI_DEBUG_ICONS") == "1" and not _icon_warned[key] then
      _icon_warned[key] = true
      print("[icons] no vector for '" .. tostring(key) .. "' -- using '?'")
    end
    glyph = "?"
  end
  local px = math.max(8, math.floor(tonumber(size) or 12))
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", px))
  if type(col) == "table" then
    love.graphics.setColor(col[1] or 1, col[2] or 1, col[3] or 1,
                           col[4] or 1)
  else
    love.graphics.setColor(1, 1, 1, 1)
  end
  love.graphics.print(glyph, x, y)
end

function Icons.width(key, size) return size end

return Icons