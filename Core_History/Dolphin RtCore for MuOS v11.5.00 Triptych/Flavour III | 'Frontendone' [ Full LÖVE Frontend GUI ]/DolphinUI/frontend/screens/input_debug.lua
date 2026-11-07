-- frontend/screens/input_debug.lua
-- Input analysis + remap tool.
--
-- v0.5.0 — full redesign
--
-- The old "live event log" was a dead end: it could not produce a
-- complete picture of how the device maps buttons and axes, and B
-- could not leave the screen because main.lua never calls S.pad when
-- the screen owns S.joystickpressed. This rewrite handles ALL logical
-- dispatch inside S.joystickpressed, so B always works.
--
-- Modes:
--   MENU     — device info + "START INPUT ANALYSIS" + "MANUAL REMAP"
--   EXPLAIN  — animated overlay explaining the process
--   CAPTURE  — one big icon at a time, 10 s countdown, records every
--              event (raw button, semantic name, hat, axis)
--   STICK    — guided LEFT/RIGHT analog stick calibration
--   SUMMARY  — review results, save JSON to data/logs/
--   REMAP    — legacy manual remap table (stub, see notes below)
--
-- Input routing:
--   State.raw_input = true for the whole screen.
--   S.joystickpressed / S.joystickhat / S.joystickaxis / S.gamepadpressed
--   are defined, so main.lua hands us every event before any global
--   handler and BEFORE the 80 ms input_ok debounce.

local A      = require("assets")
local SFX    = require("sfx")
local State  = require("state")
local IM     = require("input_map")
local D      = require("ui.draw")
local BG     = require("ui.bg")
local Header = require("ui.header")
local BI     = require("ui.button_icons")
local Icons  = require("ui.icons")
local json   = require("json")
local sh     = require("sh")

local S = {}
local W, H = 640, 480

-- ══════════════════════════════════════════════════════════════
--  Analysis steps
-- ══════════════════════════════════════════════════════════════
local BUTTON_STEPS = {
  { key = "dpad_up",    icon = "dpad",   label = "D-Pad UP",    hint = "Press the D-Pad UP"    },
  { key = "dpad_down",  icon = "dpad",   label = "D-Pad DOWN",  hint = "Press the D-Pad DOWN"  },
  { key = "dpad_left",  icon = "dpad",   label = "D-Pad LEFT",  hint = "Press the D-Pad LEFT"  },
  { key = "dpad_right", icon = "dpad",   label = "D-Pad RIGHT", hint = "Press the D-Pad RIGHT" },
  { key = "a",          icon = "a",      label = "A",           hint = "Press the A button"    },
  { key = "b",          icon = "b",      label = "B",           hint = "Press the B button"    },
  { key = "x",          icon = "x",      label = "X",           hint = "Press the X button"    },
  { key = "y",          icon = "y",      label = "Y",           hint = "Press the Y button"    },
  { key = "start",      icon = "start",  label = "START",       hint = "Press START"           },
  { key = "select",     icon = "select", label = "SELECT",      hint = "Press SELECT"          },
  { key = "l1",         icon = "l1",     label = "L1",          hint = "Press the L1 shoulder" },
  { key = "l2",         icon = "l2",     label = "L2",          hint = "Pull the L2 trigger"   },
  { key = "l3",         icon = "l3",     label = "L3",          hint = "Click the LEFT stick"  },
  { key = "r1",         icon = "r1",     label = "R1",          hint = "Press the R1 shoulder" },
  { key = "r2",         icon = "r2",     label = "R2",          hint = "Pull the R2 trigger"   },
  { key = "r3",         icon = "r3",     label = "R3",          hint = "Click the RIGHT stick" },
  { key = "menu",       icon = "menu",   label = "MENU (M)",    hint = "Press the MENU button" },
}

local STICK_STEPS = {
  { key = "stick_left",  label = "LEFT STICK",
    hint = "Rotate the LEFT stick slowly to its maximum range in\n" ..
           "every direction, then let it rest at center." },
  { key = "stick_right", label = "RIGHT STICK",
    hint = "Rotate the RIGHT stick slowly to its maximum range in\n" ..
           "every direction, then let it rest at center." },
}

