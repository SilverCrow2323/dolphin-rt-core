-- frontend/minoru/persona.lua
-- Personality + mood engine for Minoru⁶.
--
-- Two layers, both persistent under frontend/minoru/data/:
--
--   1. TRAITS — slow-moving (dossier says "Sarcasmo Elicoidale",
--               "Saccente ma leale", "Altruismo Selettivo"). Every
--               meaningful event nudges them; slow drift returns
--               everything to 0.5 with disuse.
--
--   2. MOOD   — fast-moving, session-only. Frustration, satisfaction,
--               worry, wonder, affection. Rises on events, decays at
--               0.15/s.
--
-- The suggested visor emotion is derived from mood first, traits
-- second. Altruismo Selettivo is encoded as a hard rule: if
-- `worry` (or a "serious context" flag) is high, the engine refuses
-- to pick sarcastic or angry lines. Minoru knows when to shut up.
--
-- Public API:
--   Persona.init()
--   Persona.observe(event_name, extra)
--   Persona.update(dt)
--   Persona.traits() / Persona.mood()
--   Persona.suggested_emotion()
--   Persona.score_line(line)
--   Persona.set_serious(bool)     -- temporarily disable humour
--   Persona.is_serious()
--   Persona.flush()

local json = require("json")

local P = {}

-- The module is self-contained: JSON lives under frontend/minoru/data/.
local DIR        = "minoru/data"
local PATH       = DIR .. "/persona.json"
local FLUSH_SECS = 6.0
local DRIFT_RATE = 0.002
local MOOD_DECAY = 0.15

-- ── Defaults ─────────────────────────────────────────────────
local TRAIT_DEFAULTS = {
  sarcasm     = 0.65,   -- dossier: "Sarcasmo Elicoidale"
  helpfulness = 0.45,   -- dossier: "Altruismo Selettivo"
  patience    = 0.55,
  curiosity   = 0.40,
  formality   = 0.22,
  affection   = 0.30,   -- dossier: friendship with Pips
}

local MOOD_DEFAULTS = {
  frustration  = 0.0,
  satisfaction = 0.0,
  worry        = 0.0,
  wonder       = 0.0,
  affection    = 0.0,
}

-- ── Runtime state ────────────────────────────────────────────
local _traits    = {}
local _mood      = {}
local _dirty     = false
local _last_flush = 0
local _serious   = false
local _serious_t = 0
local _serious_dur = 0

local function copy(t)
  local c = {}
  for k, v in pairs(t) do c[k] = v end
  return c
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- ── Load / save ──────────────────────────────────────────────
local function load()
  for k, v in pairs(TRAIT_DEFAULTS) do _traits[k] = v end
  for k, v in pairs(MOOD_DEFAULTS)  do _mood[k]   = v end

  local f = io.open(PATH, "r")
  if not f then return end
  local c = f:read("*a"); f:close()
  local ok, data = pcall(json.decode, c)
  if not ok or type(data) ~= "table" then return end
  if type(data.traits) == "table" then
    for k, v in pairs(data.traits) do
      if _traits[k] ~= nil and type(v) == "number" then
        _traits[k] = clamp(v, 0, 1)
      end
    end
  end
end

local function save_now()
  os.execute("mkdir -p " .. DIR)
  local payload = json.encode({ traits = _traits })
  local tmp = PATH .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return end
  f:write(payload)
  f:close()
  if not os.rename(tmp, PATH) then
    os.execute("cp " .. "'" .. tmp .. "' '" .. PATH .. "'")
    os.remove(tmp)
  end
  _dirty = false
  _last_flush = os.time()
end

-- ── Event catalogue ──────────────────────────────────────────
-- Values are deliberately small: one event nudges, not rewrites.
-- `serious = true` on an event temporarily silences humour.
local EVENTS = {
  -- External input station
  pair_attempt       = { mood = { frustration = 0.10 },                     trait = { patience    = -0.010 } },
  pair_choice        = { mood = {},                                          trait = {} },
  pair_scan_start    = { mood = { wonder      = 0.05 },                     trait = { curiosity   =  0.004 } },
  pair_scan_complete = { mood = { satisfaction = 0.10, wonder = 0.06 },     trait = { curiosity   =  0.006 } },
  pair_success       = { mood = { satisfaction = 0.45, frustration = -0.30 },
                         trait = { helpfulness = 0.008, patience = 0.004 } },
  pair_failure       = { mood = { frustration = 0.25, worry = 0.10 },       trait = { patience    = -0.015 } },
  device_removed     = { mood = { frustration = 0.10 },                     trait = {} },
  device_renamed     = { mood = { satisfaction = 0.05 },                    trait = {} },
  slot_empty_press   = { mood = { frustration = 0.08 },                     trait = { sarcasm     =  0.004 } },

  -- Generic app events
  success            = { mood = { satisfaction = 0.30 },                    trait = { helpfulness =  0.005 } },
  error              = { mood = { frustration = 0.20, worry = 0.10 },       trait = { patience    = -0.010 } },
  crash              = { mood = { worry = 0.35, frustration = 0.15 },
                         trait = { patience = -0.020, affection = 0.005 } },
  session_long       = { mood = { worry = 0.10 },                           trait = {} },
  repeated_action    = { mood = { frustration = 0.15 },                     trait = { sarcasm     =  0.010 } },
  novel_input        = { mood = { wonder = 0.30 },                          trait = { curiosity   =  0.015 } },
  engaged            = { mood = { satisfaction = 0.05 },                    trait = { helpfulness =  0.002 } },

  -- Dossier-flavoured events
  quote_used         = { mood = { affection = 0.05 },                       trait = {} },
  serious_moment     = { mood = { worry = 0.30, affection = 0.20 },         trait = {},
                         serious = true, serious_dur = 25.0 },
  paradox_signal     = { mood = { wonder = 0.45 },                          trait = { curiosity   =  0.010 },
                         serious = true, serious_dur = 12.0 },
  friendship_beat    = { mood = { affection = 0.40, satisfaction = 0.20 },  trait = { affection   =  0.020 } },
}

