-- frontend/minoru/history.lua
-- Persistent, session-scoped event log for Minoru⁶.
--
-- Storage: frontend/minoru/data/history.json
--   {
--     "sessions": 7,
--     "last_seen": 1789657200,
--     "current_session": 1789657200,
--     "events": [
--       { "t": 1789657212, "session": 1789657200,
--         "type": "greeting", "screen": "external_input_station",
--         "text": "Oh. It's you again.", "emotion": "sarcastic" },
--       ...
--     ]
--   }
--
-- One session id per app boot. Newest-first. Bounded to MAX_EVENTS.

local json = require("json")

local M = {}

local DIR        = "minoru/data"
local PATH       = DIR .. "/history.json"
local MAX_EVENTS = 250
local FLUSH_SECS = 5.0

local _state = {
  sessions        = 0,
  last_seen       = 0,
  current_session = 0,
  events          = {},
  _dirty          = false,
  _last_flush     = 0,
}

-- ── Load / save ──────────────────────────────────────────────
local function load()
  local f = io.open(PATH, "r")
  if not f then return end
  local c = f:read("*a"); f:close()
  local ok, data = pcall(json.decode, c)
  if not ok or type(data) ~= "table" then return end

  _state.sessions  = tonumber(data.sessions)  or 0
  _state.last_seen = tonumber(data.last_seen) or 0
  if type(data.events) == "table" then
    local clean = {}
    for _, ev in ipairs(data.events) do
      if type(ev) == "table" and ev.t and ev.type then
        clean[#clean + 1] = ev
      end
    end
    _state.events = clean
  end
end

local function save_now()
  os.execute("mkdir -p " .. DIR)
  local payload = json.encode({
    sessions        = _state.sessions,
    last_seen       = _state.last_seen,
    current_session = _state.current_session,
    events          = _state.events,
  })
  local tmp = PATH .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return end
  f:write(payload)
  f:close()
  if not os.rename(tmp, PATH) then
    os.execute("cp " .. "'" .. tmp .. "' '" .. PATH .. "'")
    os.remove(tmp)
  end
  _state._dirty = false
  _state._last_flush = os.time()
end

-- ── Public API ───────────────────────────────────────────────
function M.init()
  load()
  _state.sessions        = _state.sessions + 1
  _state.last_seen       = os.time()
  _state.current_session = os.time()
  _state._dirty          = true
end

function M.push(event_type, text, opts)
  if not event_type then return end
  opts = opts or {}
  table.insert(_state.events, 1, {
    t       = os.time(),
    session = _state.current_session,
    type    = tostring(event_type),
    screen  = opts.screen or "unknown",
    text    = tostring(text or ""),
    emotion = opts.emotion or "standard",
    silent  = opts.silent or false,
    meta    = opts.meta,
  })
  while #_state.events > MAX_EVENTS do
    table.remove(_state.events)
  end
  _state._dirty = true
end

function M.update(dt)
  if not _state._dirty then return end
  if os.time() - _state._last_flush < FLUSH_SECS then return end
  save_now()
end

function M.flush()
  if _state._dirty then save_now() end
end

function M.recent(n)
  n = n or 10
  local out = {}
  for i = 1, math.min(n, #_state.events) do
    local ev = _state.events[i]
    out[i] = {
      t       = ev.t,
      session = ev.session,
      type    = ev.type,
      screen  = ev.screen,
      text    = ev.text,
      emotion = ev.emotion,
      silent  = ev.silent,
      meta    = ev.meta,
    }
  end
  return out
end

function M.by_screen(screen_name, n)
  n = n or 20
  local out, count = {}, 0
  for _, ev in ipairs(_state.events) do
    if ev.screen == screen_name then
      count = count + 1
      out[count] = ev
      if count >= n then break end
    end
  end
  return out
end

function M.by_type(event_type, n)
  n = n or 20
  local out, count = {}, 0
  for _, ev in ipairs(_state.events) do
    if ev.type == event_type then
      count = count + 1
      out[count] = ev
      if count >= n then break end
    end
  end
  return out
end

function M.sessions()   return _state.sessions     end
function M.session_id() return _state.current_session end

function M.clear()
  _state.events = {}
  _state._dirty = true
  save_now()
end

return M