local CAPTURE_TIMEOUT = 10.0
local STICK_DURATION  = 18.0
local TRANSITION_DUR  = 0.32

-- ══════════════════════════════════════════════════════════════
--  State
-- ══════════════════════════════════════════════════════════════
S.mode         = "menu"       -- menu | explain | capture | stick | summary | remap
S.step_index   = 1
S.t            = 0
S.transition   = nil
S.results      = nil
S._capture     = nil
S._commit_at   = nil
S._stick_min   = nil
S._stick_max   = nil
S.menu_sel     = 1
S.toast        = nil

-- ══════════════════════════════════════════════════════════════
--  Device info + manual map
-- ══════════════════════════════════════════════════════════════
local function collect_device()
  local info = {
    name = "?", guid = "?", is_gamepad = false,
    buttons = 0, axes = 0, hats = 0, count = 0,
  }
  if not (love.joystick and love.joystick.getJoysticks) then return info end
  local list = love.joystick.getJoysticks()
  info.count = #list
  local j = list[1]
  if not j then return info end
  pcall(function() info.name       = j:getName()        end)
  pcall(function() info.guid       = j:getGUID()        end)
  pcall(function() info.is_gamepad = j:isGamepad()      end)
  pcall(function() info.buttons    = j:getButtonCount() end)
  pcall(function() info.axes       = j:getAxisCount()   end)
  pcall(function() info.hats       = j:getHatCount()    end)
  return info
end

local function manual_map_info()
  local f = io.open("data/joystick_map.json", "r")
  if not f then return { has = false, count = 0 } end
  local c = f:read("*a"); f:close()
  if not c or c == "" then return { has = false, count = 0 } end
  local ok, data = pcall(json.decode, c)
  if not ok or type(data) ~= "table" then return { has = false, count = 0 } end
  local n = 0
  for k, _ in pairs(data) do
    if type(k) == "string" and k:sub(1, 1) ~= "_" then n = n + 1 end
  end
  return { has = n > 0, count = n }
end

-- ══════════════════════════════════════════════════════════════
--  Toast
-- ══════════════════════════════════════════════════════════════
local function flash(msg, ttl)
  S.toast = { msg = msg, ttl = ttl or 2.5, t = 0 }
end

-- ══════════════════════════════════════════════════════════════
--  Event trace
-- ══════════════════════════════════════════════════════════════
local function trace(kind, detail)
  local c = S._capture
  if not c then return end
  table.insert(c.events, {
    t = string.format("%.3f", love.timer.getTime() - c.started_at),
    kind = kind, detail = detail,
  })
  if #c.events > 300 then table.remove(c.events, 1) end
end

-- ══════════════════════════════════════════════════════════════
--  Mode transitions
-- ══════════════════════════════════════════════════════════════
local begin_button_capture

local function start_analysis()
  S.results = {
    started_at  = os.date("%Y-%m-%d %H:%M:%S"),
    device      = collect_device(),
    manual_map  = manual_map_info(),
    buttons     = {},
    sticks      = {},
  }
  S.step_index = 1
  S.mode       = "explain"
  S.t          = 0
  SFX.play("menu_select")
end

function begin_button_capture()
  local step = BUTTON_STEPS[S.step_index]
  if not step then
    S.mode = "stick"
    S.step_index = 1
    S._stick_min, S._stick_max = {}, {}
    S.t = 0
    return
  end
  S.mode = "capture"
  S._capture = {
    step          = step,
    started_at    = love.timer.getTime(),
    pressed       = false,
    released      = false,
    first_press_t = nil,
    release_t     = nil,
    raw_button    = nil,
    semantic      = nil,
    hat           = nil,
    hat_dir       = nil,
    axes_seen     = {},
    events        = {},
  }
  S._commit_at = nil
end

