-- rtid_builder.lua — bulk rebuild intentionally disabled.
-- Individual game-card metadata is generated on demand when a game is opened.
local M = { available = false, reason = "cards are generated on demand" }
function M.rebuild_all() return { built = 0, updated = 0, orphans = 0 } end
return M