-- ── Public API ───────────────────────────────────────────────
function P.init()
  load()
  _dirty = true
end

function P.traits() return _traits end
function P.mood()   return _mood   end

function P.set_serious(on, duration)
  _serious   = on == true
  _serious_t = 0
  _serious_dur = duration or 0
end

function P.is_serious() return _serious end

function P.observe(event_name, extra)
  if not event_name then return end
  local spec = EVENTS[event_name]
  if not spec then return end

  local amplify = 1.0
  if extra and extra.screen == "external" then amplify = 1.20 end

  for k, v in pairs(spec.mood or {}) do
    if _mood[k] ~= nil then
      _mood[k] = clamp(_mood[k] + v * amplify, 0, 1)
    end
  end
  for k, v in pairs(spec.trait or {}) do
    if _traits[k] ~= nil then
      _traits[k] = clamp(_traits[k] + v * amplify, 0, 1)
    end
  end

  if spec.serious then
    P.set_serious(true, spec.serious_dur or 20.0)
  end

  _dirty = true
end

function P.update(dt)
  -- Serious countdown
  if _serious then
    _serious_t = _serious_t + dt
    if _serious_dur > 0 and _serious_t >= _serious_dur then
      _serious = false
      _serious_t = 0
    end
  end

  -- Mood decay
  for k, v in pairs(_mood) do
    if v > 0 then
      _mood[k] = math.max(0, v - MOOD_DECAY * dt)
    end
  end

  -- Trait drift toward 0.5
  for k, v in pairs(_traits) do
    local d = 0.5 - v
    if math.abs(d) > 0.001 then
      _traits[k] = clamp(v + d * DRIFT_RATE * dt, 0, 1)
      _dirty = true
    end
  end

  if _dirty and os.time() - _last_flush > FLUSH_SECS then
    save_now()
  end
end

-- Visor emotion, derived from mood then traits.
-- Altruismo Selettivo: worry overrides sarcasm/anger entirely.
function P.suggested_emotion()
  if _serious or _mood.worry > 0.55 then return "apprehension" end
  if _mood.affection > 0.55       then return "standard"     end
  if _mood.frustration > 0.55     then return "angry"        end
  if _mood.wonder      > 0.50     then return "paradox"      end
  if _mood.frustration > 0.30     then return "sarcastic"    end
  if _mood.satisfaction> 0.45     then return "standard"     end
  if _traits.sarcasm   > 0.70     then return "sarcastic"    end
  return "standard"
end

-- Line scoring used by Lines.pick().
function P.score_line(line)
  local score = 1.0
  local em    = line.emotion or "standard"

  -- Serious mode: hard veto on humour.
  if _serious or _mood.worry > 0.55 then
    if em == "sarcastic" or em == "angry" then return 0.0 end
    if em == "standard" then score = score + 3.0 end
    if em == "apprehension" then score = score + 2.0 end
  end

  -- Mood/trait alignment.
  local suggested = P.suggested_emotion()
  if em == suggested then score = score + 2.0 end
  if em == "sarcastic"    and _traits.sarcasm    > 0.60 then score = score + 1.0 end
  if em == "standard"     and _traits.formality  > 0.50 then score = score + 0.5 end
  if em == "apprehension" and _traits.patience   < 0.40 then score = score + 0.5 end
  if em == "angry"        and _traits.patience   < 0.30 then score = score + 1.5 end
  if em == "paradox"      and _traits.curiosity  > 0.60 then score = score + 0.8 end

  if em == "paradox" and _traits.curiosity < 0.30 then score = score - 1.5 end
  if em == "angry"   and _traits.patience  > 0.70 then score = score - 1.0 end

  return score
end

function P.flush()
  if _dirty then save_now() end
end

function P.reset()
  for k, v in pairs(TRAIT_DEFAULTS) do _traits[k] = v end
  for k, v in pairs(MOOD_DEFAULTS)  do _mood[k]   = v end
  _serious = false
  _dirty = true
  save_now()
end

return P