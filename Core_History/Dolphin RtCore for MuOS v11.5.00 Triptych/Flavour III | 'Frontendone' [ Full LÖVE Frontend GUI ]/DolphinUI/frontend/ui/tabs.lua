-- frontend/ui/tabs.lua
local A = require("assets")
local D = require("ui.draw")
local State = require("state")

local Tabs = {}

function Tabs.draw(tabs, index, x, y, width)
  if not tabs or #tabs == 0 then return end

  local th = State.theme
  x = x or 20
  y = y or 58
  width = width or (640 - 40)
  local n = #tabs
  local tw = math.floor(width / n)
  for i, t in ipairs(tabs) do
    local tx = x + (i - 1) * tw
    local active = (i == index)
    love.graphics.setColor(active and th.focus or {0.10, 0.11, 0.14, 0.9})
    love.graphics.rectangle("fill", tx + 1, y, tw - 2, 22, 3, 3)
    love.graphics.setColor(active and {1,1,1} or th.text_dim)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.printf(t.label, tx, y + 5, tw, "center")
    if active then
      love.graphics.setColor(th.focus)
      D.rough_rect(tx + 1, y, tw - 2, 22, { jitter = 0.6, thickness = 1.5, seed = i*7 })
    end
  end
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.6)
  love.graphics.line(x, y + 23, x + width, y + 23)
end

return Tabs