local function finish_button_capture(reason)
  local c = S._capture
  if not c then return end

  S.results.buttons[c.step.key] = {
    step       = c.step.key,
    label      = c.step.label,
    pressed    = c.pressed,
    released   = c.released,
    raw_button = c.raw_button,
    semantic   = c.semantic,
    hat        = c.hat,
    hat_dir    = c.hat_dir,
    press_time = (c.first_press_t and c.release_t)
                  and (c.release_t - c.first_press_t) or nil,
    axes_seen  = c.axes_seen,
    events     = c.events,
    timed_out  = (reason == "timeout"),
    skipped    = (reason == "skip"),
  }

  local next_idx = S.step_index + 1
  S.transition = {
    t = 0, dur = TRANSITION_DUR,
    on_mid = function()
      S.step_index = next_idx
      if next_idx > #BUTTON_STEPS then
        S._capture = nil
        S.mode = "stick"
        S.step_index = 1
        S._stick_min, S._stick_max = {}, {}
        S.t = 0
      else
        begin_button_capture()
      end
    end,
  }
end

local function finish_stick()
  local step = STICK_STEPS[S.step_index]
  if step then
    local minmax = {}
    for ax, mn in pairs(S._stick_min or {}) do
      minmax[ax] = { min = mn, max = (S._stick_max or {})[ax] or 0 }
    end
    S.results.sticks[step.key] = minmax
  end
  S.step_index = S.step_index + 1
  if S.step_index > #STICK_STEPS then
    S.mode = "summary"
  else
    S._stick_min, S._stick_max = {}, {}
    S.t = 0
  end
end

local function skip_current()
  if S.mode == "capture" then
    finish_button_capture("skip")
  elseif S.mode == "stick" then
    finish_stick()
  end
end

local function save_results()
  if not S.results then return nil end
  S.results.finished_at = os.date("%Y-%m-%d %H:%M:%S")
  local ts = os.date("%Y%m%d_%H%M%S")
  local path = "data/logs/input_analysis_" .. ts .. ".json"
  os.execute("mkdir -p data/logs")
  local ok, encoded = pcall(json.encode, S.results)
  if not ok then
    flash("Cannot encode results", 3.0)
    return nil
  end
  sh.atomic_write(path, encoded)
  flash("Saved: " .. path, 3.5)
  return path
end

-- ══════════════════════════════════════════════════════════════
--  Lifecycle
-- ══════════════════════════════════════════════════════════════
function S.enter()
  S.mode        = "menu"
  S.menu_sel    = 1
  S.step_index  = 1
  S.t           = 0
  S._capture    = nil
  S._commit_at  = nil
  S._stick_min  = nil
  S._stick_max  = nil
  S.results     = nil
  S.transition  = nil
  S.toast       = nil
  State.raw_input    = true
  State.capture_mode = false
end

function S.leave()
  State.raw_input    = false
  State.capture_mode = false
end

function S.re_enter()
  State.raw_input = true
end

-- ══════════════════════════════════════════════════════════════
--  Helpers: logical from raw
-- ══════════════════════════════════════════════════════════════
local function logical_of(button)
  return IM.raw_to_logical[button]
end

-- ══════════════════════════════════════════════════════════════
--  Raw event handlers
-- ══════════════════════════════════════════════════════════════
function S.joystickpressed(j, button)
  -- Capture mode: record everything, never lose a press.
  if S.mode == "capture" then
    local c = S._capture
    if not c then return end
    local logical = logical_of(button)

    -- START is the universal "skip" during analysis.
    if logical == "START" then
      skip_current()
      return
    end

    c.pressed = true
    if not c.raw_button then c.raw_button = button end
    if not c.first_press_t then
      c.first_press_t = love.timer.getTime()
    end
    trace("raw", string.format("btn #%d %s", button, logical or "?"))
    return
  end

  -- Stick mode: log button presses too, but only START is meaningful.
  if S.mode == "stick" then
    local logical = logical_of(button)
    if logical == "START" then skip_current(); return end
    return
  end

  -- Menu mode.
  if S.mode == "menu" then
    local logical = logical_of(button)
    if logical == "A" then
      if S.menu_sel == 1 then start_analysis()
      elseif S.menu_sel == 2 then
        S.mode = "remap"
        flash("Remap table is legacy — [B] to go back", 3.0)
      end
    elseif logical == "B" then
      S.transition = nil
      State.raw_input = false
      State.back()
    end
    return
  end

  -- Explain mode: any button advances.
  if S.mode == "explain" then
    begin_button_capture()
    return
  end

  -- Summary mode.
  if S.mode == "summary" then
    local logical = logical_of(button)
    if logical == "A" then
      save_results()
    elseif logical == "B" then
      S.mode = "menu"
    end
    return
  end

  -- Remap mode (stub).
  if S.mode == "remap" then
    local logical = logical_of(button)
    if logical == "B" then S.mode = "menu" end
    return
  end
