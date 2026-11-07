-- ui/mascot.lua — the cyber-dolphin scene (120 frames, 12x10 sheet).
-- The handheld never moves inside the frame, so the scene can be drawn at any
-- scale without jitter. Loaded lazily (13 MB of VRAM) and only when a screen
-- asks for it; release() frees it again.
--
-- Key frames: lightning starts ~62, hits the screen 76-82, loop closes at 119.
local M = {}
M.COLS, M.ROWS, M.FRAMES, M.FPS = 12, 10, 120, 24
M.FW, M.FH = 158, 173
M.HIT = 78                                  -- frame where the screen flashes purple
local PATH = "assets/images/boot/dolphin_scene.png"
local img, quads

function M.load()
    if img then return true end
    if not love.filesystem.getInfo(PATH) then return false end
    local ok, i = pcall(love.graphics.newImage, PATH)
    if not ok then return false end
    i:setFilter("linear", "linear")
    img, quads = i, {}
    for n = 0, M.FRAMES - 1 do
        local c, r = n % M.COLS, math.floor(n / M.COLS)
        quads[n + 1] = love.graphics.newQuad(c * M.FW, r * M.FH, M.FW, M.FH, i:getDimensions())
    end
    return true
end
function M.loaded() return img ~= nil end
function M.release() img, quads = nil, nil end

-- frame index (0-based) for a time in seconds, looping
function M.frame_at(t, speed)
    return math.floor(t * M.FPS * (speed or 1)) % M.FRAMES
end

-- draws frame n centred horizontally on cx with its top at y
function M.draw(n, cx, y, scale, alpha)
    if not img then return end
    scale = scale or 1
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(img, quads[(n % M.FRAMES) + 1], cx - M.FW * scale / 2, y, 0, scale, scale)
end

return M
