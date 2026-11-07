-- core/state.lua — global core state (no love.* dependencies).
local M = {}

M.t          = 0
M.screen     = nil
M.theme_name = "gc"
M.raw_input  = false

function M.init()
  M.t          = 0
  M.screen     = nil
  M.theme_name = "gc"
  M.raw_input  = false
end

function M.update(dt) M.t = M.t + dt end
function M.go(name)   M.screen = name   end

-- Bridge: moduli legacy leggono State.theme (theme table).
-- Restituisce il tema corrente da ui.theme se disponibile.
function M.__theme_getter()
  local ok, Theme = pcall(require, "ui.theme")
  if ok and Theme and Theme.current then return Theme.current() end
  return {
    name     = "gc",
    accent   = {0.55, 0.35, 0.95},
    text     = {1, 1, 1},
    text_dim = {0.65, 0.65, 0.75},
  }
end

setmetatable(M, {
  __index = function(t, k)
    if k == "theme" then return rawget(t, "__theme_getter")() end
    return rawget(t, k)
  end,
})


-- ── Extended helpers (added by 01_core.sh) ──────────────
function M.has_screen(name)
    local ok, UI = pcall(require, "ui")
    if not ok or type(UI) ~= "table" then return false end
    return UI.screens and UI.screens[name] ~= nil
end

function M.back()
    local ok, UI = pcall(require, "ui")
    if ok and UI and UI.back then
        return UI.back()
    end
    local ok2, UI2 = pcall(require, "ui")
    if ok2 and UI2 and UI2.go then
        UI2.go((M.opts and M.opts.return_to) or "menu")
    end
    M.opts = nil
end

function M.opts_set(t) M.opts = t or {} end
function M.opts_get() return M.opts end

return M
