-- frontend/ui/proc_icons.lua
-- Icone vettoriali procedurali — usate come fallback quando
-- non esiste un PNG. Disegnate su griglia canonica 24x24,
-- scalate al size richiesto.
--
-- Tutte le icone accettano un colore {r,g,b[,a]} e usano
-- solo forme primitive: circle, rectangle, arc, line, polygon.

local M = {}
M.icons = {}

-- ── Helper ─────────────────────────────────────────────
local function frame(x, y, size, col, fn)
  local s = size / 24
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(s, s)
  local c = col or {1, 1, 1, 1}
  love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
  love.graphics.setLineWidth(2)
  fn()
  love.graphics.setLineWidth(1)
  love.graphics.pop()
end

-- ── Icone ──────────────────────────────────────────────

-- Profile: testa + spalle
M.icons.profile = function()
  love.graphics.circle("line", 12, 8, 4)
  love.graphics.arc("line", "open", 12, 21, 8, math.pi, 2 * math.pi)
end

-- Controller: gamepad con 2 stick + dpad
M.icons.controller = function()
  love.graphics.rectangle("line", 2, 8, 20, 10, 5, 5)
  love.graphics.circle("line", 7, 12.5, 2.2)
  love.graphics.circle("line", 17, 12.5, 2.2)
  love.graphics.line(11.5, 11.5, 12.5, 11.5)
  love.graphics.line(10, 15, 14, 15)
  love.graphics.line(12, 13, 12, 17)
end

-- Save: floppy disk
M.icons.save = function()
  love.graphics.rectangle("line", 4, 4, 16, 16, 1, 1)
  love.graphics.rectangle("line", 9, 4, 8, 6)
  love.graphics.rectangle("line", 7, 14, 10, 6)
end

-- Hotkeys: tasto keyboard con lettera K stilizzata
M.icons.hotkeys = function()
  love.graphics.rectangle("line", 3, 7, 18, 12, 2, 2)
  love.graphics.line(8, 10, 8, 16)
  love.graphics.line(8, 13, 13, 10)
  love.graphics.line(8, 13, 13, 16)
end

