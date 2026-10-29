-- frontend/task_runner.lua
-- Launch a muOS task script from the frontend, hand the framebuffer
-- over, and let the shell return to the launcher.
--
-- Flow:
--   1. Quit LÖVE (which releases ALSA + the framebuffer).
--   2. A detached shell waits briefly for LÖVE to actually exit, then
--      execs the target.
--   3. muOS's task runner returns to the launcher when the script
--      finishes; the launcher restarts DolphinUI.
--
-- v0.5.1 — extension detection
--   * The old version always ran "sh <path>". That broke on .py files
--     (the Bash Arsenal ships rt_joywatch.py / rt_keyinject.py and
--     Overlay Menu.py). run() now picks the interpreter from the file
--     extension: sh, python3, or falls back to treating the file as
--     directly executable.
--   * Path sanitization unchanged (no newline, no NUL, no "..").

local sh = require("sh")

local M = {}

local function looks_safe_path(p)
  if type(p) ~= "string" or p == "" then return false end
  if p:find("\0", 1, true) then return false end
  if p:find("\n", 1, true) then return false end
  if p:find("\r", 1, true) then return false end
  if p:find("%.%.")        then return false end
  return true
end

local function interpreter_for(path)
  local lower = path:lower()
  if lower:match("%.py$")  then return "python3" end
  if lower:match("%.sh$")  then return "sh"      end
  if lower:match("%.lua$") then return "lua"     end
  return "sh"   -- safest default for script files
end

-- Run a script and quit the frontend.
--   path  = absolute path to the script
--   opts  = { interp = "sh"|"python3"|..., confirm = bool }
function M.run(path, opts)
  opts = opts or {}

  if not looks_safe_path(path) then
    require("modal").show("Invalid script path",
      "Path:\n" .. tostring(path) .. "\n\nThe path is invalid.")
    return
  end

  local f = io.open(path, "r")
  if not f then
    require("modal").show("Script not found",
      "Path:\n" .. path .. "\n\nThe file does not exist.")
    return
  end
  f:close()

  local interp = opts.interp or interpreter_for(path)

  -- Inner command: brief sleep so LÖVE can release ALSA and the
  -- framebuffer, then exec the interpreter against the script.
  local inner = "sleep 0.5; exec " .. interp .. " " .. sh.shq(path)
  local cmd = "setsid sh -c " .. sh.shq(inner) ..
              " </dev/null >/dev/null 2>&1 &"
  os.execute(cmd)

  if love and love.timer then love.timer.sleep(0.2) end
  love.event.quit()
end

return M