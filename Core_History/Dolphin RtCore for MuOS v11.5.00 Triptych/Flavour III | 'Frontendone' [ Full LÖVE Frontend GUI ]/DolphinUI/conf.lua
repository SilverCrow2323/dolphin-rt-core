-- Dolphin Rt:UI — conf.lua
-- La risoluzione arriva da mux_launch.sh come argomento "WxH" (pannello del
-- dispositivo), oppure da DOLPHINUI_RES. La UI e' logica 640x480 e main.lua la
-- scala con bande nere se la finestra e' diversa (vedi love.draw).
local function wanted_size()
  local function parse(s)
    local w, h = tostring(s or ""):match("^(%d+)x(%d+)$")
    w, h = tonumber(w), tonumber(h)
    if w and h and w >= 320 and h >= 240 and w <= 3840 and h <= 2160 then return w, h end
  end
  local w, h = parse(os.getenv("DOLPHINUI_RES"))
  if w then return w, h end
  if type(arg) == "table" then
    for k, v in pairs(arg) do
      w, h = parse(v)
      if w then return w, h end
    end
  end
  return 640, 480
end

function love.conf(t)
  t.identity          = "DolphinRtFinalCut"
  t.version           = "11.5"
  t.console           = false

  local w, h = wanted_size()
  t.window.title      = "Dolphin Rt:FinalCut"
  t.window.width      = w
  t.window.height     = h
  t.window.fullscreen = false
  t.window.vsync      = 0
  t.window.msaa       = 0
  t.window.resizable  = false
  t.window.highdpi    = false

  t.modules.joystick  = true
  t.modules.physics   = false
  t.modules.touch     = false
  t.modules.video     = false
end