-- Enhancer: sparkle 4 punte
M.icons.enhancer = function()
  local pts = {}
  for i = 0, 7 do
    local a = -math.pi / 2 + i * math.pi / 4
    local r = (i % 2 == 0) and 10 or 3.5
    pts[#pts + 1] = 12 + math.cos(a) * r
    pts[#pts + 1] = 12 + math.sin(a) * r
  end
  love.graphics.polygon("line", pts)
end

-- Logging: documento con righe
M.icons.logging = function()
  love.graphics.rectangle("line", 5, 3, 14, 18, 1, 1)
  love.graphics.line(8, 8, 16, 8)
  love.graphics.line(8, 12, 16, 12)
  love.graphics.line(8, 16, 13, 16)
end

-- Library: 3 libri verticali
M.icons.library = function()
  love.graphics.rectangle("line", 3, 5, 4, 15)
  love.graphics.rectangle("line", 10, 4, 4, 16)
  love.graphics.rectangle("line", 17, 6, 4, 14)
  love.graphics.line(3, 20, 21, 20)
end

-- Advanced: 3 slider con knob a posizioni diverse
M.icons.advanced = function()
  love.graphics.line(3, 8, 21, 8)
  love.graphics.circle("fill", 9, 8, 2.5)
  love.graphics.line(3, 13, 21, 13)
  love.graphics.circle("fill", 16, 13, 2.5)
  love.graphics.line(3, 18, 21, 18)
  love.graphics.circle("fill", 7, 18, 2.5)
end

-- Info: cerchio con "i"
M.icons.info = function()
  love.graphics.circle("line", 12, 12, 9)
  love.graphics.circle("fill", 12, 7.5, 1.4)
  love.graphics.line(12, 11, 12, 17)
  love.graphics.line(9, 17, 15, 17)
end

-- Settings: gear con 8 denti
M.icons.settings = function()
  love.graphics.circle("line", 12, 12, 8)
  love.graphics.circle("line", 12, 12, 4)
  for i = 0, 7 do
    local a = i * math.pi / 4
    local x1 = 12 + math.cos(a) * 8
    local y1 = 12 + math.sin(a) * 8
    local x2 = 12 + math.cos(a) * 10.5
    local y2 = 12 + math.sin(a) * 10.5
    love.graphics.line(x1, y1, x2, y2)
  end
end

-- Homebrew: casa
M.icons.homebrew = function()
  love.graphics.polygon("line", 12, 4, 21, 11, 3, 11)
  love.graphics.rectangle("line", 5, 11, 14, 9)
  love.graphics.rectangle("line", 10, 15, 4, 5)
end

-- Star: stella 5 punte
M.icons.star = function()
  local pts = {}
  for i = 0, 9 do
    local a = -math.pi / 2 + i * math.pi / 5
    local r = (i % 2 == 0) and 10 or 4.2
    pts[#pts + 1] = 12 + math.cos(a) * r
    pts[#pts + 1] = 12 + math.sin(a) * r
  end
  love.graphics.polygon("line", pts)
end

-- About: cerchio con "?" stilizzato
M.icons.about = function()
  love.graphics.circle("line", 12, 12, 9)
  love.graphics.arc("line", "open", 12, 9.5, 3, math.pi * 1.1, math.pi * 2.6)
  love.graphics.line(12, 12.5, 12, 13.5)
  love.graphics.circle("fill", 12, 16.5, 1.4)
end

-- Manual: libro aperto
M.icons.manual = function()
  love.graphics.line(2, 6, 2, 19)
  love.graphics.line(22, 6, 22, 19)
  love.graphics.line(2, 6, 12, 8)
  love.graphics.line(22, 6, 12, 8)
  love.graphics.line(2, 19, 12, 20)
  love.graphics.line(22, 19, 12, 20)
  love.graphics.line(12, 8, 12, 20)
end

-- Update: freccia su in cerchio
M.icons.update = function()
  love.graphics.circle("line", 12, 12, 9)
  love.graphics.line(12, 7, 12, 17)
  love.graphics.line(12, 7, 8, 11)
  love.graphics.line(12, 7, 16, 11)
end

-- Theme: palette (cerchio + 3 dots)
M.icons.theme = function()
  love.graphics.circle("line", 12, 12, 9)
  love.graphics.circle("fill", 9, 9, 1.6)
  love.graphics.circle("fill", 15, 9, 1.6)
  love.graphics.circle("fill", 12, 15, 1.6)
end

-- Sfx: nota musicale
M.icons.sfx = function()
  love.graphics.circle("line", 9, 17, 3)
  love.graphics.circle("line", 17, 15, 3)
  love.graphics.line(12, 17, 12, 6)
  love.graphics.line(20, 15, 20, 4)
  love.graphics.line(12, 6, 20, 4)
end

-- UI: layout a pannelli
M.icons.ui = function()
  love.graphics.rectangle("line", 3, 4, 18, 16, 2, 2)
  love.graphics.line(3, 9, 21, 9)
  love.graphics.line(10, 9, 10, 20)
end

-- Library shortcut alias
M.icons.workshop = M.icons.advanced
M.icons.external = function()
  love.graphics.rectangle("line", 3, 5, 18, 14, 1, 1)
  love.graphics.line(3, 9, 21, 9)
  love.graphics.line(7, 5, 7, 9)
  love.graphics.line(17, 5, 17, 9)
end

M.icons.logout = function()
  love.graphics.rectangle("line", 3, 4, 12, 16, 1, 1)
  love.graphics.line(14, 12, 22, 12)
  love.graphics.line(18, 8, 22, 12)
  love.graphics.line(18, 16, 22, 12)
end

M.icons.play = function()
  love.graphics.polygon("line", 8, 5, 20, 12, 8, 19)
end

M.icons.restart = function()
  love.graphics.arc("line", "open", 12, 12, 7, -math.pi * 0.3, math.pi * 1.4)
  love.graphics.line(18, 5, 18, 9)
  love.graphics.line(14, 9, 18, 9)
end

M.icons.debugger = function()  -- non usato, ma utile
  love.graphics.rectangle("line", 3, 5, 18, 14, 2, 2)
  love.graphics.line(6, 9, 9, 12, 6, 15)
  love.graphics.line(12, 15, 17, 15)
end

-- Alias mappature
M.icons.wiimote = M.icons.controller
M.icons.saves   = M.icons.save
M.icons.app     = M.icons.settings
M.icons.general = M.icons.settings
M.icons.roms    = M.icons.library

-- ── Public API ─────────────────────────────────────────
-- Ritorna true se l'icona e' stata disegnata proceduralmente.
function M.draw(key, x, y, size, col)
  local fn = M.icons[key]
  if not fn then return false end
  frame(x, y, size, col, fn)
  return true
end

-- True se esiste un'icona procedurale per la key.
M.icons.cheats = function()
  -- stella con "!"
  local pts={}
  for i=0,9 do
    local a=-math.pi/2+i*math.pi/5
    local rr=(i%2==0) and 9 or 3.6
    pts[#pts+1]=12+math.cos(a)*rr
    pts[#pts+1]=12+math.sin(a)*rr
  end
  love.graphics.polygon("line",pts)
  love.graphics.circle("fill",12,12,1.6)
end
M.icons.rtprofile = function()
  love.graphics.circle("line",12,9,4)
  love.graphics.arc("line","open",12,21,8,math.pi,2*math.pi)
  love.graphics.circle("fill",17,7,2)
end
M.icons.graphicmods = function()
  love.graphics.rectangle("line",3,5,18,14,2,2)
  love.graphics.line(3,10,21,10)
  love.graphics.line(7,5,7,10)
  love.graphics.line(17,5,17,10)
  love.graphics.line(3,15,21,15)
end
M.icons.disc = function()
  love.graphics.circle("line",12,12,9)
  love.graphics.circle("line",12,12,3)
  love.graphics.arc("line","open",12,12,6,0,math.pi*0.6)
end


M.icons.identity = function()
    love.graphics.setLineWidth(1.4)
    for i = 0, 3 do
        local a = -math.pi/4 + i * 0.14
        love.graphics.line(
            9 + math.cos(a) * 6, 15 + math.sin(a) * 6,
            22 + math.cos(a) * 1, 3 + math.sin(a) * 1)
    end
    love.graphics.circle("line", 9, 15, 6)
    love.graphics.setColor(0.98, 0.78, 0.24, 1)
    love.graphics.ellipse("line", 9, 15, 4, 2.2)
    love.graphics.line(6, 15, 8, 12, 10, 16, 12, 13)
    love.graphics.circle("fill", 9, 15, 1)
end
function M.has(key)
  return M.icons[key] ~= nil
end


-- ── Filled-in icons (v2.0 aesthetic unification) ─────────────
-- These were previously falling back to ASCII glyphs via ui/icons.lua.
-- All drawn on the canonical 24×24 grid using only love.graphics primitives.

-- chart: three bars of increasing height
M.icons.chart = function()
  love.graphics.rectangle("fill", 4, 15, 4, 6)
  love.graphics.rectangle("fill", 10, 10, 4, 11)
  love.graphics.rectangle("fill", 16, 5, 4, 16)
end

-- close: X cross
M.icons.close = function()
  love.graphics.line(5, 5, 19, 19)
  love.graphics.line(19, 5, 5, 19)
end

-- gamesettings: a gear-like wheel with sliders (distinct from settings)
M.icons.gamesettings = function()
  love.graphics.circle("line", 12, 12, 7)
  love.graphics.line(5, 12, 8, 12)
  love.graphics.line(16, 12, 19, 12)
  love.graphics.line(12, 5, 12, 8)
  love.graphics.line(12, 16, 12, 19)
  love.graphics.circle("fill", 12, 12, 2)
end

-- gear: proper cog wheel (8 teeth)
M.icons.gear = function()
  love.graphics.circle("line", 12, 12, 6)
  love.graphics.circle("line", 12, 12, 2.5)
  for i = 0, 7 do
    local a = i * math.pi / 4
    love.graphics.line(
      12 + math.cos(a) * 6, 12 + math.sin(a) * 6,
      12 + math.cos(a) * 9, 12 + math.sin(a) * 9)
  end
end

-- link: two interlocking rings
M.icons.link = function()
  love.graphics.circle("line", 8, 12, 4)
  love.graphics.circle("line", 16, 12, 4)
end

-- off: power symbol (ring + vertical bar)
M.icons.off = function()
  love.graphics.circle("line", 12, 12, 8)
  love.graphics.line(12, 4, 12, 12)
end

-- rt: stylized "R" with core dot
M.icons.rt = function()
  love.graphics.line(7, 18, 7, 6, 14, 6, 14, 12, 7, 12)
  love.graphics.line(11, 12, 16, 18)
  love.graphics.circle("fill", 17, 6, 1.5)
end

-- screen: monitor frame with stand
M.icons.screen = function()
  love.graphics.rectangle("line", 3, 5, 18, 13, 2, 2)
  love.graphics.line(9, 21, 15, 21)
  love.graphics.line(12, 18, 12, 21)
end

-- sync: two curved arrows forming a circle
M.icons.sync = function()
  love.graphics.arc("line", "open", 12, 12, 6, -math.pi * 0.85, math.pi * 0.15, 14)
  love.graphics.arc("line", "open", 12, 12, 6,  math.pi * 0.15, math.pi * 1.15, 14)
  love.graphics.polygon("fill", 17, 8, 14, 5, 18, 4)
  love.graphics.polygon("fill", 7, 16, 10, 19, 6, 20)
end

-- text: "T" glyph
M.icons.text = function()
  love.graphics.line(6, 6, 18, 6)
  love.graphics.line(12, 6, 12, 18)
  love.graphics.line(9, 18, 15, 18)
end

-- warning: triangle with exclamation
M.icons.warning = function()
  love.graphics.polygon("line", 12, 4, 21, 20, 3, 20)
  love.graphics.rectangle("fill", 11, 9, 2, 6)
  love.graphics.rectangle("fill", 11, 17, 2, 2)
end

-- wrench: spanner with open-ended head
M.icons.wrench = function()
  love.graphics.line(6, 18, 14, 10)
  love.graphics.arc("line", "open", 16, 8, 3.2, math.pi * 0.25, math.pi * 1.75, 12)
  love.graphics.line(14, 10, 13, 11)
end


return M
