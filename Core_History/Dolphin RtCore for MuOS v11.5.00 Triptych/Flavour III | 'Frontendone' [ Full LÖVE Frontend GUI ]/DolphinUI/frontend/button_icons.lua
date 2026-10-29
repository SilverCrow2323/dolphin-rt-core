-- frontend/button_icons.lua — kept for backward compat.
-- Screens calling require("button_icons") get the procedural impl
-- living in ui/button_icons.lua. This avoids the two files diverging.
--
-- The old top-level exposed draw_icon(key, x, y, size) which nothing
-- in the current tree uses; we still provide a thin shim in case any
-- future screen calls it.

local B = require("ui.button_icons")

-- Legacy shim: old API returned true if drawn, false otherwise.
if not B.draw_icon then
  B.draw_icon = function(key, x, y, size)
    local State = require("state")
    local th = State.theme or "gc"
    B.draw(th, key, x, y, size or 18)
    return true
  end
end

return B