end

function S.joystickreleased(j, button)
  if S.mode ~= "capture" then return end
  local c = S._capture
  if not c then return end
  if c.raw_button and button == c.raw_button then
    c.released = true
    c.release_t = love.timer.getTime()
    trace("rel", string.format("btn #%d", button))
    S._commit_at = love.timer.getTime() + 0.15
  end
end

function S.joystickhat(j, hat, dir)
  if S.mode == "capture" then
    local c = S._capture
    if not c then return end
    if dir == "c" then
      if c.hat_dir then
        c.released = true
        c.release_t = love.timer.getTime()
        S._commit_at = love.timer.getTime() + 0.15
        trace("hat_rel", string.format("hat %d", hat))
      end
    else
      c.hat = hat
      c.hat_dir = dir
      if not c.pressed then
        c.pressed = true
        c.first_press_t = love.timer.getTime()
      end
      trace("hat", string.format("hat %d dir %s", hat, dir))
    end
    return
  end
  -- Menu navigation via hat.
  if S.mode == "menu" then
    if dir == "u" or dir == "lu" or dir == "ru" then
      S.menu_sel = math.max(1, S.menu_sel - 1); SFX.play("menu_move")
    elseif dir == "d" or dir == "ld" or dir == "rd" then
      S.menu_sel = math.min(2, S.menu_sel + 1); SFX.play("menu_move")
    end
    return
  end
end

function S.joystickaxis(j, axis, value)
  if S.mode == "capture" then
    local c = S._capture
    if not c then return end
    local e = c.axes_seen[axis]
    if not e then
      c.axes_seen[axis] = { min = value, max = value, last = value }
    else
      if value < e.min then e.min = value end
      if value > e.max then e.max = value end
      e.last = value
    end
    return
  end
  if S.mode == "stick" then
    S._stick_min = S._stick_min or {}
    S._stick_max = S._stick_max or {}
    local mn, mx = S._stick_min[axis], S._stick_max[axis]
    if not mn or value < mn then S._stick_min[axis] = value end
    if not mx or value > mx then S._stick_max[axis] = value end
    -- Axis 1/2 can also drive menu nav.
    if S.mode == "menu" and axis == 1 then
      if value > 0.7 then
        -- handled nowhere for now
      end
    end
    return
  end
end

function S.gamepadpressed(j, name)
  -- Only record semantic name during capture. Never drive UI here,
  -- because SDL fires this right after joystickpressed for the same
  -- physical button on a recognized GameController.
  if S.mode == "capture" and S._capture then
    S._capture.semantic = S._capture.semantic or name
    trace("sem", name)
  end
end

function S.gamepadaxis(j, axis, value)
  -- forward into stick analysis, if applicable
  if S.mode == "stick" and (axis == "triggerleft" or axis == "triggerright") then
    return
  end
end

-- Legacy pad handler — never called by main.lua here because we own
-- S.joystickpressed, but kept as a safety net if main.lua changes.
function S.pad(_)
end

function S.key(k)
  if k == "escape" then
    S.transition = nil
    State.raw_input = false
    State.back()
  elseif k == "space" then
    -- quick escape hatch for testing
    if S.mode == "capture" or S.mode == "stick" then skip_current() end
  end
end

