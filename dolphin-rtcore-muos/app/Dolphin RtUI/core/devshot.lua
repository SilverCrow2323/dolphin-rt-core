-- core/devshot.lua — headless screenshot helper (development only).
-- Single: DOLPHINUI_SHOT=/tmp/out.png[:seconds] love . --screen=triage
-- Batch:  DOLPHINUI_SHOT_BATCH=boot,library DOLPHINUI_SHOT_DIR=/tmp/shots love .
-- Does nothing unless one of the opt-in environment variables is set.
local M = {}
local spec = os.getenv("DOLPHINUI_SHOT")
local path, delay, t, done = nil, 1.2, 0, false
if spec and spec ~= "" then
  path, delay = spec:match("^(.-):([%d%.]+)$")
  if not path then path, delay = spec, 1.2 end
  delay = tonumber(delay) or 1.2
end

local batch_spec = os.getenv("DOLPHINUI_SHOT_BATCH")
local batch_dir = os.getenv("DOLPHINUI_SHOT_DIR")
local batch_delay = tonumber(os.getenv("DOLPHINUI_SHOT_DELAY") or "") or 1.2
local batch, batch_index = {}, 1
local batch_started, batch_capturing, batch_failed = false, false, false
if batch_spec and batch_spec ~= "" and batch_dir and batch_dir ~= "" then
  for name in batch_spec:gmatch("[^,%s]+") do batch[#batch + 1] = name end
end

function M.active() return path ~= nil or #batch > 0 end

-- DOLPHINUI_SHOT_PADS="A,DOWN,DOWN" — logical buttons pressed 0.15 s apart,
-- starting at 1.0 s, before capture (to photograph a non-default state).
local pads = {}
for tok in (os.getenv("DOLPHINUI_SHOT_PADS") or ""):gmatch("[^,%s]+") do
  pads[#pads + 1] = tok:upper()
end
local GP = {
  A = "a", B = "b", X = "x", Y = "y", UP = "dpup", DOWN = "dpdown",
  LEFT = "dpleft", RIGHT = "dpright", MENU = "guide",
  L1 = "leftshoulder", R1 = "rightshoulder", START = "start",
}
local fed = 0
local batch_fed = 0

local function fail_batch(message)
  if batch_failed then return end
  batch_failed = true
  print("[devshot] batch capture failed: " .. tostring(message))
  love.event.quit(1)
end

local function safe_name(name)
  return tostring(name):gsub("[^%w_%-]", "_")
end

local function enter_batch_screen()
  local ok, UI = pcall(require, "ui")
  if not ok or type(UI) ~= "table" or type(UI.go_instant) ~= "function" then
    fail_batch("UI navigation API unavailable")
    return
  end
  local entered, result = pcall(UI.go_instant, batch[batch_index], {})
  if not entered or result == false then
    fail_batch(entered and ("cannot open screen " .. batch[batch_index]) or result)
    return
  end
  t, batch_fed, batch_capturing = 0, 0, false
  batch_started = true
end

function M.update(dt)
  if #batch > 0 then
    if batch_failed or batch_index > #batch then return end
    if not batch_started then enter_batch_screen() end
    if batch_failed then return end
    t = t + dt
    while batch_fed < #pads and t >= 1.0 + batch_fed * 0.15 do
      batch_fed = batch_fed + 1
      local ok, UI = pcall(require, "ui")
      if ok and UI.gamepad and GP[pads[batch_fed]] then
        pcall(UI.gamepad, GP[pads[batch_fed]])
        pcall(UI.gamepad_released, GP[pads[batch_fed]])
      end
    end
    return
  end

  if not path then return end
  t = t + dt
  while fed < #pads and t >= 1.0 + fed * 0.15 do
    fed = fed + 1
    local ok, UI = pcall(require, "ui")
    if ok and UI.gamepad and GP[pads[fed]] then
      pcall(UI.gamepad, GP[pads[fed]])
      pcall(UI.gamepad_released, GP[pads[fed]])
    end
  end
end

local function capture_batch_frame()
  batch_capturing = true
  local ok, err = pcall(love.graphics.captureScreenshot, function(img)
    local callback_ok, callback_err = pcall(function()
      local data = img:encode("png")
      local filename = batch_dir .. "/" .. safe_name(batch[batch_index]) .. ".png"
      local file, open_err = io.open(filename, "wb")
      if not file then error(open_err or ("cannot open " .. filename)) end
      local write_ok, write_err = file:write(data:getString())
      local close_ok, close_err = file:close()
      if not write_ok then error(write_err or ("cannot write " .. filename)) end
      if not close_ok then error(close_err or ("cannot close " .. filename)) end
      print(string.format("[devshot] captured %s", filename))
    end)
    if not callback_ok then fail_batch(callback_err); return end

    batch_index = batch_index + 1
    if batch_index > #batch then
      love.event.quit(0)
      return
    end
    enter_batch_screen()
  end)
  if not ok then fail_batch(err) end
end

function M.after_draw()
  if #batch > 0 then
    if not batch_failed and batch_started and not batch_capturing and t >= batch_delay then
      capture_batch_frame()
    end
    return
  end

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
