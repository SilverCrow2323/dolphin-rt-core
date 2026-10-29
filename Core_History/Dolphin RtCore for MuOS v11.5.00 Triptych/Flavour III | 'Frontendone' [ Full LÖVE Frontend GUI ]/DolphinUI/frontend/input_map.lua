-- frontend/input_map.lua
-- Single source of truth for the frontend input mapping.
--
-- Two coordinate systems are in play on muOS, and they do NOT match:
--
--   1. LÖVE / frontend side   — SDL_JoystickGetButton indices as seen
--                               by the LÖVE runtime. muOS's virtual
--                               "muOS-Keys" device reports the pad
--                               here using the layout main.lua calls
--                               "Schema B" (A = 3, B = 4, X = 6,
--                               Y = 5, ...).
--
--   2. Dolphin side           — Dolphin's own SDL input source uses
--                               different raw indices for the same
--                               physical buttons. The controller
--                               profiles in workshop/controller/
--                               encode this as "Button N" values
--                               (A = Button 1, B = Button 0, ...).
--
-- Screens only ever see LOGICAL names ("A", "B", "UP", ...). main.lua
-- translates incoming raw/semantic events into a logical name before
-- dispatching them. Anything that needs the Dolphin-side index
-- (hotkey injection, profile writing) goes through
-- M.to_dolphin_raw().
--
-- ── v0.5.0 — labels + is_action ───────────────────────────────
--   * M.labels[logical] = "Button A"  (per debug UI)
--   * M.is_action(logical)  → true se è un pulsante d'azione
--     (A/B/X/Y/L1/R1/L2/R2/START/SELECT/MENU), non un d-pad.
--   * M.is_dpad_dir(logical) → true se è UP/DOWN/LEFT/RIGHT.
--
-- ── v0.4.7 — CRITICAL FIX ─────────────────────────────────────
--   Override schema versioning, fallback chain garantita.

local M = {}

-- ── Schema / versioning ─────────────────────────────────────
local SCHEMA_VERSION = 2

-- ── Schema B raw indices (muOS frontend, libSDL2) ───────────
local RAW_DEFAULTS = {
  VOL_DOWN = 1,
  VOL_UP   = 2,
  A        = 3,
  B        = 4,
  Y        = 5,
  X        = 6,
  L1       = 7,
  R1       = 8,
  SELECT   = 9,
  START    = 10,
  MENU     = 11,
  L3       = 12,
  R3       = 15,
  L2       = 13,
  R2       = 14,
}

local RAW_MIN, RAW_MAX = 0, 63

-- ── SDL GameController semantic names ───────────────────────
local SEMANTIC = {
  A      = "a",
  B      = "b",
  X      = "x",
  Y      = "y",
  L1     = "leftshoulder",
  R1     = "rightshoulder",
  L2     = "lefttrigger",
  R2     = "righttrigger",
  SELECT = "back",
  START  = "start",
  MENU   = "guide",
  UP     = "dpup",
  DOWN   = "dpdown",
  LEFT   = "dpleft",
  RIGHT  = "dpright",
}

M.SEMANTIC = SEMANTIC

-- ── Human-readable labels (per debug UI) ────────────────────
M.labels = {
  A      = "Button A",
  B      = "Button B",
  X      = "Button X",
  Y      = "Button Y",
  L1     = "Shoulder L1",
  R1     = "Shoulder R1",
  L2     = "Trigger L2",
  R2     = "Trigger R2",
  SELECT = "Select",
  START  = "Start",
  MENU   = "Menu",
  L3     = "Stick L3",
  R3     = "Stick R3",
  UP     = "D-Pad Up",
  DOWN   = "D-Pad Down",
  LEFT   = "D-Pad Left",
  RIGHT  = "D-Pad Right",
}

-- Set delle azioni (non d-pad).
local ACTIONS = {
  A = true, B = true, X = true, Y = true,
  L1 = true, R1 = true, L2 = true, R2 = true,
  SELECT = true, START = true, MENU = true,
  L3 = true, R3 = true,
}