-- ══════════════════════════════════════════════════════════════
--  Update
-- ══════════════════════════════════════════════════════════════
function S.update(dt)
  S.t = S.t + dt
  if S.toast then
    S.toast.t = S.toast.t + dt
    if S.toast.t >= S.toast.ttl then S.toast = nil end
  end

  if S.transition then
    S.transition.t = S.transition.t + dt
    if S.transition.t >= S.transition.dur / 2 and S.transition.on_mid then
      local cb = S.transition.on_mid
      S.transition.on_mid = nil
      cb()
    end
    if S.transition.t >= S.transition.dur then
      S.transition = nil
    end
    return
  end

  if S.mode == "capture" then
    local c = S._capture
    if c then
      local now = love.timer.getTime()
      if not c.pressed and (now - c.started_at) > CAPTURE_TIMEOUT then
        finish_button_capture("timeout")
        return
      end
      if S._commit_at and now >= S._commit_at then
        S._commit_at = nil
        finish_button_capture("ok")
      end
    end
  elseif S.mode == "stick" then
    if S.t >= STICK_DURATION then
      finish_stick()
    end
  end
end

-- ══════════════════════════════════════════════════════════════
--  Drawing helpers
-- ══════════════════════════════════════════════════════════════
local function chamfer(mode, x, y, w, h, cut)
  cut = cut or 4
  love.graphics.polygon(mode,
    x + cut,     y,
    x + w - cut, y,
    x + w,       y + cut,
    x + w,       y + h - cut,
    x + w - cut, y + h,
    x + cut,     y + h,
    x,           y + h - cut,
    x,           y + cut)
end

-- ══════════════════════════════════════════════════════════════
--  Draw: MENU
-- ══════════════════════════════════════════════════════════════
local function draw_menu(th)
  local dev = collect_device()
  local mm  = manual_map_info()

  local px, py, pw, ph = 24, 66, W - 48, H - 110
  love.graphics.setColor(0.05, 0.06, 0.10, 0.95)
  love.graphics.rectangle("fill", px, py, pw, ph, 8, 8)
  love.graphics.setColor(th.focus)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", px, py, pw, ph, 8, 8)
  love.graphics.setLineWidth(1)
  D.corner_brackets(px, py, pw, ph, th.focus, 16)

  -- DEVICE header
  love.graphics.setColor(th.focus)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.print("DEVICE", px + 20, py + 14)

  local yy = py + 32
  local function row(label, value, col)
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print(label, px + 20, yy)
    love.graphics.setColor(col or th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print(tostring(value or "—"), px + 140, yy)
    yy = yy + 16
  end

  row("Name",       dev.name)
  row("GUID",       dev.guid)
  row("Gamepad",    dev.is_gamepad and "YES" or "NO",
      dev.is_gamepad and {0.30,0.80,0.40} or {0.90,0.30,0.30})
  row("Buttons",    dev.buttons)
  row("Axes",       dev.axes)
  row("Hats",       dev.hats)

  yy = yy + 8
  love.graphics.setColor(th.focus)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.print("MANUAL MAPPING", px + 20, yy)
  yy = yy + 18
  if mm.has then
    love.graphics.setColor(0.30, 0.80, 0.40)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print(string.format("YES — %d override(s)", mm.count or 0),
      px + 20, yy)
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.print("data/joystick_map.json is loaded", px + 20, yy + 14)
  else
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.print("NO — using factory defaults", px + 20, yy)
  end

  -- Menu items
  local my = py + ph - 108
  local items = {
    { label = "START INPUT ANALYSIS", color = {0.30, 0.80, 0.60},
      desc  = "Guided button + analog stick analysis" },
    { label = "MANUAL REMAP TABLE",   color = {0.20, 0.72, 0.98},
      desc  = "Legacy button remap (deprecated)" },
  }
  for i, it in ipairs(items) do
    local focused = (i == S.menu_sel)
    local x = px + 20
    local y = my + (i - 1) * 48
    local w = pw - 40
    local h = 42

    if focused then
      love.graphics.setColor(it.color[1]*0.22, it.color[2]*0.22,
        it.color[3]*0.22, 0.95)
      love.graphics.rectangle("fill", x, y, w, h, 6, 6)
      love.graphics.setColor(it.color)
      D.rough_rect(x, y, w, h,
        { jitter = 1.0, thickness = 2.5, seed = i * 11 })
      D.corner_brackets(x, y, w, h, it.color, 12)
    else
      love.graphics.setColor(0.10, 0.12, 0.16, 0.85)
      love.graphics.rectangle("fill", x, y, w, h, 6, 6)
      love.graphics.setColor(0.30, 0.30, 0.36, 0.9)
      love.graphics.rectangle("line", x, y, w, h, 6, 6)
    end

    -- Left arrow
    if focused then
      love.graphics.setColor(it.color)
      love.graphics.polygon("fill",
        x + 16, y + h/2 - 6,
        x + 26, y + h/2,
        x + 16, y + h/2 + 6)
    end

    -- Icon chip
    Icons.draw(i == 1 and "star" or "wrench",
      x + 34, y + 6, 28, it.color)

    -- Label
    love.graphics.setColor(focused and {1,1,1} or th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 13))
    love.graphics.print(it.label, x + 72, y + 6)

    -- Description
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.print(it.desc or "", x + 72, y + 24)
  end

  -- Footer
  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 9))
  love.graphics.printf("[↑↓] Navigate   [A] Confirm   [B] Back",
    px, py + ph - 22, pw, "center")
