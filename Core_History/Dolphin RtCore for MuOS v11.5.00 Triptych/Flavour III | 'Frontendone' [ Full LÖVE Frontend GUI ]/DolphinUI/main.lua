local Core   = require("core")
local UI     = require("ui")
local Notify = require("ui.notify")

-- Frame cap. conf.lua runs with vsync off, so without this the app spins a
-- core flat out (heat + battery on the H700). 60 FPS is plenty for a UI;
-- DOLPHINUI_FPS overrides it (e.g. 30 for the longest battery life).
love.fps_cap = math.max(15, tonumber(os.getenv("DOLPHINUI_FPS") or "") or 60)

-- Risparmio batteria adattivo: se nessuno tocca i tasti per un po' la UI scende
-- a 30 fps (10 s) e poi a 20 fps (60 s); al primo input torna al cap normale.
-- L'animazione resta morbida perche' tutti gli smoothing sono exp(-dt*k).
-- Disattiva con DOLPHINUI_IDLE_FPS=0 oppure setting "idle_fps" = false.
local _last_activity = 0
local function _touch() _last_activity = love.timer and love.timer.getTime() or 0 end
local _idle_env_off = os.getenv("DOLPHINUI_IDLE_FPS") == "0"
local function _idle_enabled()
  if _idle_env_off then return false end
  local ok, St = pcall(require, "core.settings")
  if ok and St.data and St.get("idle_fps") == false then return false end   -- Settings > Display
  return true
end
local function effective_cap()
  local cap = love.fps_cap or 60
  if not _idle_enabled() then return cap end
  local idle = love.timer.getTime() - _last_activity
  if idle > 60 then return math.min(cap, 20) end
  if idle > 10 then return math.min(cap, 30) end
  return cap
end

function love.run()
  if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
  if love.timer then love.timer.step() end
  _touch()
  local dt = 0
  return function()
    local t0 = love.timer.getTime()
    if love.event then
      love.event.pump()
      for name, a, b, c, d, e, f in love.event.poll() do
        if name == "quit" then
          if not love.quit or not love.quit() then return a or 0 end
        end
        love.handlers[name](a, b, c, d, e, f)
      end
    end
    -- dt limitato: dopo un hitch (scan, ritorno da Dolphin) le animazioni non
    -- "saltano" alla fine, riprendono dal punto in cui erano.
    dt = math.min(love.timer.step(), 0.05)
    if love.update then love.update(dt) end
    if love.graphics and love.graphics.isActive() then
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())
      if love.draw then love.draw() end
      love.graphics.present()
    end
    local spare = 1 / effective_cap() - (love.timer.getTime() - t0)
    if spare > 0 then love.timer.sleep(spare) end
  end
end

function love.load()
  -- copying the app (zip, file manager) can drop exec bits; harmless if the
  -- filesystem ignores chmod
  os.execute("chmod +x scripts/*.sh mux_launch.sh lib/love lib/gptokeyb2 2>/dev/null &")
  love.graphics.setDefaultFilter("linear", "linear")
  love.graphics.setBackgroundColor(0.03, 0.03, 0.05)

  pcall(function()
    require("core.crash_handler").install(
      (require("version") or {}).string or "unknown")
  end)

  Core.init()
  UI.init()

  -- Surface the outcome of the most recent launch, if any.
  pcall(function()
    local flag = "data/logs/report_pending.flag"
    local fh = io.open(flag, "r")
    if not fh then return end
    fh:close()
    os.remove(flag)
    local rh = io.open("data/logs/report_latest.txt", "r")
    if not rh then return end
    local body = rh:read("*a") or ""
    rh:close()
    local result = body:match("RESULT:%s*([^\n]+)") or ""
    if result == "" then return end
    local kind = "warning"
    if result:match("PASS") then kind = "success"
    elseif result:match("INCOMPLETE") then kind = "info" end
    require("ui.notify").show(kind, "Last launch: " .. result, 4.0)
  end)

  -- launch.sh exports DOLPHINUI_RETURN_TO when restarting the frontend
  -- after a game session. If the variable is set, skip the warning screen
  -- and jump straight to the return-to screen.
  -- CLI: --screen=<name>  jumps directly to a screen.
  local forced = nil
  if type(arg) == "table" then
    for _, a in ipairs(arg) do
      local s = tostring(a):match("^%-%-screen=(.+)$")
      if s and s ~= "" then forced = s end
    end
  end
  if forced then
    pcall(function() UI.go_instant(forced) end)
    Notify.show("info", "DEV → " .. forced, 1.2)
    return
  end

  local ret = os.getenv("DOLPHINUI_RETURN_TO")
  if ret and ret ~= "" then
    UI.go_instant(ret)
  else
    UI.go_instant("boot")
  end
  Notify.show("info", "Dolphin Rt:UI is starting.", 2.0)
  if not UI.gamepad then
    Notify.show("warning", "UI.gamepad is missing; gamepad disabled.", 6.0)
  end
