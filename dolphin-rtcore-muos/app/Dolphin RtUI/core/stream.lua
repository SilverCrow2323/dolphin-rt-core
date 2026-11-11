-- core/stream.lua — Rt:Stream state + IO (library from the PC, settings, stats,
-- server health, launch request). Pure parsing lives in core/stream_lib.lua.
-- Runtime data lives in data/stream/ (never shipped inside the package).
local L = require("core.stream_lib")
local M = {}

local DIR = "data/stream"
M.DIR = DIR
M.s, M.stats, M.games = {}, {}, {}
M.health = { library = "unknown", sunshine = "unknown", pending = false }

local function shq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function read(p) local f = io.open(p, "rb"); if not f then return nil end local d = f:read("*a"); f:close(); return d end
local function write(p, d)
  local tmp = p .. ".tmp"
  local f = io.open(tmp, "wb"); if not f then return false end
  f:write(d); f:close()
  return os.rename(tmp, p) and true or false
end
M.read, M.write = read, write

function M.init()
  os.execute("mkdir -p " .. shq(DIR .. "/covers") .. " " .. shq(DIR .. "/keys") .. " 2>/dev/null")
  if not read(DIR .. "/.migrated") then os.execute("sh tools/stream/migrate.sh >/dev/null 2>&1") end
  M.s = L.parse_conf(read(DIR .. "/stream.conf"))
  M.stats = L.parse_stats(read(DIR .. "/stats.tsv"))
  M.reload()
end

function M.reload() M.games = L.parse_library(read(DIR .. "/library.tsv")) end

function M.configured() return M.s.HOST ~= nil and M.s.HOST ~= "" end

function M.set_many(values)
  if type(values) ~= "table" then return false, "settings must be a table" end
  local previous, updates = {}, {}
  for key, value in pairs(values) do
    if type(key) ~= "string" or key == "" then return false, "invalid setting key" end
    value = tostring(value or "")
    if not value:match("^[%w%.:%-_ ]*$") then return false, "characters not allowed" end
    previous[key] = M.s[key]
    updates[key] = value
  end
  if next(updates) == nil then return true end
  for key, value in pairs(updates) do M.s[key] = value end
  if not write(DIR .. "/stream.conf", L.serialize_conf(M.s)) then
    for key, value in pairs(previous) do M.s[key] = value end
    return false, "could not persist stream.conf"
  end
  return true
end

function M.set(key, value)
  if type(key) ~= "string" or key == "" then return false, "invalid setting key" end
  return M.set_many({ [key] = value })
end

function M.stat(app)
  local t = M.stats[app]
  if not t then t = { plays = 0, last = 0, fav = false }; M.stats[app] = t end
  return t
end
local function save_stats() write(DIR .. "/stats.tsv", L.serialize_stats(M.stats)) end
function M.toggle_fav(app) local t = M.stat(app); t.fav = not t.fav; save_stats(); return t.fav end
function M.record_play(app) local t = M.stat(app); t.plays = t.plays + 1; t.last = os.time(); save_stats() end

-- ── background jobs (tools/stream/*.sh) ─────────────────────
-- Fire-and-forget: sh tools/stream/<script> <args...> &   (every argument quoted)
function M.spawn(script, ...)
  local parts = { "sh", shq("tools/stream/" .. script) }
  for _, a in ipairs({ ... }) do parts[#parts + 1] = shq(a) end
  os.execute(table.concat(parts, " ") .. " >/dev/null 2>&1 &")
end

-- job with a result file: removes it first, the tool writes it when done
function M.job(script, result, ...)
  os.remove(DIR .. "/" .. result)
  M.spawn(script, ...)
end

-- long-running job with a done marker: (sh tool args; touch job.done) &
function M.run_job(script, ...)
  os.remove(DIR .. "/job.done")
  local parts = { "sh", shq("tools/stream/" .. script) }
  for _, a in ipairs({ ... }) do parts[#parts + 1] = shq(a) end
  os.execute("(" .. table.concat(parts, " ") .. "; touch " .. shq(DIR .. "/job.done") .. ") >/dev/null 2>&1 &")
end
function M.job_done() local f = io.open(DIR .. "/job.done", "rb"); if f then f:close() end; return f ~= nil end
function M.kill_pair()
  os.execute("kill $(cat " .. shq(DIR .. "/pair.pid") .. ") >/dev/null 2>&1; rm -f " .. shq(DIR .. "/pair.pid"))
end

function M.check_health()
  if not M.configured() then M.health.library, M.health.sunshine = "unknown", "unknown"; return end
  os.remove(DIR .. "/h_lib.done"); os.remove(DIR .. "/h_sun.done")
  M.spawn("health.sh", "http://" .. M.s.HOST .. ":" .. M.s.SYNC_PORT .. "/library.tsv", DIR .. "/h_lib.done")
  M.spawn("health.sh", "http://" .. M.s.HOST .. ":47989/serverinfo", DIR .. "/h_sun.done")
  M.health.pending = true
end

function M.poll_health()
  if not M.health.pending then return end
  local a, b = read(DIR .. "/h_lib.done"), read(DIR .. "/h_sun.done")
  if a then M.health.library = a:match("^OK") and "ok" or "fail" end
  if b then M.health.sunshine = b:match("^OK") and "ok" or "fail" end
  if a and b then M.health.pending = false end
end

-- Writes data/launch_cmd.sh (+ .ret + .request) for mux_launch.sh's loop, which
-- runs tools/stream/stream_launch.sh synchronously and then restarts the UI.
function M.request_launch(game, return_to)
  if not L.valid_app(game.app) then return false, "invalid app name" end
  os.remove("data/launch_cmd.sh"); os.remove("data/launch.ret"); os.remove("data/launch.request")
  local ok = write("data/launch_cmd.sh",
    "#!/bin/bash\nexec bash tools/stream/stream_launch.sh " .. shq(game.app) .. "\n")
  if not ok then return false, "cannot write launch_cmd.sh" end
  os.execute("chmod +x data/launch_cmd.sh 2>/dev/null")
  if not write("data/launch.ret", return_to or "stream_library") then return false, "cannot write launch.ret" end
  if not write("data/launch.request", "1") then return false, "cannot write launch.request" end
  M.record_play(game.app)
  return true
end

-- Result of the last stream (written by stream_launch.sh when it failed or was very short)
function M.last_result()
  local r = read(DIR .. "/last_result.txt")
  if r then os.remove(DIR .. "/last_result.txt") end
  return r and r:gsub("%s+$", "") or nil
end

return M