end

-- ══════════════════════════════════════════════════════════════
--  Draw: EXPLAIN overlay
-- ══════════════════════════════════════════════════════════════
local function draw_explain(th)
  local ease = math.min(1, S.t / 0.30)
  ease = 1 - (1 - ease)^3

  love.graphics.setColor(0, 0, 0, 0.85 * ease)
  love.graphics.rectangle("fill", 0, 0, W, H)

  local bw, bh = 540, 340
  local bx = (W - bw) / 2
  local by = (H - bh) / 2 + (1 - ease) * 40

  love.graphics.setColor(0.05, 0.06, 0.10, 0.98 * ease)
  love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
  love.graphics.setColor(th.focus)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)
  love.graphics.setLineWidth(1)
  D.corner_brackets(bx, by, bw, bh, th.focus, 16)

  love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.18)
  love.graphics.rectangle("fill", bx, by, bw, 42, 8, 8)

  love.graphics.setColor(th.focus)
  love.graphics.setFont(A.font(th.font_body_bold, 14))
  love.graphics.printf("INPUT ANALYSIS", bx, by + 12, bw, "center")

  local lines = {
    "You will be guided through each button, one at a time.",
    "A big icon and the button name will be shown on screen.",
    "Press AND release the button within 10 seconds.",
    "",
    "Every input event seen during the window is recorded:",
    "raw button numbers, SDL GameController names, hat",
    "directions and analog axes. Nothing is filtered.",
    "",
    "When all buttons are done, you will be asked to rotate",
    "the LEFT and then the RIGHT analog stick to measure",
    "min / max ranges and estimate a dead zone.",
    "",
    "At the end, results are saved as JSON under data/logs/.",
  }
  love.graphics.setColor(th.text)
  love.graphics.setFont(A.font(th.font_body, 11))
  local ty = by + 60
  for _, l in ipairs(lines) do
    love.graphics.print(l, bx + 28, ty)
    ty = ty + 17
  end

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 11))
  love.graphics.printf("[A] Start   [B] Cancel", bx, by + bh - 30, bw, "center")
end

