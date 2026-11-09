-- core/devshot.lua — headless screenshot helper (development only).
-- Usage:  DOLPHINUI_SHOT=/tmp/out.png[:seconds] love . --screen=triage
-- Captures the logical UI after <seconds> (default 1.2) and quits. Does nothing
-- unless DOLPHINUI_SHOT is set, so it costs nothing on the handheld.
local M = {}
local spec = os.getenv("DOLPHINUI_SHOT")
local path, delay, t, done = nil, 1.2, 0, false
if spec and spec ~= "" then
  path, delay = spec:match("^(.-):([%d%.]+)$")
  if not path then path, delay = spec, 1.2 end
  delay = tonumber(delay) or 1.2
end
function M.active() return path ~= nil end
-- DOLPHINUI_SHOT_PADS="A,DOWN,DOWN"  — logical buttons pressed 0.15 s apart,
-- starting at 1.0 s, before the capture (to photograph a non-default state).
local pads = {}
for tok in (os.getenv("DOLPHINUI_SHOT_PADS") or ""):gmatch("[^,%s]+") do pads[#pads + 1] = tok:upper() end
local GP = { A = "a", B = "b", X = "x", Y = "y", UP = "dpup", DOWN = "dpdown", LEFT = "dpleft",
             RIGHT = "dpright", MENU = "guide", L1 = "leftshoulder", R1 = "rightshoulder", START = "start" }
local fed = 0
function M.update(dt)
  if not path then return end
  t = t + dt
  while fed < #pads and t >= 1.0 + fed * 0.15 do
    fed = fed + 1
    local ok, UI = pcall(require, "ui")
    if ok and UI.gamepad and GP[pads[fed]] then
      pcall(UI.gamepad, GP[pads[fed]]); pcall(UI.gamepad_released, GP[pads[fed]])
    end
  end
end
function M.after_draw()
  if not path or done or t < delay then return end
  done = true
  love.graphics.captureScreenshot(function(img)
    local data = img:encode("png")
    local f = io.open(path, "wb")
    if f then f:write(data:getString()); f:close() end
    love.event.quit(0)
  end)
end
return M
