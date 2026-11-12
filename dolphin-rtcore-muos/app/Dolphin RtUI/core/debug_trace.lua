-- Heavy diagnostic trace for muOS field builds.
-- Enabled by DOLPHINUI_HEAVY_DEBUG=1; never logs environment secrets.
local M = {}
local PATH = os.getenv("DOLPHINUI_DEBUG_LOG") or "data/logs/heavy_debug.log"
local MAX_BYTES = 2 * 1024 * 1024
local enabled = os.getenv("DOLPHINUI_HEAVY_DEBUG") == "1"

local function clean(v)
  local s = tostring(v)
  s = s:gsub("[\r\n\t]", " ")
  if #s > 700 then s = s:sub(1, 700) .. "…" end
  return s
end

local function rotate()
  local f = io.open(PATH, "r")
  if not f then return end
  local n = f:seek("end") or 0
  f:close()
  if n >= MAX_BYTES then
    os.remove(PATH .. ".1")
    os.rename(PATH, PATH .. ".1")
  end
end

function M.is_enabled() return enabled end
function M.set_enabled(v) enabled = v == true end

function M.write(tag, ...)
  if not enabled then return end
  pcall(function()
    os.execute("mkdir -p " .. string.format("%q", PATH:match("^(.*)/") or "data/logs") .. " 2>/dev/null")
    rotate()
    local f = io.open(PATH, "a")
    if not f then return end
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts+1] = clean(select(i, ...)) end
    local stamp = os.date("%Y-%m-%d %H:%M:%S")
    local clock = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
    f:write(stamp, string.format(" +%.3f", clock), " [", clean(tag), "] ",
      table.concat(parts, " | "), "\n")
    f:close()
  end)
end

function M.error(tag, err)
  local trace = ""
  if debug and debug.traceback then trace = debug.traceback("", 2) end
  M.write("ERROR:" .. tostring(tag), tostring(err), trace)
end

function M.start(version)
  if not enabled then return end
  M.write("SESSION", "START", "version=" .. tostring(version or "unknown"),
    "arch=" .. tostring(os.getenv("LD_LIBRARY_PATH") and "runtime-path-set" or "runtime-path-unset"),
    "cwd=" .. tostring(os.getenv("PWD") or "unknown"))
end

function M.finish()
  M.write("SESSION", "SHUTDOWN")
end

return M
