function love.conf(t)
    t.identity = "dolphinstream"
    t.window.title = "Dolphin Stream"
    t.window.width = 640
    t.window.height = 480
    t.window.vsync = 1
    -- set DOLPHINSTREAM_WINDOWED=1 to test on a PC
    t.window.fullscreen = (os.getenv("DOLPHINSTREAM_WINDOWED") == nil)
    t.window.fullscreentype = "desktop"
    t.modules.physics = false
    t.modules.video = false
    t.modules.thread = false
end
