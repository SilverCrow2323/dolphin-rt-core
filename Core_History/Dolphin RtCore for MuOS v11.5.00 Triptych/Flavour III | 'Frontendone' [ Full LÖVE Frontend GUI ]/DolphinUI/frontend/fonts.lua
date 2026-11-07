-- frontend/fonts.lua
-- Semantic font resolver.
--
-- Usage:
--   local F = require("fonts")
--   love.graphics.setFont(F.get("title", 18))
--   love.graphics.setFont(F.get("voice", 22))
--   love.graphics.setFont(F.for_text("title", user_string, 18))
--
-- Never call A.font("assets/fonts/Whatever.ttf", size) directly in
-- a screen — go through F.get(role, size) instead. Re-theming the
-- whole app means editing this one file.
--
-- Roles:
--   brand      — the literal strings "GameCube", "GC", "Wii". Only.
--   title      — screen headers, page titles
--   voice      — main menu item labels
--   body       — descriptions, help text, list rows
--   body_bold  — emphasised body, list headers
--   mono       — paths, values, code, hex dumps
--   number     — big numbers (ratings, counts, timers)

local A     = require("assets")
local State = require("state")

local F = {}

-- Role → { gc = path, wii = path }
local ROLE_PATHS = {
  brand = {
    gc  = "assets/fonts/GameCube.ttf",
    wii = "assets/fonts/Wii.ttf",
  },
  title = {
    gc  = "assets/fonts/Orbitron-Bold.ttf",
    wii = "assets/fonts/Oxanium-Bold.ttf",
  },
  voice = {
    gc  = "assets/fonts/Audiowide-Regular.ttf",
    wii = "assets/fonts/ChakraPetch-Bold.ttf",
  },
  body = {
    gc  = "assets/fonts/Oxanium-Regular.ttf",
    wii = "assets/fonts/Oxanium-Regular.ttf",
  },
  body_bold = {
    gc  = "assets/fonts/Oxanium-Bold.ttf",
    wii = "assets/fonts/Oxanium-Bold.ttf",
  },
  mono = {
    gc  = "assets/fonts/JetBrainsMono-Regular.ttf",
    wii = "assets/fonts/JetBrainsMono-Regular.ttf",
  },
  number = {
    gc  = "assets/fonts/Orbitron-Black.ttf",
    wii = "assets/fonts/Oxanium-Bold.ttf",
  },
}

-- Last-resort fallback chain when a font file is missing.
local FALLBACK_CHAIN = {
  "assets/fonts/Oxanium-Bold.ttf",
  "assets/fonts/Oxanium-Regular.ttf",
}

local function current_theme_id()
  if not State or not State.theme_name then return "gc" end
  return State.theme_name
end

local function resolve_path(role, theme_id)
  local entry = ROLE_PATHS[role]
  if not entry then return FALLBACK_CHAIN[1] end
  return entry[theme_id] or entry.gc or FALLBACK_CHAIN[1]
end

function F.get(role, size)
  size = math.max(6, math.floor(size or 12))
  local path = resolve_path(role, current_theme_id())
  local f = A.font(path, size)
  if f then return f end
  for _, p in ipairs(FALLBACK_CHAIN) do
    local alt = A.font(p, size)
    if alt then return alt end
  end
  return love.graphics.getFont()
end

-- Same as F.get but escapes to a body font whenever the text has
-- any non-ASCII byte. Use for any dynamic user-facing string.
function F.for_text(role, text, size)
  if role == "brand" or role == "title" or role == "voice" then
    return A.title_font(text, size)
  end
  return F.get(role, size)
end

-- Exposed for debugging / tools screens.
function F.role_path(role)
  return resolve_path(role, current_theme_id())
end

return F