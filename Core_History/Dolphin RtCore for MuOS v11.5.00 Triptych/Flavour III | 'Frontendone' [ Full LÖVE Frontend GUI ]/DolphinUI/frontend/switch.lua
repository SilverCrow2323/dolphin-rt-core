local State = require("state")
local M = {}
function M.draw(x, y, w, h, font)
  local th = State.theme
  local is_gc = (State.theme_name == "gc")
  local seg_w = w / 2
  font = font or love.graphics.getFont()
  love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
  love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", x, y, w, h, h/2, h/2)
  local sx = is_gc and x or (x + seg_w)
  love.graphics.setColor(th.focus)
  love.graphics.rectangle("fill", sx + 2, y + 2, seg_w - 4, h - 4, (h-4)/2, (h-4)/2)
  love.graphics.setColor(th.text); love.graphics.setFont(font)
  love.graphics.printf("GC",  x, y + (h-14)/2, seg_w, "center")
  love.graphics.printf("WII", x + seg_w, y + (h-14)/2, seg_w, "center")
  love.graphics.setLineWidth(1)
  return w
end
function M.toggle()
  if State.flip_trigger then State.flip_trigger() end
end
return M