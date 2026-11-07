-- boot.lua — sprite-based boot animation (12x10 grid, 120 frames).
-- Overlay: "Dolphin Rt:Stream" logo with electric flicker.
-- Falls back to the classic cube animation if dolphin_scene.png is missing.
local ui = require("ui")
local lg = love.graphics

local M = { dur = 3.8 }
local W, H = 640, 480
local canvas

-- ===== SPRITE SHEET CONFIG =====
local SPRITE_FILE   = "dolphin_scene.png"
local SPRITE_COLS   = 12             -- columns
local SPRITE_ROWS   = 10             -- rows
local SPRITE_FPS    = 32             -- frames per second
local SPRITE_SCALE  = 1.0
local SPRITE_Y       = 225            -- centro verticale
local SPRITE_MAX_DIM = 620           -- if larger, auto-scale
local SPRITE_FLASH_AT = 0.55         -- fraction of M.dur for the flash

-- ===== LOGO CONFIG =====
local LOGO_FILE     = "mock_rt_logo.png"
local LOGO_Y        = 95
local LOGO_MAX_W    = 380
local LOGO_FLICKER_T = 3.5           -- end of flicker phase (seconds)
-- ================================

local sprite, sprite_frames, sprite_w, sprite_h
local sprite_quads = {}
local sprite_scale_final = SPRITE_SCALE
local logo_w, logo_h, logo_scale = 0, 0, 1

function M.init()
    local ok, cv = pcall(lg.newCanvas, W, H)
    canvas = (ok and cv) or false

    sprite = ui.img(SPRITE_FILE)
    if sprite then
        local iw, ih = sprite:getDimensions()
        sprite_w = math.floor(iw / SPRITE_COLS)
        sprite_h = math.floor(ih / SPRITE_ROWS)
        sprite_frames = SPRITE_COLS * SPRITE_ROWS

        local md = math.max(sprite_w, sprite_h)
        if md * SPRITE_SCALE > SPRITE_MAX_DIM then
            sprite_scale_final = SPRITE_MAX_DIM / md
        end

        sprite_quads = {}
        for i = 0, sprite_frames - 1 do
            local c = i % SPRITE_COLS
            local r = math.floor(i / SPRITE_COLS)
            sprite_quads[i] = lg.newQuad(c * sprite_w, r * sprite_h,
                sprite_w, sprite_h, iw, ih)
        end

        local msg = string.format("[boot] sprite %s: %dx%d, %dx%d grid = %d frames, %dx%d each, %.0f fps",
            SPRITE_FILE, iw, ih, SPRITE_COLS, SPRITE_ROWS, sprite_frames,
            sprite_w, sprite_h, SPRITE_FPS)
        print(msg)
    else
        sprite_frames = 0
        print("[boot] " .. SPRITE_FILE .. " missing, using classic fallback")
    end

    local logo = ui.img(LOGO_FILE)
    if logo then
        logo_w, logo_h = logo:getDimensions()
        logo_scale = math.min(1, LOGO_MAX_W / logo_w)
        print(string.format("[boot] logo %s: %dx%d, scale=%.2f", LOGO_FILE, logo_w, logo_h, logo_scale))
    else
        print("[boot] " .. LOGO_FILE .. " missing, will use logo.png fallback")
    end
end

local function ph(t, a, b) return ui.clamp((t - a) / (b - a), 0, 1) end

-- ===== CLASSIC FALLBACK =====
local function scene_classic(bt)
    local th = ui.th
    local acc = th.gc
    ui.bg(bt, true)
    local cx, cy = W / 2, 200
    local fin = 1 - ph(bt, 0, 0.45)
    local glow = ph(bt, 0.2, 1.0) * (1 - ph(bt, 1.6, 2.2))
    for i = 1, 5 do
        lg.setColor(acc[1], acc[2], acc[3], 0.07 * glow)
        lg.circle("fill", cx, cy, 40 + i * 26 + math.sin(bt * 4 + i) * 4)
    end
    local grow = ui.outBack(ph(bt, 0.25, 1.0))
    local shrink = 1 - ui.inCubic(ph(bt, 1.5, 1.85))
    local s = 74 * grow * shrink
    if s > 1 then ui.cube3d(cx, cy, s, bt * 2.6, 0.55, acc, 1) end
    local flash = math.max(0, 1 - math.abs(bt - 1.84) / 0.2)
    if flash > 0 then
        lg.setColor(1, 1, 1, 0.85 * flash)
        lg.rectangle("fill", 0, 0, W, H)
    end
    local lp = ph(bt, 1.85, 2.6)
    local logo = ui.img("logo.png")
    if logo and lp > 0 then
        local y = ui.lerp(-130, 118, ui.outBounce(lp))
        local sc = 150 / logo:getWidth()
        lg.setColor(1, 1, 1, math.min(1, lp * 4))
        lg.draw(logo, cx, y, 0, sc, sc, logo:getWidth() / 2, logo:getHeight() / 2)
    end
    if fin > 0 then lg.setColor(0, 0, 0, fin); lg.rectangle("fill", 0, 0, W, H) end
