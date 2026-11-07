-- frontend/minoru/init.lua
-- Minoru⁶ — autonomous character engine.
--
-- Public API:
--   local Minoru = require("minoru")
--   local m = Minoru.new({ screen = "external_input_station",
--                          form   = "desk_lamp",
--                          on_say = function(engine, info) ... end })
--   m:say("greeting")            -- speech
--   m:observe("pair_attempt")    -- feed persona + history
--   m:set_form("holo")           -- swap support form
--   m:emote_visor("paradox")     -- silent visor reaction
--   m:serious(20)                -- 20 s of no-humour mode
--   m:meta_speak()               -- future-narrator voice
--   m:rig_ref()                  -- direct rig access
--
--   function love.update(dt) m:update(dt) end
--   function love.draw()     m:draw(x, y, w, h) end
--   on screen exit:          m:flush()
--
-- Persona, history and workspace persist under frontend/minoru/data/.
-- The module is fully self-contained: no external libs, no binaries.

local Avatar    = require("minoru.avatar")
local World     = require("minoru.world")
local Lines     = require("minoru.lines")
local Workspace = require("minoru.workspace")
local Persona   = require("minoru.persona")
local History   = require("minoru.history")
local MAssets   = require("minoru.assets")

local SFX       = require("sfx")
local A         = require("assets")

local Engine = {}
Engine.__index = Engine

-- ── Constructor ──────────────────────────────────────────────
function Engine.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Engine)

  self.screen_name = opts.screen or "unknown"
  self.form        = opts.form   or "holo"

  self.avatar      = Avatar.new()
  self.world       = World.new(opts.world or {})

  Persona.init()
  History.init()
  Workspace.init()

  self.bubble          = nil
  self.bubble_queue    = {}
  self.hold_after_done = opts.hold_after_done or 0.55
  self._hold_t         = 0
  self._used           = {}
  self._idle_t         = 0
  self._last_av        = nil

  -- Optional listener for speech events (used by the Minoru Room
  -- chat log). Receives (self, { text, emotion, pool }).
  self.on_say      = opts.on_say
  self.last_spoken = nil

  local a = opts.anchors or {}
  self:set_anchors(a.left or 200, a.center or 320, a.right or 420)

  return self
end

-- ── Anchors ──────────────────────────────────────────────────
function Engine:set_anchors(left_x, center_x, right_x)
  self._anchor_left_x   = left_x
  self._anchor_center_x = center_x
  self._anchor_right_x  = right_x
end

local function pick_anchor(self, pos)
  if     pos == "left"  then return self._anchor_left_x   or 200 end
  if     pos == "right" then return self._anchor_right_x  or 420 end
  return self._anchor_center_x or 320
end

-- ── Support form ─────────────────────────────────────────────
local KNOWN_FORMS = {
  desk_lamp = true,
  wrist     = true,
  holo      = true,
  mecha     = true,
  professor = true,
  napoleon  = true,
  comedic   = true,
}

function Engine:set_form(form)
  if KNOWN_FORMS[form] then
    self.form = form
  else
    self.form = form   -- accept unknown; falls back to procedural
  end
end

-- ── Speech ───────────────────────────────────────────────────
function Engine:say(pool_name, opts)
  opts = opts or {}

  -- Altruismo Selettivo: if the persona is serious, joke pools are
  -- refused outright; the picker redirect handles the rest.
  if Persona.is_serious()
     and (pool_name == "ext_taunt"
          or pool_name == "error"
          or pool_name == "greeting"
          or pool_name == "canon_tease_pips") then
    pool_name = "serious_console"
  end

  local line
  if Lines.pools[pool_name] then
    self._used[pool_name] = self._used[pool_name] or {}
    line = Lines.pick(pool_name, self._used[pool_name])
  elseif type(pool_name) == "string" then
    line = { text = pool_name, delay = 0.018, pos = "center",
             emotion = "standard" }
  end
  if not line then return end

  if opts.emotion and opts.emotion ~= "auto" then
    line.emotion = opts.emotion
  end

  if opts.priority then
    self.bubble_queue = {}
    self.bubble = nil
  end

  if self.bubble and not self.bubble.done then
    table.insert(self.bubble_queue, line)
    return
  end

  -- Tag the origin pool so the on_say hook can report it.
  line.pool = pool_name
  self:_start_bubble(line)

  if opts.silent ~= true then
    pcall(SFX.play, MAssets.sfx.talk_blip)
  end

  pcall(History.push, pool_name, line.text, {
    emotion = line.emotion or "standard",
    screen  = self.screen_name,
    meta    = { form = self.form },
  })
end

-- Meta-narrator voice ("Minoru of the future").
function Engine:meta_speak(pool_name)
  pool_name = pool_name or "meta_reader"
  self:say(pool_name, { emotion = "paradox", priority = true })
  pcall(Persona.observe, "quote_used", {})
end