local DPAD = {
  UP = true, DOWN = true, LEFT = true, RIGHT = true,
}

function M.is_action(logical)
  return ACTIONS[logical] == true
end

function M.is_dpad_dir(logical)
  return DPAD[logical] == true
end

function M.label(logical)
  return M.labels[logical] or tostring(logical or "?")
end

-- ── Override JSON ───────────────────────────────────────────
local OVERRIDE_PATH = "data/joystick_map.json"

local _gp_cache    = nil
local _gp_cache_at = 0
local GP_CACHE_TTL = 1.0

local function now()
  if love and love.timer then return love.timer.getTime() end
  return os.time()
end

local function any_joystick_is_gamepad()
  local t = now()
  if _gp_cache ~= nil and (t - _gp_cache_at) < GP_CACHE_TTL then
    return _gp_cache
  end
  _gp_cache_at = t
  _gp_cache    = false

  if love and love.joystick and love.joystick.getJoysticks then
    local ok, js = pcall(love.joystick.getJoysticks)
    if ok and js then
      for _, j in ipairs(js) do
        local ok2, is_gp = pcall(function() return j:isGamepad() end)
        if ok2 and is_gp then
          _gp_cache = true
          break
        end
      end
    end
  end
  return _gp_cache
end

function M.refresh_joystick_state()
  _gp_cache    = nil
  _gp_cache_at = 0
end

local function read_override()
  if any_joystick_is_gamepad() then
    return nil
  end

  local content
  if love and love.filesystem and love.filesystem.read then
    local ok, c = pcall(love.filesystem.read, OVERRIDE_PATH)
    if ok and type(c) == "string" and #c > 0 then content = c end
  end
  if not content then
    local f = io.open(OVERRIDE_PATH, "r")
    if f then content = f:read("*a"); f:close() end
  end
  if not content or content == "" then return nil end

  local ok, json = pcall(require, "json")
  if not ok or not json then return nil end
  local ok2, data = pcall(json.decode, content)
  if not ok2 or type(data) ~= "table" then return nil end

  local schema = tonumber(data._schema)
  if schema ~= SCHEMA_VERSION then
    print(string.format(
      "[input_map] ignoring %s: _schema=%s (expected %d)",
      OVERRIDE_PATH, tostring(data._schema), SCHEMA_VERSION))
    return nil
  end

  local out = {}
  for k, v in pairs(data) do
    if type(k) == "string"
       and k:sub(1, 1) ~= "_"
       and RAW_DEFAULTS[k] ~= nil
       and type(v) == "number"
       and v == math.floor(v)
       and v >= RAW_MIN and v <= RAW_MAX then
      out[k] = v
    end
  end

  if next(out) == nil then return nil end
  return out
end

local function rebuild()
  M.RAW = {}
  for k, v in pairs(RAW_DEFAULTS) do M.RAW[k] = v end

  local override = read_override()
  if override then
    for k, v in pairs(override) do
      M.RAW[k] = v
    end
  end

  M.raw_to_logical = {}
  for k, v in pairs(M.RAW) do
    M.raw_to_logical[v] = k
  end
end

rebuild()

-- ── Public API ──────────────────────────────────────────────
M.RAW_DEFAULTS   = RAW_DEFAULTS
M.SCHEMA_VERSION = SCHEMA_VERSION

function M.reload()
  M.refresh_joystick_state()
  rebuild()
end

function M.set_raw(logical, raw_index)
  if RAW_DEFAULTS[logical] == nil then
    return false, "unknown logical name: " .. tostring(logical)
  end
  if type(raw_index) ~= "number" then
    return false, "raw index must be a number"
  end
  raw_index = math.floor(raw_index)
  if raw_index < RAW_MIN or raw_index > RAW_MAX then
    return false, "raw index out of range"
  end

  local existing = M.raw_to_logical[raw_index]
  if existing and existing ~= logical then
    return false, "already bound to " .. tostring(existing)
  end

  M.RAW[logical] = raw_index
  M.raw_to_logical = {}
  for k, v in pairs(M.RAW) do M.raw_to_logical[v] = k end
  return true