-- ══════════════════════════════════════════════════════════════
--  Draw: CAPTURE
-- ══════════════════════════════════════════════════════════════
local function draw_capture(th)
  local c = S._capture
  if not c then return end
  local step = c.step

  -- Rotation flip scale X
  local sx = 1
  if S.transition then
    local p = S.transition.t / S.transition.dur
    sx = math.abs(math.cos(p * math.pi))
    if sx < 0.05 then sx = 0.05 end
  end

  love.graphics.push()
  love.graphics.translate(W/2, H/2)
  love.graphics.scale(sx, 1)
  love.graphics.translate(-W/2, -H/2)

  -- Big icon
  local icon_size = 128
  local ix = W/2 - icon_size/2
  local iy = 100

  -- Frame behind icon
  love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.10)
  love.graphics.rectangle("fill", ix - 16, iy - 16,
    icon_size + 32, icon_size + 32, 12, 12)

  BI.draw(th, step.icon, ix, iy, icon_size)

  -- Label
  love.graphics.setColor(th.text)
  love.graphics.setFont(A.font(th.font_title, 26))
  love.graphics.printf(step.label, 0, iy + icon_size + 14, W, "center")

  -- Hint
  love.graphics.setColor(th.focus)
  love.graphics.setFont(A.font(th.font_body, 13))
  love.graphics.printf(step.hint, 0, iy + icon_size + 56, W, "center")

  love.graphics.pop()

  -- Countdown bar
  local remaining = math.max(0,
    CAPTURE_TIMEOUT - (love.timer.getTime() - c.started_at))
  local bar_x, bar_y, bar_w, bar_h = 80, H - 90, W - 160, 14
  love.graphics.setColor(0.10, 0.12, 0.16, 1)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 7, 7)
  local p = remaining / CAPTURE_TIMEOUT
  local col = (p > 0.5) and {0.30, 0.80, 0.40}
           or (p > 0.2) and {0.96, 0.77, 0.26}
                        or {0.90, 0.30, 0.30}
  love.graphics.setColor(col)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w * p, bar_h, 7, 7)
  love.graphics.setColor(0.9, 0.95, 1.0)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.printf(string.format("%.1f s", remaining),
    bar_x, bar_y - 20, bar_w, "center")

  -- Status
  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 10))
  local status =
    c.released and "Captured — advancing..." or
    c.pressed and  "Release the button"        or
                   "Waiting for input..."
  love.graphics.printf(status, 0, bar_y + 22, W, "center")

  -- Step counter
  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body_bold, 10))
  love.graphics.printf(string.format("STEP %d / %d",
    S.step_index, #BUTTON_STEPS), 0, 60, W - 20, "right")

  -- Skip hint
  love.graphics.setFont(A.font(th.font_body, 9))
  love.graphics.printf("[START] Skip", 0, H - 22, W, "center")
end

-- ══════════════════════════════════════════════════════════════
--  Draw: STICK
-- ══════════════════════════════════════════════════════════════
local function draw_stick(th)
  local step = STICK_STEPS[S.step_index]
  if not step then return end

  love.graphics.setColor(th.text)
  love.graphics.setFont(A.font(th.font_title, 22))
  love.graphics.printf(step.label, 0, 70, W, "center")

  love.graphics.setColor(th.focus)
  love.graphics.setFont(A.font(th.font_body, 12))
  love.graphics.printf(step.hint, 0, 108, W, "center")

  -- Collect axes
  local keys = {}
  for ax, _ in pairs(S._stick_min or {}) do table.insert(keys, ax) end
  table.sort(keys)

  local y = 210
  for _, ax in ipairs(keys) do
    local mn = S._stick_min[ax] or 0
    local mx = S._stick_max[ax] or 0

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(
      A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10))
    love.graphics.print(string.format("axis %-2d", ax), 40, y + 1)

    local bar_x = 110
    local bar_w = W - 160
    love.graphics.setColor(0.10, 0.12, 0.16, 1)
    love.graphics.rectangle("fill", bar_x, y, bar_w, 14, 7, 7)

    local function map(v)
      local t = (v + 1) / 2
      t = math.max(0, math.min(1, t))
      return bar_x + bar_w * t
    end

    local a = map(mn)
    local b = map(mx)
    love.graphics.setColor(0.20, 0.72, 0.98)
    love.graphics.rectangle("fill", a, y, b - a, 14, 7, 7)

    -- Center marker
    love.graphics.setColor(0.9, 0.9, 0.9, 0.7)
    love.graphics.rectangle("fill", bar_x + bar_w/2 - 1, y - 2, 2, 18)

    y = y + 30
  end

  -- Countdown
  local remaining = math.max(0, STICK_DURATION - S.t)
  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body_bold, 11))
  love.graphics.printf(string.format("%.1f s", remaining),
    0, H - 70, W, "center")

  love.graphics.setFont(A.font(th.font_body, 9))
  love.graphics.printf("[START] Skip this stick", 0, H - 22, W, "center")
end