function Engine:_start_bubble(line)
  local emotion = line.emotion or "auto"
  if emotion == "auto" or not emotion or emotion == "" then
    emotion = Persona.suggested_emotion()
  end

  self.bubble = {
    text    = line.text,
    delay   = line.delay or 0.020,
    pos     = line.pos   or "center",
    emotion = emotion,
    prompt  = line.prompt or false,
    t       = 0,
    typed   = 0,
    done    = false,
  }
  self._hold_t = 0

  local target = pick_anchor(self, self.bubble.pos)
  self.avatar:walk_to(target)
  self.avatar:set_state("talk")
  self.avatar:set_emotion(emotion)

  -- If the line carries a paradox emotion, fire the persona signal.
  if emotion == "paradox" then
    pcall(Persona.observe, "paradox_signal", {})
  end

  -- Notify listeners (used by the Minoru Room chat log).
  self.last_spoken = {
    text    = line.text,
    emotion = emotion,
    pool    = line.pool or nil,
  }
  if self.on_say then
    pcall(self.on_say, self, self.last_spoken)
  end
end

-- ── Observation ──────────────────────────────────────────────
function Engine:observe(event_name, extra)
  extra = extra or {}
  pcall(Persona.observe, event_name, { screen = self.screen_name })
  pcall(History.push, event_name, extra.text or event_name, {
    emotion = extra.emotion or Persona.suggested_emotion(),
    screen  = self.screen_name,
    silent  = extra.silent or true,
    meta    = extra.meta,
  })
end

function Engine:emote_visor(name)
  self.avatar:set_emotion(name)
end

function Engine:serious(duration)
  Persona.set_serious(true, duration or 20.0)
  self.bubble_queue = {}
  self.avatar:set_emotion("apprehension")
end

function Engine:is_serious()
  return Persona.is_serious()
end

function Engine:rig_ref()
  return self.avatar:rig_ref()
end

-- ── Update ───────────────────────────────────────────────────
function Engine:update(dt)
  self.world:update(dt)
  Workspace.update(dt)
  self.avatar:update(dt)
  Persona.update(dt)
  History.update(dt)

  if self.bubble then
    local b = self.bubble
    if not b.done then
      local prev = math.floor(b.typed)
      b.typed = b.typed + dt / b.delay
      if math.floor(b.typed) > prev and math.floor(b.typed) % 4 == 0 then
        pcall(SFX.play, MAssets.sfx.talk_blip)
      end
      if b.typed >= #b.text then
        b.typed = #b.text
        b.done  = true
        self._hold_t = 0
      end
    else
      self._hold_t = self._hold_t + dt
      local hold = b.prompt and 1.4 or self.hold_after_done
      if self._hold_t >= hold then
        self.bubble = nil
        if #self.bubble_queue > 0 then
          local next_line = table.remove(self.bubble_queue, 1)
          self:_start_bubble(next_line)
        else
          self.avatar:set_state("idle")
          self.avatar:set_emotion(Persona.suggested_emotion())
        end
      end
    end
  else
    self._idle_t = (self._idle_t or 0) + dt
    if self._idle_t > 12 and not Persona.is_serious()
       and math.random() < 0.006 then
      self._idle_t = 0
      self:say("idle")
    end
  end
end

-- ── Draw ─────────────────────────────────────────────────────
function Engine:draw(x, y, w, h)
  self.world:draw(x, y, w, h)

  local size_factor = 0.46
  if     self.form == "holo"      then size_factor = 0.40
  elseif self.form == "wrist"     then size_factor = 0.32
  elseif self.form == "mecha"     then size_factor = 0.56
  elseif self.form == "desk_lamp" then size_factor = 0.50
  end

  local av_size = math.min(96, h * size_factor)
  local av_x    = (self.avatar.x or (x + w * 0.5)) - av_size / 2
  local av_y    = y + h - av_size - h * 0.10
  av_x = math.max(x + 4, math.min(x + w - av_size - 4, av_x))

  self.avatar:draw(av_x, av_y, av_size, nil)
  self._last_av = { x = av_x, y = av_y, size = av_size }

  if self.bubble then
    self:_draw_bubble(self.bubble, x, y, w, h)
  end

  self:_draw_workspace_hud(x, y, w, h)
  self:_draw_form_tag(x, y, w, h)
end

function Engine:_draw_form_tag(x, y, w, h)
  local labels = {
    desk_lamp  = "DESK UNIT",
    wrist      = "SUITAI WRIST × NODE5",
    holo       = "HOLOGRAPHIC UNIT",
    mecha      = "MECHA INTEGRATION",
    professor  = "PROFESSOR UNIT",
    napoleon   = "NAPOLEON UNIT",
    comedic    = "COMEDIC UNIT",
  }
  local label = labels[self.form] or "MINORU"
  love.graphics.setFont(
    A.font("assets/fonts/JetBrainsMono-Regular.ttf", 8))
  love.graphics.setColor(0.55, 0.62, 0.72, 0.6)
  love.graphics.print(label, x + 10, y + h - 14)
