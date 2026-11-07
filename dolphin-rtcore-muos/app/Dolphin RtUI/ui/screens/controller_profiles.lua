local K = require("ui.kit")
local SFX = require("ui.sfx")

local S = {}
S.system = "GameCube"
S.list = K.List(K.MARGIN, 92, K.W - K.MARGIN * 2 - 234, K.BOT - 92, 46)
S.sprite = nil
S._img_cache = {}
S.t = 0

local SHEETS = {
    GameCube = "assets/images/3d_assets/gcpad_spritesheet_256.png",
    Wii      = "assets/images/3d_assets/wiimote_spritesheet_256.png",
}

local function cache_img(path)
    if not path then return nil end
    if S._img_cache[path] ~= nil then return S._img_cache[path] or nil end
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then img:setFilter("linear","linear"); S._img_cache[path] = img; return img end
    S._img_cache[path] = false
    return nil
end

local function load_sheet(path)
    local img = cache_img(path)
    if not img then return nil end
    local W, H = img:getDimensions()
    local m = path:match("_(%d+)%.png$")
    local frame = tonumber(m) or 128
    local cols = math.max(1, math.floor(W/frame))
    local rows_n = math.max(1, math.floor(H/frame))
    if cols*frame ~= W then cols = 1 end
    if rows_n*frame ~= H then rows_n = 1 end
    local quads, n = {}, 0
    for r = 0, rows_n-1 do
        for c = 0, cols-1 do
            n = n + 1
            quads[n] = love.graphics.newQuad(c*frame, r*frame, frame, frame, W, H)
        end
    end
    return { img = img, quads = quads, count = n, size = frame }
end

local function scan()
    local base = "workshop/controller/" .. S.system
    local rows = {}
    local h = io.popen("ls -1d " .. base .. "/*/ 2>/dev/null")
    if h then
        for line in h:lines() do
            local name = line:match("([^/]+)/?$")
            if name then rows[#rows+1] = { name = name, dir = base .. "/" .. name } end
        end
        h:close()
    end
    table.sort(rows, function(a,b) return a.name:lower() < b.name:lower() end)
    S.list:set(rows, false)
    S.sprite = load_sheet(SHEETS[S.system])
end

function S.enter()
    S.system = "GameCube"; S.t = 0
    S.list = K.List(K.MARGIN, 92, K.W - K.MARGIN * 2 - 234, K.BOT - 92, 46)
    S._img_cache = {}
    scan()
    K.set_accent("gc")
end
function S.update(dt) S.t = S.t + dt; S.list:update(dt) end

function S.pad(b)
    local row = S.list:cur()
    if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "L1" or b == "R1" then
        S.system = (S.system == "GameCube") and "Wii" or "GameCube"
        scan()
        K.set_accent(S.system == "Wii" and "wii" or "gc")
        SFX.play("menu_pagescroll")
    elseif b == "A" and row then
        require("ui").go("controller_map", { dir = row.dir, name = row.name, system = S.system })
    elseif b == "B" then require("ui").back() end
end

local function draw_row(row, x, y, w, h, focused)
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    if K.draw_tool_icon then
        K.draw_tool_icon("gamepad", x + 26, y + h/2, 20, focused and K.acc or K.C.dim, focused and 1 or 0.7)
    end
    K.text("body", row.name, x + 46, y + h/2 - 11, focused and K.C.text or K.C.dim)
    if focused then
        K.text("small", "(A) KEY MAP", x + w - K.width("small", "(A) KEY MAP") - 14,
               y + h/2 - 9, K.acc)
    end
end

function S.draw()
    K.bg()
    K.header("Controller Key Map", S.system .. " profiles", nil, { icon = "gamepad" })
    if #S.list.items == 0 then
        K.text("body", "No profiles in workshop/controller/" .. S.system,
               0, 240, K.C.dim, 1, K.W, "center")
    else
        S.list:draw(draw_row)
    end
    -- right preview
    local px = K.W - K.MARGIN - 220
    local py = 92
    local pw = 220
    local ph = K.BOT - py
    K.panel(px, py, pw, ph, { cut = 8 })
    local acc = K.acc or K.ACC.gc
    for i = 8, 1, -1 do
        K.color(acc, 0.03)
        love.graphics.circle("fill", px + pw/2, py + ph/2, (ph/2 - 10) * i/8)
    end
    if S.sprite then
        local frame = math.floor(S.t * 14) % S.sprite.count
        local size = math.min(pw - 20, ph - 80)
        local sc = size / S.sprite.size
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(S.sprite.img, S.sprite.quads[frame+1],
            px + pw/2 - S.sprite.size*sc/2,
            py + ph/2 - S.sprite.size*sc/2 - 20, 0, sc, sc)
    end
    local row = S.list:cur()
    if row then
        K.text("key", S.system, px, py + ph - 44, acc, 1, pw, "center")
        K.text("h", K.clip("h", row.name, pw - 12), px, py + ph - 28, K.C.text, 1, pw, "center")
    end
    K.footer({
        { key = "A", label = "Key Map" },
        { key = "L1 R1", label = "System" },
        { key = "B", label = "Back" },
    })
end

return S
