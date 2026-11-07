local State = require("core.state")
local M = {}
local themes = {}

function M.register(name, t) themes[name] = t end

function M.init()
  M.register("gc",  require("ui.theme.gc"))
  M.register("wii", require("ui.theme.wii"))
end

function M.current()
  return themes[State.theme_name] or themes.gc
end

function M.flip()
  State.theme_name = (State.theme_name == "gc") and "wii" or "gc"
end

return M
