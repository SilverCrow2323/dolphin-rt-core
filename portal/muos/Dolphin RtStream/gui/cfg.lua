-- cfg.lua - stream settings (conf/stream.conf), interface (conf/ui.cfg),
-- stats/favorites (conf/stats.tsv) and per-game overrides (conf/games.tsv)
local M = {}
local base = ""

M.defaults = {
  HOST = "", SYNC_PORT = "8765", WIDTH = "640", HEIGHT = "480", FPS = "60", BITRATE = "10000",
  CODEC = "auto", REMOTE = "auto", SOPS = "yes", PLATFORM = "", EXTRA_ARGS = "", TOKEN = "",
}
M.order = { "HOST", "SYNC_PORT", "WIDTH", "HEIGHT", "FPS", "BITRATE", "CODEC", "REMOTE", "SOPS", "PLATFORM", "EXTRA_ARGS", "TOKEN" }
M.s = {}

M.uidef = { theme = 1, view = 1, sort = 1, anim = true, scan = true, swap = false, confirm = true, eco = false, boot = true }
M.ui = {}

M.stats = {}
M.over = {}
local ZERO = { plays = 0, last = 0, fav = false }
local NOOVER = { res = "", bitrate = "", fps = "" }

local function readFile(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local s = f:read("*a"); f:close()
  return s
end
local function writeFile(p, s)
  local f = io.open(p, "wb")
  if not f then return false end
  f:write(s); f:close()
  return true
end
M.readFile, M.writeFile = readFile, writeFile

function M.split(line)
  local t = {}
  for f in (line .. "\t"):gmatch("([^\t]*)\t") do t[#t + 1] = f end
  return t
end

-- Keeps only safe characters: values end up in a file sourced by the shell.
-- Double and single quotes are NOT allowed in values: they are replaced with a space
-- and a warning is returned (false if something was lost).
local function safe(v)
  local s = tostring(v or "")
  local cleaned = s:gsub("[^%w%.%-_ :/=,@+%[%]]", " ")
  return cleaned, (cleaned ~= s)
end

-- ------------------------------------------------------------------ stream.conf
function M.loadStream()
  M.s = {}
  for k, v in pairs(M.defaults) do M.s[k] = v end
  local txt = readFile(base .. "/conf/stream.conf")
  if not txt then return end
  for line in txt:gmatch("[^\n]+") do
    line = (line:gsub("\r", ""))
    if not line:match("^%s*#") then
      local k, v = line:match('^%s*([A-Z_]+)%s*=%s*"([^"]*)"')
      if not k then k, v = line:match("^%s*([A-Z_]+)%s*=%s*([^%s#]*)") end
      if k and M.defaults[k] ~= nil then M.s[k] = v end
    end
  end
end

function M.saveStream()
  local out = {
    "# Dolphin Stream - streaming settings",
    "# Written by the GUI (START > Streaming). Read by mux_launch.sh and tools/*.sh",
    "",
  }
  local lost = {}
  for _, k in ipairs(M.order) do
    local v, changed = safe(M.s[k])
    out[#out + 1] = string.format('%s="%s"', k, v)
    if changed then lost[#lost + 1] = k end
  end
  local ok = writeFile(base .. "/conf/stream.conf", table.concat(out, "\n") .. "\n")
  return ok, (#lost > 0 and table.concat(lost, ", ") or nil)
end

function M.resetStream()
  local host = M.s.HOST
  for k, v in pairs(M.defaults) do M.s[k] = v end
  M.s.HOST = host                         -- the PC IP is not lost
  M.saveStream()
end

-- ------------------------------------------------------------------ ui.cfg
function M.loadUi()
  M.ui = {}
  for k, v in pairs(M.uidef) do M.ui[k] = v end
  local txt = readFile(base .. "/conf/ui.cfg")
  if not txt then return end
  for k, v in txt:gmatch("([%w_]+)=([^\n\r]*)") do
    local d = M.uidef[k]
    if type(d) == "boolean" then M.ui[k] = (v == "1")
    elseif type(d) == "number" then M.ui[k] = tonumber(v) or d end
  end
end

function M.saveUi()
  local out = {}
  for k, v in pairs(M.ui) do
    if type(v) == "boolean" then out[#out + 1] = k .. "=" .. (v and "1" or "0")
    else out[#out + 1] = k .. "=" .. tostring(v) end
  end
  table.sort(out)
  return writeFile(base .. "/conf/ui.cfg", table.concat(out, "\n") .. "\n")
end

-- ------------------------------------------------------------------ stats.tsv
function M.loadStats()
  M.stats = {}
  local txt = readFile(base .. "/conf/stats.tsv")
  if not txt then return end
  for line in txt:gmatch("[^\n]+") do
    local a, p, l, f = line:match("^([^\t]+)\t(%d+)\t(%d+)\t(%d)")
    if a then M.stats[a] = { plays = tonumber(p), last = tonumber(l), fav = (f == "1") } end
  end
end

function M.saveStats()
  local out = {}
  for a, s in pairs(M.stats) do
    if s.plays > 0 or s.fav then
      out[#out + 1] = string.format("%s\t%d\t%d\t%d", a, s.plays, s.last, s.fav and 1 or 0)
    end
  end
  table.sort(out)
  return writeFile(base .. "/conf/stats.tsv", table.concat(out, "\n") .. "\n")
end

function M.stat(app) return M.stats[app] or ZERO end
function M.mut(app)
  local s = M.stats[app]
  if not s then s = { plays = 0, last = 0, fav = false }; M.stats[app] = s end
  return s
end

-- ------------------------------------------------------------------ games.tsv
function M.loadOver()
  M.over = {}
  local txt = readFile(base .. "/conf/games.tsv")
  if not txt then return end
  for line in txt:gmatch("[^\n]+") do
    local f = M.split((line:gsub("\r", "")))
    if f[1] and f[1] ~= "" then
      M.over[f[1]] = { res = f[2] or "", bitrate = f[3] or "", fps = f[4] or "" }
    end
  end
end

function M.saveOver()
  local out = {}
  for a, o in pairs(M.over) do
    out[#out + 1] = a .. "\t" .. o.res .. "\t" .. o.bitrate .. "\t" .. o.fps
  end
  table.sort(out)
  return writeFile(base .. "/conf/games.tsv", table.concat(out, "\n") .. "\n")
end

function M.getOver(app) return M.over[app] or NOOVER end
function M.setOver(app, key, val)
  local o = M.over[app]
  if not o then o = { res = "", bitrate = "", fps = "" }; M.over[app] = o end
  o[key] = val
  if o.res == "" and o.bitrate == "" and o.fps == "" then M.over[app] = nil end
  M.saveOver()
end

function M.init(b)
  base = b
  M.loadStream(); M.loadUi(); M.loadStats(); M.loadOver()
end

return M