end

function M.reset_raw(logical)
  if RAW_DEFAULTS[logical] == nil then return false end
  return M.set_raw(logical, RAW_DEFAULTS[logical])
end

function M.reset_all()
  M.RAW = {}
  for k, v in pairs(RAW_DEFAULTS) do M.RAW[k] = v end
  M.raw_to_logical = {}
  for k, v in pairs(M.RAW) do M.raw_to_logical[v] = k end
  os.remove(OVERRIDE_PATH)
end

function M.save()
  if any_joystick_is_gamepad() then
    return false, "gamepad recognized — override not applicable"
  end

  local delta   = {}
  local n_delta = 0
  for k, v in pairs(M.RAW) do
    if RAW_DEFAULTS[k] ~= v then
      delta[k] = v
      n_delta  = n_delta + 1
    end
  end

  if n_delta == 0 then
    os.remove(OVERRIDE_PATH)
    return true
  end

  local ok, json = pcall(require, "json")
  if not ok or not json then
    return false, "json module unavailable"
  end

  os.execute("mkdir -p data")

  local path = OVERRIDE_PATH
  local tmp  = path .. ".tmp"

  local payload = {
    _schema  = SCHEMA_VERSION,
    _comment = "DolphinUI controller remap. Keys: logical name " ..
               "→ raw SDL joystick button index seen by the LÖVE " ..
               "runtime. Only entries that differ from the factory " ..
               "default are stored. Delete this file to reset.",
  }
  for k, v in pairs(delta) do payload[k] = v end

  local f = io.open(tmp, "w")
  if not f then return false, "cannot write " .. tmp end

  local enc_ok, encoded = pcall(json.encode, payload)
  if not enc_ok then
    f:close()
    os.remove(tmp)
    return false, "json.encode failed"
  end
  f:write(encoded)
  f:close()

  os.remove(path)
  if os.rename(tmp, path) then return true end

  local function q(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
  end
  local rc = os.execute("cp " .. q(tmp) .. " " .. q(path))
  os.remove(tmp)
  if rc == true or rc == 0 then return true end
  return false, "rename and cp both failed"
end

function M.has_custom_map()
  for k, v in pairs(M.RAW) do
    if RAW_DEFAULTS[k] ~= v then return true end
  end
  return false
end

-- ── Bridge to Dolphin hotkey "Button N" ────────────────────
local DOLPHIN_HOTKEY = {
  [3]  = "1",
  [4]  = "0",
  [6]  = "2",
  [5]  = "3",
  [7]  = "9",
  [8]  = "12",
  [9]  = "6",
  [10] = "7",
  [11] = "8",
  [13] = "4",
  [14] = "5",
}

function M.to_dolphin_raw(love_raw)
  return DOLPHIN_HOTKEY[love_raw]
end

-- ── Public logical constants ───────────────────────────────
M.A      = SEMANTIC.A
M.B      = SEMANTIC.B
M.X      = SEMANTIC.X
M.Y      = SEMANTIC.Y
M.L1     = SEMANTIC.L1
M.R1     = SEMANTIC.R1
M.L2     = SEMANTIC.L2
M.R2     = SEMANTIC.R2
M.SELECT = SEMANTIC.SELECT
M.START  = SEMANTIC.START
M.MENU   = SEMANTIC.MENU
M.UP     = SEMANTIC.UP
M.DOWN   = SEMANTIC.DOWN
M.LEFT   = SEMANTIC.LEFT
M.RIGHT  = SEMANTIC.RIGHT

M.semantic_to_logical = {}
for k, v in pairs(M.SEMANTIC) do
  M.semantic_to_logical[v] = k
end

return M