end

function Engine:_draw_bubble(b, x, y, w, h)
  local shown = b.text:sub(1, math.floor(b.typed))
  local fully = b.typed >= #b.text

  local bw = math.min(440, w * 0.72)
  local bh = 104
  local bx = x + 18
  local by = y + h - bh - 18

  love.graphics.setColor(0.04, 0.05, 0.09, 0.96)
  love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)

  local em  = Lines.emotions[b.emotion] or Lines.emotions.standard
  local col = { em.r, em.g, em.b }
  love.graphics.setColor(col[1], col[2], col[3], 0.75)

  local D = require("ui.draw")
  D.rough_rect(bx, by, bw, bh,
    { jitter = 0.8, thickness = 1.6, seed = 77 })

  local av = self._last_av or { x = x, y = y, size = 40 }
  local tip_x = math.max(bx + bw + 4,
                  math.min(bx + bw + 44, av.x + av.size / 2))
  local tip_y = by + 30
  love.graphics.setColor(0.04, 0.05, 0.09, 0.96)
  love.graphics.polygon("fill",
    bx + bw, tip_y - 8,
    tip_x,   tip_y,
    bx + bw, tip_y + 10)

  love.graphics.setColor(col)
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 10))
  love.graphics.print("MINORU\u{2077}  \u{00B7}  R.I.", bx + 12, by + 8)

  love.graphics.setColor(col[1], col[2], col[3], 0.55)
  love.graphics.printf(b.emotion:upper(),
    bx, by + 9, bw - 12, "right")

  love.graphics.setColor(0.92, 0.95, 1.00)
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Regular.ttf", 11))
  love.graphics.printf(shown, bx + 12, by + 28, bw - 24, "left")

  if not fully and math.floor(b.typed * 8) % 2 == 0 then
    local _, wrapped = love.graphics.getFont():getWrap(shown, bw - 24)
    local last = wrapped[#wrapped] or ""
    local lw = love.graphics.getFont():getWidth(last)
    local ly = by + 28 + (#wrapped - 1) * 16
    love.graphics.rectangle("fill", bx + 12 + lw + 1, ly, 6, 12)
  end

  if b.prompt then
    love.graphics.setColor(0.70, 0.80, 0.92)
    love.graphics.setFont(A.font("assets/fonts/Oxanium-Regular.ttf", 9))
    love.graphics.printf("[A] Continue   [B] Skip all",
      bx, by + bh - 14, bw, "center")
  end
end

function Engine:_draw_workspace_hud(x, y, w, h)
  local files = Workspace.all()
  if not files or #files == 0 then return end

  local pw = 220
  local ph = 16 + #files * 16
  local px = x + w - pw - 12
  local py = y + 12

  love.graphics.setColor(0.02, 0.03, 0.05, 0.82)
  love.graphics.rectangle("fill", px, py, pw, ph, 4, 4)
  love.graphics.setColor(0.30, 0.85, 1.00, 0.35)
  love.graphics.rectangle("line", px, py, pw, ph, 4, 4)

  love.graphics.setColor(0.30, 0.85, 1.00, 0.9)
  love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf", 9))
  love.graphics.print("> WORKSPACE", px + 8, py + 4)

  local foc = Workspace.focused()
  for i, f in ipairs(files) do
    local ry = py + 16 + (i - 1) * 16
    local is_foc = (f == foc)
    local label = f.name
    if #label > 22 then label = label:sub(1, 20) .. ".." end

    love.graphics.setColor(is_foc and {0.90, 0.95, 1.00}
                                 or {0.55, 0.62, 0.72})
    love.graphics.setFont(
      A.font("assets/fonts/JetBrainsMono-Regular.ttf", 8))
    love.graphics.print(label, px + 8, ry)

    local bar_x = px + 110
    local bar_w = pw - 130
    love.graphics.setColor(0.12, 0.15, 0.20, 1)
    love.graphics.rectangle("fill", bar_x, ry + 3, bar_w, 6, 3, 3)
    local col = is_foc and {0.30, 0.85, 0.40} or {0.30, 0.55, 0.80}
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", bar_x, ry + 3,
      bar_w * (f.progress or 0), 6, 3, 3)

    love.graphics.setColor(0.55, 0.62, 0.72)
    love.graphics.setFont(
      A.font("assets/fonts/JetBrainsMono-Regular.ttf", 7))
    love.graphics.printf(("%3d%%"):format(math.floor((f.progress or 0) * 100)),
      bar_x, ry + 1, bar_w, "right")
  end
end

function Engine:flush()
  Persona.flush()
  History.flush()
  Workspace.flush()
end

Engine.Persona   = Persona
Engine.History   = History
Engine.Lines     = Lines
Engine.Workspace = Workspace

return Engine