end

local DevShot = require("core.devshot")

function love.update(dt)
  DevShot.update(dt)
  Core.update(dt)
  UI.update(dt)
  Notify.update(dt)
end

-- La UI e' disegnata in uno spazio logico fisso K.W x K.H (640x480). Se la
-- finestra ha un'altra risoluzione (RG34XX 720x480, CubeXX 720x720, 1280x720...)
-- si renderizza su canvas e si scala centrato con bande nere: stesse proporzioni,
-- scissor e hit-area corretti. A 640x480 nessun costo aggiuntivo.
local KitK = require("ui.kit")
local _ui_canvas

local function draw_all()
  UI.draw()
  local okS, St = pcall(require, "core.state")
  if not (okS and St.screen == "boot") then      -- keep the boot intro clean
    Notify.draw(KitK.W, KitK.H)
  end
end

function love.draw()
  local ww, wh = love.graphics.getDimensions()
  if ww == KitK.W and wh == KitK.H then draw_all(); return DevShot.after_draw() end
  if _ui_canvas == nil then
    local ok, c = pcall(love.graphics.newCanvas, KitK.W, KitK.H)
    if ok and c then c:setFilter("linear", "linear") end
    _ui_canvas = ok and c or false
  end
  if not _ui_canvas then return draw_all() end
  love.graphics.push("all")
  love.graphics.setCanvas(_ui_canvas)
  love.graphics.clear(0.03, 0.03, 0.05, 1)
  love.graphics.origin()
  draw_all()
  love.graphics.pop()
  local sc = math.min(ww / KitK.W, wh / KitK.H)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(_ui_canvas, math.floor((ww - KitK.W * sc) / 2),
                     math.floor((wh - KitK.H * sc) / 2), 0, sc, sc)
end

-- ── Input debug logger ─────────────────────────────────────
local _State = (function()
    local ok, m = pcall(require, "core.state")
    return ok and m or nil
end)()

local _ilog_ready = false
local function _ilog(kind, a, b)
    local _env = os.getenv("DOLPHINUI_DEBUG_INPUT") == "1"
    local _setting = false
    pcall(function()
        local S = require("core.settings")
        _setting = S.get("debug_input") == true
    end)
    if not _env and not _setting then return end
    if not _ilog_ready then
        os.execute("mkdir -p data/logs 2>/dev/null")
        _ilog_ready = true
    end
    local path = "data/logs/input_debug.log"
    local sz = 0
    local chk = io.open(path, "r")
    if chk then chk:seek("end"); sz = chk:seek(); chk:close() end
    if sz > 500 * 1024 then os.remove(path) end
    local f = io.open(path, "a")
    if not f then return end
    f:write(os.date("%F %T"), " ", kind,
            " a=", tostring(a), "[", type(a), "]",
            " b=", tostring(b), "[", type(b), "]",
            " screen=", tostring(_State and _State.screen),
            " raw=", tostring(_State and _State.raw_input), "\n")
    f:close()