-- ══════════════════════════════════════════════════════════════
--  Draw: SUMMARY
-- ══════════════════════════════════════════════════════════════
local function draw_summary(th)
  if not S.results then return end

  love.graphics.setColor(th.text)
  love.graphics.setFont(A.font(th.font_title, 18))
  love.graphics.printf("ANALYSIS COMPLETE", 0, 60, W, "center")

  local y = 96
  local mono = A.font("assets/fonts/JetBrainsMono-Regular.ttf", 9)
  love.graphics.setFont(mono)

  for _, s in ipairs(BUTTON_STEPS) do
    local rec = S.results.buttons[s.key]
    if rec then
      local col = rec.pressed and {0.30,0.80,0.40} or {0.90,0.30,0.30}
      love.graphics.setColor(col)
      local txt = string.format("%-12s %-4s  raw=%-3s sem=%-14s hat=%s",
        s.label,
        rec.pressed and "OK" or "MISS",
        rec.raw_button and tostring(rec.raw_button) or "—",
        rec.semantic or "—",
        rec.hat_dir or "—")
      love.graphics.print(txt, 20, y)
      y = y + 12
      if y > H - 110 then break end
    end
  end

  y = y + 8
  love.graphics.setColor(th.focus)
  love.graphics.setFont(A.font(th.font_body_bold, 10))
  love.graphics.print("STICKS", 20, y); y = y + 14
  love.graphics.setFont(mono)
  for _, s in ipairs(STICK_STEPS) do
    local r = S.results.sticks[s.key]
    if r then
      love.graphics.setColor(th.text)
      love.graphics.print(s.label, 20, y)
      local parts = {}
      for ax, mm in pairs(r) do
        table.insert(parts, string.format("a%d:[%.2f..%.2f]",
          ax, mm.min, mm.max))
      end
      table.sort(parts)
      love.graphics.setColor(0.75, 0.85, 0.95)
      love.graphics.print(table.concat(parts, "  "), 160, y)
      y = y + 12
    end
  end

  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 10))
  love.graphics.printf("[A] Save JSON   [B] Back to menu",
    0, H - 40, W, "center")
end

-- ══════════════════════════════════════════════════════════════
--  Draw: REMAP (stub)
-- ══════════════════════════════════════════════════════════════
local function draw_remap(th)
  love.graphics.setColor(th.text)
  love.graphics.setFont(A.font(th.font_body_bold, 14))
  love.graphics.printf("MANUAL REMAP TABLE", 0, H/2 - 40, W, "center")
  love.graphics.setColor(th.text_dim)
  love.graphics.setFont(A.font(th.font_body, 11))
  love.graphics.printf(
    "The legacy remap table has been disabled in this revision.\n" ..
    "Use data/joystick_map.json directly, or re-add the old\n" ..
    "workshop_files.lua editor if you need manual remaps.\n\n" ..
    "[B] to go back",
    0, H/2 - 10, W, "center")
end

-- ══════════════════════════════════════════════════════════════
--  Main draw
-- ══════════════════════════════════════════════════════════════
function S.draw()
  local th = State.theme
  BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
  Header.draw("INPUT ANALYSIS", "settings")

  if     S.mode == "menu"    then draw_menu(th)
  elseif S.mode == "explain" then draw_menu(th); draw_explain(th)
  elseif S.mode == "capture" then draw_capture(th)
  elseif S.mode == "stick"   then draw_stick(th)
  elseif S.mode == "summary" then draw_summary(th)
  elseif S.mode == "remap"   then draw_remap(th)
  end

  -- Toast
  if S.toast then
    local p = S.toast.t / S.toast.ttl
    local a = (p > 0.8) and (1 - p) / 0.2 or 1
    local f = A.font(th.font_body_bold, 11)
    local fw = f:getWidth(S.toast.msg)
    local tw = math.min(W - 40, fw + 32)
    local tx = (W - tw) / 2
    local ty = H - 60
    love.graphics.setColor(0, 0, 0, 0.85 * a)
    love.graphics.rectangle("fill", tx, ty, tw, 30, 6, 6)
    love.graphics.setColor(0.30, 0.80, 0.40, a)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tx, ty, tw, 30, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.printf(S.toast.msg, tx, ty + 8, tw, "center")
  end
end

return S