end

-- ===== SPRITE SCENE =====
local function scene_sprite(bt)
    local th = ui.th
    local acc = th.gc
    ui.bg(bt, true)

    -- glow dietro
    local glow = ph(bt, 0.1, 0.6) * (1 - ph(bt, M.dur - 0.4, M.dur))
    for i = 1, 4 do
        lg.setColor(acc[1], acc[2], acc[3], 0.055 * glow)
        lg.circle("fill", W / 2, SPRITE_Y, 90 + i * 35 + math.sin(bt * 3 + i) * 5)
    end

    -- flash sincronizzato
    local flash_t = M.dur * SPRITE_FLASH_AT
    local d = math.abs(bt - flash_t)
    local flash = d < 0.18 and (1 - d / 0.18) or 0

    -- sprite frame corrente
    if sprite and sprite_frames > 0 then
        local idx = math.min(sprite_frames - 1, math.max(0, math.floor(bt * SPRITE_FPS)))
        local q = sprite_quads[idx]
        if q then
            local fade_in = math.min(1, bt / 0.3)
            lg.setColor(1, 1, 1, fade_in)
            lg.draw(sprite, q, W / 2, SPRITE_Y, 0,
                sprite_scale_final, sprite_scale_final,
                sprite_w / 2, sprite_h / 2)
        end
    end

    -- flash bianco
    if flash > 0 then
        lg.setColor(1, 1, 1, 0.82 * flash)
        lg.rectangle("fill", 0, 0, W, H)
    end

    -- LOGO "Dolphin Rt:Stream" con effetto elettrico (flicker)
    local mock_logo = ui.img(LOGO_FILE)
    local lp = ph(bt, 1.5, 2.0)
    if mock_logo and lp > 0 then
        local flicker = 1
        if bt < LOGO_FLICKER_T then
            -- simulazione scarica elettrica: alterna 100% / 40%
            flicker = (math.sin(bt * 50) > 0.5) and 1 or 0.4
        end
        local drop = (1 - ui.outBounce(lp)) * -60
        local lx = W / 2
        local ly = LOGO_Y + drop
        -- shadow
        lg.setColor(0, 0, 0, 0.35 * lp * flicker)
        lg.draw(mock_logo, lx + 2, ly + 2, 0, logo_scale, logo_scale, logo_w / 2, logo_h / 2)
        -- logo
        lg.setColor(1, 1, 1, lp * flicker)
        lg.draw(mock_logo, lx, ly, 0, logo_scale, logo_scale, logo_w / 2, logo_h / 2)
    end

    -- hint

    -- bottom text
    local txt_a = ph(bt, 2.0, 2.5)
    if txt_a > 0 then
        ui.textf("Dolphin Rt:Core for muOS", 0, 420, W, "center", ui.fonts.om, th.text, txt_a)
        ui.textf("Project", 0, 445, W, "center", ui.fonts.s, th.dim, txt_a)
    end

    -- fade-out
    local fo = ph(bt, M.dur - 0.45, M.dur)
    if fo > 0 then
        lg.setColor(0, 0, 0, fo)
        lg.rectangle("fill", 0, 0, W, H)
    end
end

local function scene(bt)
    if sprite and sprite_frames > 1 then
        scene_sprite(bt)
    else
        scene_classic(bt)
    end
end

function M.render(bt)
    if not canvas then return end
    lg.push("all")
    lg.setCanvas(canvas)
    lg.origin()
    lg.clear(0, 0, 0, 1)
    scene(bt)
    lg.setCanvas()
    lg.pop()
end

function M.blit(bt, ga)
    if canvas then
        lg.setColor(1, 1, 1, ga)
        lg.draw(canvas)
    else
        scene(bt)
    end
end

return M
