function love.conf(t)
    t.identity = "DolphinRtCorePortUI"
    t.version = "11.5"
    t.console = false
    t.window.title = "Dolphin Rt:UI"
    t.window.width = 640
    t.window.height = 480
    t.window.fullscreen = true
    t.window.vsync = 1
    t.window.resizable = false
    t.window.msaa = 0
    t.modules.physics = false
    t.modules.video = false
    t.modules.joystick = true
    t.modules.touch = false
end