end

-- ── Keyboard ──────────────────────────────────────────────
-- ── Input dedup (2026-10-17) ──────────────────────────────
-- SDL2/gamepad riconosce il controller → LÖVE emette SIA joystick SIA
-- gamepad per lo stesso evento fisico. Senza dedup: D-pad salta 2,
-- A/B/X/Y doppi. Fix: skip joystick se isGamepad; dedup direzione D-pad.
local _dd_last = {}
local function _dd_time()
    if love and love.timer then return love.timer.getTime() end
    return os.time()
end
local function _dd_dir(dir)
    if not dir then return true end
    local now = _dd_time(); local prev = _dd_last[dir]
    if prev and (now - prev) < 0.05 then return false end
    _dd_last[dir] = now; return true
end
local function _is_gamepad(j)
    if not j then return false end
    local ok,v = pcall(function() return j:isGamepad() end)
    return ok and v == true
end
local _DPAD_G2L = {dpup="UP",dpdown="DOWN",dpleft="LEFT",dpright="RIGHT"}
local _HAT_G2L  = {u="UP",d="DOWN",l="LEFT",r="RIGHT",
                   lu="UP",ru="UP",ld="DOWN",rd="DOWN"}

function love.keypressed(k, sc)
    _touch()
    _ilog("key", k, sc)
    if UI and UI.key then UI.key(sc or k) end
end
function love.keyreleased(k, sc)
    if UI and UI.key_released then UI.key_released(sc or k) end
end

-- ── Joystick (raw SDL button indices) ─────────────────────
function love.joystickpressed(j, b)
    _touch()
    _ilog("joy", j, b)
    if _is_gamepad(j) then return end
    if UI and UI.pad then UI.pad(b) end
end
function love.joystickreleased(j, b)
    if _is_gamepad(j) then return end
    if UI and UI.pad_released then UI.pad_released(b) end
end
function love.joystickhat(j, h, d)
    _touch()
    _ilog("hat", h, d)
    if d == "c" or d == "" then return end
    local _d = _HAT_G2L[d]
    if _d and not _dd_dir(_d) then return end
    if UI and UI.hat then UI.hat(d) end
end

-- ── Gamepad (SDL GameController string names) ─────────────
function love.gamepadpressed(j, b)
    _touch()
    _ilog("gp", j, b)
    local _d = _DPAD_G2L[b]
    if _d and not _dd_dir(_d) then return end
    if UI and UI.gamepad then UI.gamepad(b) end
end
function love.gamepadreleased(j, b)
    if UI and UI.gamepad_released then UI.gamepad_released(b) end
end

-- ── Gamepad analog triggers (L2/R2 fire as axes on muOS) ──
local _trig_state = { lt = false, rt = false }
function love.gamepadaxis(j, axis, value)
    if math.abs(value) > 0.5 then _touch() end
    if axis == "triggerleft" or axis == "lefttrigger" then
        local pressed = value > 0.5
        if pressed ~= _trig_state.lt then
            _trig_state.lt = pressed
            _ilog("gpaxis", axis, value)
            if pressed then
                if UI and UI.gamepad then UI.gamepad("lefttrigger") end
            else
                if UI and UI.gamepad_released then UI.gamepad_released("lefttrigger") end
            end
        end
    elseif axis == "triggerright" or axis == "righttrigger" then
        local pressed = value > 0.5
        if pressed ~= _trig_state.rt then
            _trig_state.rt = pressed
            _ilog("gpaxis", axis, value)
            if pressed then
                if UI and UI.gamepad then UI.gamepad("righttrigger") end
            else
                if UI and UI.gamepad_released then UI.gamepad_released("righttrigger") end
            end
        end
    end
end

function love.quit()                 Core.shutdown()    end
