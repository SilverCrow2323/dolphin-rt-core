-- core/stream_lib.lua — Rt:Stream, pure logic (no LOVE, no io).
-- library.tsv (written by the PC portal):  kind <TAB> title <TAB> app <TAB> cover <TAB> id <TAB> rom
--   kind  = gc | wii        cover = "covers/<file>" or "<file>" or "-"
-- stream.conf: KEY="value" lines, values restricted to harmless characters.
local M = {}

local function split_tab(line)
  local out = {}
  for f in (line .. "\t"):gmatch("(.-)\t") do out[#out + 1] = f end
  return out
end

function M.valid_app(app)
  -- Real titles contain ':' '&' "'" accents and "(2)" suffixes. Every use is quoted (shq / "$APP"),
  -- so only control characters and double quotes (which the portal strips anyway) are refused.
  return type(app) == "string" and #app > 0 and #app < 160 and not app:find("[\"%c]")
end

-- cover names: a bare file name, optionally under "covers/"; never a path escape
local function clean_cover(c)
  if not c or c == "" or c == "-" then return nil end
  c = c:gsub("^covers/", "")
  if c:find("/") or c:find("%.%.") or c:find("[%c\\]") then return nil end
  return c
end

function M.parse_library(text)
  local games = {}
  for line in (text or ""):gmatch("[^\r\n]+") do
    if line:sub(1, 1) ~= "#" then
      local f = split_tab(line)
      local kind = f[1] and f[1]:lower()
      if (kind == "gc" or kind == "wii") and f[2] and f[2] ~= "" and M.valid_app(f[3]) then
        games[#games + 1] = {
          kind = kind, title = f[2], app = f[3], cover = clean_cover(f[4]),
          id = (f[5] and f[5] ~= "-" and f[5] ~= "") and f[5] or nil,
        }
      end
    end
  end
  return games
end

-- stream.conf helpers
local VALUE_OK = "^[%w%.:%-_ ]*$"
M.defaults = { HOST = "", SYNC_PORT = "8765", WIDTH = "640", HEIGHT = "480", FPS = "60",
               BITRATE = "10000", CODEC = "auto", REMOTE = "auto", SOPS = "yes",
               PLATFORM = "", MAC = "", TOKEN = "" }
M.ORDER = { "HOST", "SYNC_PORT", "WIDTH", "HEIGHT", "FPS", "BITRATE", "CODEC", "REMOTE", "SOPS", "PLATFORM", "MAC", "TOKEN" }

function M.conf_get(text, key)
  return (text or ""):match("\n?" .. key .. '="([^"\n]*)"')
end

function M.parse_conf(text)
  local s = {}
  for k, v in pairs(M.defaults) do s[k] = v end
  for _, k in ipairs(M.ORDER) do
    local v = M.conf_get("\n" .. (text or ""), k)
    if v and v:match(VALUE_OK) then s[k] = v end
  end
  return s
end

function M.serialize_conf(s)
  local out = { "# Dolphin Rt:Stream - streaming settings (written by the UI)" }
  for _, k in ipairs(M.ORDER) do
    local v = tostring(s[k] or M.defaults[k] or "")
    if not v:match(VALUE_OK) then v = M.defaults[k] or "" end
    out[#out + 1] = k .. '="' .. v .. '"'
  end
  return table.concat(out, "\n") .. "\n"
end

-- per-game stats / favourites:  app <TAB> plays <TAB> last <TAB> fav
function M.parse_stats(text)
  local t = {}
  for line in (text or ""):gmatch("[^\r\n]+") do
    if line:sub(1, 1) ~= "#" then
      local f = split_tab(line)
      if f[1] and f[1] ~= "" then
        t[f[1]] = { plays = tonumber(f[2]) or 0, last = tonumber(f[3]) or 0, fav = f[4] == "1" }
      end
    end
  end
  return t
end

function M.serialize_stats(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  local out = { "# app\tplays\tlast\tfav" }
  for _, k in ipairs(keys) do
    local s = t[k]
    out[#out + 1] = ("%s\t%d\t%d\t%d"):format(k, s.plays or 0, s.last or 0, s.fav and 1 or 0)
  end
  return table.concat(out, "\n") .. "\n"
end

-- Moonlight argv builder (pure, so it is testable). Returns list of args.
local function num(v, lo, hi, d)
  v = tonumber(v); if not v then return d end
  return math.max(lo, math.min(hi, math.floor(v)))
end
function M.moonlight_args(s, app, keydir)
  local a = { "stream", "-app", app, "-keydir", keydir,
    "-bitrate", tostring(num(s.BITRATE, 500, 150000, 10000)),
    "-width", tostring(num(s.WIDTH, 160, 3840, 640)),
    "-height", tostring(num(s.HEIGHT, 120, 2160, 480)),
    "-fps", tostring(num(s.FPS, 15, 120, 60)),
    "-codec", (s.CODEC == "h264" or s.CODEC == "h265") and s.CODEC or "auto",
    "-remote", (s.REMOTE == "yes" or s.REMOTE == "no") and s.REMOTE or "auto" }
  if s.SOPS == "no" then a[#a + 1] = "-nosops" end
  return a
end

function M.ago(ts, now)
  if not ts or ts == 0 then return "never played" end
  if now < 1735689600 or ts < 1735689600 then return "unknown (clock)" end
  local d = math.max(0, now - ts)
  if d < 120 then return "just now" end
  if d < 3600 then return math.floor(d / 60) .. " min ago" end
  if d < 86400 then return math.floor(d / 3600) .. " h ago" end
  if d < 172800 then return "yesterday" end
  return math.floor(d / 86400) .. " d ago"
end

return M
