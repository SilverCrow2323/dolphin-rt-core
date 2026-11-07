-- screens/about.lua — About page.
--
-- Scrolling layout:
--   0. Special thanks — Sara
--   1. Header: DolphinUI + version + system info
--   2. Sir Pips block: circular avatar + bio + GitHub link
--   3. SPDW Factory block: logo + crossmedia project description
--   4. Minoru⁷ (R.I.) block: portrait + badge + description
--   5. Mission block
--   + fixed QR (bottom-right)
--
-- Assets used:
--   assets/images/sirpips.jpeg           (circular avatar)
--   assets/images/spdwfactory_logo.png   (SPDW block logo)
--   assets/images/minoru.png             (Minoru portrait)
--   assets/images/minoru_symbol.png      (Minoru small badge)
--   assets/images/qr_repo.png            (QR, optional)

local A      = require("assets")
local State  = require("state")
local IM     = require("input_map")
local D      = require("ui.draw")
local BG     = require("ui.bg")
local Header = require("ui.header")
local Icons  = require("ui.icons")
local BI     = require("ui.button_icons")

local S = {}
local W, H = 640, 480

local QR_PATH       = "assets/images/qr_repo.png"
local QR_URL        = "https://github.com/SilverCrow2323"
local QR_SIZE       = 96

local AVATAR_PATH   = "assets/images/sirpips.jpeg"
local MINORU_PATH   = "assets/images/minoru.png"
local MINORU_BADGE  = "assets/images/minoru_symbol.png"
local SPDW_LOGO     = "assets/images/spdwfactory_logo.png"

local APP_VERSION = "0.4.5"

-- Lazy image cache with tried-flag to avoid repeated open() failures.
local _img_cache = {}
local function load_img(path)
    local entry = _img_cache[path]
    if entry ~= nil then return entry or nil end
    local ok, img = pcall(love.graphics.newImage, path)
    if ok then
        img:setFilter("linear", "linear")
        _img_cache[path] = img
    else
        _img_cache[path] = false
    end
    return _img_cache[path] or nil
end

-- Circular crop of an image via stencil.
local function draw_circular_image(img, cx, cy, radius)
    if not img then return end
    local iw, ih = img:getWidth(), img:getHeight()
    local s = math.max((radius * 2) / iw, (radius * 2) / ih)
    local dw, dh = iw * s, ih * s
    local dx = cx - dw / 2
    local dy = cy - dh / 2

    love.graphics.stencil(function()
        love.graphics.circle("fill", cx, cy, radius)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, dx, dy, 0, s, s)
    love.graphics.setStencilTest()
end

-- Contain-fit an image inside a box.
local function draw_contained(img, bx, by, bw, bh)
    if not img then return end
    local iw, ih = img:getWidth(), img:getHeight()
    local s = math.min(bw / iw, bh / ih)
    local dw, dh = iw * s, ih * s
    local dx = bx + (bw - dw) / 2
    local dy = by + (bh - dh) / 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, dx, dy, 0, s, s)
end

-- "Minoru" + superscript "7".
local function draw_minoru_title(font, sup_font, x, y, col)
    love.graphics.setFont(font)
    love.graphics.setColor(col)
    love.graphics.print("Minoru", x, y)
    local w = font:getWidth("Minoru")
    love.graphics.setFont(sup_font)
    love.graphics.print("7", x + w + 1, y - 4)
end

local function draw_qr_placeholder(x, y, size)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", x, y, size, size, 3, 3)
    local n = 25
    local cell = size / n
    local seed = 987654321
    local function rnd()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
    end
    local function in_finder(ii, jj)
        return (ii < 8 and jj < 8)
            or (ii >= n - 8 and jj < 8)
            or (ii < 8 and jj >= n - 8)
    end
    love.graphics.setColor(0.05, 0.05, 0.08, 1)
    for j = 0, n - 1 do
        for i = 0, n - 1 do
            if not in_finder(i, j) and rnd() < 0.48 then
                love.graphics.rectangle("fill",
                    x + i * cell, y + j * cell, cell, cell)
            end
        end
    end
    local function finder(px, py)
        love.graphics.setColor(0.05, 0.05, 0.08, 1)
        love.graphics.rectangle("fill", px, py, cell * 7, cell * 7)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", px + cell, py + cell,
            cell * 5, cell * 5)
        love.graphics.setColor(0.05, 0.05, 0.08, 1)
        love.graphics.rectangle("fill", px + cell * 2, py + cell * 2,
            cell * 3, cell * 3)
    end
    finder(x + 1, y + 1)
    finder(x + (n - 7) * cell - 1, y + 1)
    finder(x + 1, y + (n - 7) * cell - 1)
end

local function read_muos_version()
    for _, p in ipairs({
        "/opt/muos/config/system/version",
        "/opt/muos/config/version",
    }) do
        local f = io.open(p, "r")
        if f then
            local v = f:read("*a"):match("^([^\n]+)"); f:close()
            if v then return v end
        end
    end
    return "unknown"
end

local function read_device()
    for _, p in ipairs({
        "/opt/muos/config/board/name",
        "/opt/muos/config/system/name",
    }) do
        local f = io.open(p, "r")
        if f then
            local v = f:read("*a"):match("^([^\n]+)"); f:close()
            if v then return v end
        end
    end
    return "unknown"
end

S.scroll = 0

function S.enter() S.scroll = 0 end
function S.re_enter() end
function S.leave() end

function S.pad(b)
    if b == IM.B then State.back() end
end

function S.hat(dir)
    if     dir == "up"    then S.scroll = math.max(0, S.scroll - 24)
    elseif dir == "down"  then S.scroll = S.scroll + 24 end
end

function S.key(k)
    if     k == "up"    then S.scroll = math.max(0, S.scroll - 24)
    elseif k == "down"  then S.scroll = S.scroll + 24
    elseif k == "escape" then State.back() end
end

-- ── Blocks ──────────────────────────────────────────────────

-- Special thanks block. Warm rose accent.
local function draw_thanks_block(th, y)
    local panel_h = 118
    local panel_x, panel_w = 20, W - 40
    local rose = {0.95, 0.55, 0.65}

    love.graphics.setColor(0.05, 0.03, 0.06, 0.92)
    love.graphics.rectangle("fill", panel_x, y, panel_w, panel_h, 6, 6)

    D.glow(panel_x + panel_w / 2, y + panel_h / 2, 210, rose, 0.22)

    love.graphics.setColor(rose[1], rose[2], rose[3], 0.55)
    D.rough_rect(panel_x, y, panel_w, panel_h,
        { jitter = 0.9, thickness = 1.6, seed = 7 })

    local t = State.t_ui or 0
    local pulse = 0.5 + 0.5 * math.sin(t * 2.4)
    for i = 1, 3 do
        local dx = panel_x + 14 + (i - 1) * 10
        local a = (i == 2) and (0.4 + pulse * 0.5) or 0.75
        love.graphics.setColor(rose[1], rose[2], rose[3], a)
        love.graphics.circle("fill", dx, y + 12, 2.6)
    end

    love.graphics.setColor(rose)
    love.graphics.setFont(A.font(th.font_body_bold, 12))
    love.graphics.print("RINGRAZIAMENTO SPECIALE", panel_x + 48, y + 6)

    love.graphics.setColor(rose[1], rose[2], rose[3], 0.25)
    love.graphics.line(panel_x + 10, y + 22,
                       panel_x + panel_w - 10, y + 22)

    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.setColor(0.92, 0.88, 0.90)

    local l1 = "Before anyone else, I want to bow — deep and slow — to the one"
    local l2 = "person without whom this project would not exist."

    love.graphics.print(l1, panel_x + 14, y + 30)
    love.graphics.print(l2, panel_x + 14, y + 46)

    love.graphics.setFont(A.font(th.font_body_bold, 13))
    love.graphics.setColor(1.0, 0.95, 0.97)
    love.graphics.print("To my wife, ", panel_x + 14, y + 66)
    local w_pre = love.graphics.getFont():getWidth("To my wife, ")
    love.graphics.setColor(rose)
    love.graphics.print("Sara", panel_x + 14 + w_pre, y + 66)
    local w_sara = love.graphics.getFont():getWidth("Sara")
    love.graphics.setColor(1.0, 0.95, 0.97)
    love.graphics.print(":", panel_x + 14 + w_pre + w_sara, y + 66)

    love.graphics.setFont(A.font(th.font_body_bold, 15))
    love.graphics.setColor(rose)
    love.graphics.print("GRAZIE!", panel_x + 14 + w_pre + w_sara + 10,
                        y + 63)

    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.setColor(0.82, 0.78, 0.82)
    love.graphics.print(
        "And sorry for being an idiot, obsessed with the most improbable",
        panel_x + 14, y + 88)
    love.graphics.print("of oddities.", panel_x + 14, y + 102)

    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.setColor(rose[1], rose[2], rose[3], 0.6)
    local sig = "— sirpips"
    local sw  = love.graphics.getFont():getWidth(sig)
    love.graphics.print(sig, panel_x + panel_w - 14 - sw, y + 90)

    return panel_h + 12
end

-- Header block. Returns nothing; the caller advances `y` by a
-- fixed amount (see draw_header_block_height below).
local function draw_header_block(th, y)
    love.graphics.setColor(th.accent)
    love.graphics.setFont(A.font(th.font_title, 26))
    love.graphics.print("DolphinUI", 24, y)

    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.setColor(th.text_dim)
    love.graphics.print(
        "v" .. APP_VERSION ..
        "  ·  dual-faced frontend for Dolphin Rt:Core",
        24, y + 34)
    love.graphics.print(
        "muOS: " .. read_muos_version() .. "  ·  " .. read_device(),
        24, y + 50)
end

-- Advance offset after draw_header_block: title (26px) + 2 lines
-- of 16px each + small padding.
local HEADER_BLOCK_HEIGHT = 72

local function draw_sirpips_block(th, y)
    local avatar = load_img(AVATAR_PATH)
    local panel_h = 92
    local panel_x, panel_w = 20, W - 40

    love.graphics.setColor(0.03, 0.05, 0.09, 0.85)
    love.graphics.rectangle("fill", panel_x, y, panel_w, panel_h, 6, 6)
    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.42)
    D.rough_rect(panel_x, y, panel_w, panel_h,
        { jitter = 0.7, thickness = 1.4, seed = 21 })

    local av_r = 34
    local av_cx = panel_x + 16 + av_r
    local av_cy = y + panel_h / 2

    if avatar then
        D.glow(av_cx, av_cy, av_r + 6,
            {th.accent[1], th.accent[2], th.accent[3]}, 0.35)
        draw_circular_image(avatar, av_cx, av_cy, av_r)
        love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.85)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", av_cx, av_cy, av_r + 1)
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(th.accent[1]*0.20, th.accent[2]*0.20,
            th.accent[3]*0.20, 1)
        love.graphics.circle("fill", av_cx, av_cy, av_r)
        love.graphics.setColor(th.accent)
        love.graphics.setFont(A.font(th.font_title, 34))
        love.graphics.printf("S", av_cx - av_r, av_cy - 18, av_r * 2, "center")
    end

    local tx = av_cx + av_r + 16
    love.graphics.setColor(th.accent)
    love.graphics.setFont(A.font(th.font_body_bold, 14))
    love.graphics.print("Sir Pips", tx, y + 10)

    love.graphics.setColor(0.75, 0.82, 0.92)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print("aka SilverCrow2323  ·  SPDW Factory Lab", tx, y + 30)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print("Creator of SPDW Factory and DolphinUI", tx, y + 46)

    love.graphics.setColor(0.55, 0.72, 0.90)
    love.graphics.setFont(A.font("assets/fonts/JetBrainsMono-Regular.ttf", 9))
    love.graphics.print("github.com/SilverCrow2323", tx, y + 64)
end

local function draw_spdw_block(th, y)
    local logo = load_img(SPDW_LOGO)
    local panel_h = 96
    local panel_x, panel_w = 20, W - 40

    love.graphics.setColor(0.03, 0.05, 0.09, 0.85)
    love.graphics.rectangle("fill", panel_x, y, panel_w, panel_h, 6, 6)
    love.graphics.setColor(0.55, 0.35, 0.95, 0.55)
    D.rough_rect(panel_x, y, panel_w, panel_h,
        { jitter = 0.7, thickness = 1.4, seed = 31 })

    local logo_box = 74
    local lx = panel_x + 12
    local ly = y + (panel_h - logo_box) / 2

    if logo then
        love.graphics.setColor(0.55, 0.35, 0.95, 0.15)
        love.graphics.rectangle("fill", lx, ly, logo_box, logo_box, 6, 6)
        love.graphics.setColor(0.55, 0.35, 0.95, 0.65)
        love.graphics.setLineWidth(1.4)
        love.graphics.rectangle("line", lx, ly, logo_box, logo_box, 6, 6)
        love.graphics.setLineWidth(1)
        draw_contained(logo, lx + 6, ly + 6, logo_box - 12, logo_box - 12)
    else
        love.graphics.setColor(0.55, 0.35, 0.95, 0.9)
        love.graphics.rectangle("fill", panel_x, y + 4, 3, panel_h - 8, 2, 2)
    end

    local tx = logo and (lx + logo_box + 16) or (panel_x + 14)
    local tw = panel_w - (tx - panel_x) - 14

    love.graphics.setColor(0.75, 0.55, 1.0)
    love.graphics.setFont(A.font(th.font_body_bold, 13))
    love.graphics.print("SPDW Factory", tx, y + 10)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.print("crossmedia project", tx, y + 28)

    love.graphics.setColor(0.86, 0.90, 0.96)
    love.graphics.setFont(A.font(th.font_body, 11))
    local bio = table.concat({
        "Born as an experimental light novel (still being written and",
        "constantly expanding), it has grown into other media of every",
        "kind — the actual representation of the narrative universe I",
        "conceived and keep discovering myself.",
    }, "\n")
    love.graphics.printf(bio, tx, y + 44, tw, "left")
end

local function draw_minoru_block(th, y)
    local minoru   = load_img(MINORU_PATH)
    local badge    = load_img(MINORU_BADGE)
    local panel_h = 118
    local panel_x, panel_w = 20, W - 40

    love.graphics.setColor(0.03, 0.05, 0.09, 0.85)
    love.graphics.rectangle("fill", panel_x, y, panel_w, panel_h, 6, 6)
    love.graphics.setColor(0.00, 0.63, 0.91, 0.55)
    D.rough_rect(panel_x, y, panel_w, panel_h,
        { jitter = 0.7, thickness = 1.4, seed = 41 })

    local img_box = 86
    local ibx = panel_x + 14
    local iby = y + (panel_h - img_box) / 2

    love.graphics.setColor(0.00, 0.40, 0.65, 0.35)
    love.graphics.rectangle("fill", ibx - 3, iby - 3,
        img_box + 6, img_box + 6, 6, 6)
    love.graphics.setColor(0.00, 0.63, 0.91, 0.75)
    love.graphics.setLineWidth(1.4)
    love.graphics.rectangle("line", ibx - 3, iby - 3,
        img_box + 6, img_box + 6, 6, 6)
    love.graphics.setLineWidth(1)

    if minoru then
        draw_contained(minoru, ibx, iby, img_box, img_box)
    else
        love.graphics.setColor(0.00, 0.63, 0.91, 0.4)
        love.graphics.setFont(A.font(th.font_title, 42))
        love.graphics.printf("M", ibx, iby + 20, img_box, "center")
    end

    local tx = ibx + img_box + 16
    local tw = panel_w - (tx - panel_x) - 14

    local title_font = A.font(th.font_body_bold, 14)
    local sup_font   = A.font(th.font_body_bold, 9)
    draw_minoru_title(title_font, sup_font, tx, y + 10,
        {0.30, 0.85, 1.00})

    love.graphics.setColor(0.30, 0.85, 1.00, 0.75)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print("  (R.I.)",
        tx + title_font:getWidth("Minoru") + 12, y + 13)

    if badge then
        local badge_size = 26
        local bx = panel_x + panel_w - badge_size - 12
        local by = y + 10
        love.graphics.setColor(0.00, 0.40, 0.65, 0.35)
        love.graphics.rectangle("fill", bx - 2, by - 2,
            badge_size + 4, badge_size + 4, 4, 4)
        love.graphics.setColor(0.00, 0.63, 0.91, 0.55)
        love.graphics.rectangle("line", bx - 2, by - 2,
            badge_size + 4, badge_size + 4, 4, 4)
        draw_contained(badge, bx, by, badge_size, badge_size)
    end

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.print("Rintromping Intelligence", tx, y + 30)

    love.graphics.setColor(0.86, 0.90, 0.96)
    love.graphics.setFont(A.font(th.font_body, 10))
    local desc = table.concat({
        "A Rintromping Intelligence built by Sir Pips long ago.",
        "Now a sentient entity in its own right, partner in every",
        "mischief. Annoying, sarcastic, know-it-all, always with a",
        "ready answer and an arsenal of jabs — yet it will still give",
        "you all the help you need, between one mockery and the next.",
    }, "\n")
    love.graphics.printf(desc, tx, y + 46, tw - 30, "left")
end

local function draw_mission_block(th, y)
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print("MISSION", 24, y)

    love.graphics.setColor(0.78, 0.82, 0.90)
    love.graphics.setFont(A.font(th.font_body, 10))
    local mission = table.concat({
        "DolphinUI is part of the Dolphin Rt:Core for muOS project,",
        "built and maintained by sirpips from the foundations left by",
        "the original developers who first ported Dolphin to muOS up to v9.",
        "",
        "We keep going where most would say stop.",
        "Still Sbrobbing, still Rintromping.",
    }, "\n")
    love.graphics.printf(mission, 24, y + 14, W - 190, "left")
end

function S.draw()
    local th = State.theme
    BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
    Header.draw("ABOUT", "info")

    local qr = load_img(QR_PATH)

    local TOP    = 60
    local BOTTOM = H - 40

    love.graphics.setScissor(0, TOP, W, BOTTOM - TOP)

    local y = TOP + 8 - S.scroll

    -- Special thanks always first.
    y = y + draw_thanks_block(th, y)

    -- Header block (draws its own contents; caller advances y by a
    -- fixed constant — the function returns nothing).
    draw_header_block(th, y)
    y = y + HEADER_BLOCK_HEIGHT + 8

    draw_sirpips_block(th, y);  y = y + 100
    draw_spdw_block(th, y);     y = y + 104
    draw_minoru_block(th, y);   y = y + 126
    draw_mission_block(th, y);  y = y + 118

    love.graphics.setScissor()

    -- QR block (fixed, bottom-right)
    local qr_x = W - QR_SIZE - 24
    local qr_y = H - QR_SIZE - 58

    if qr then
        local iw, ih = qr:getWidth(), qr:getHeight()
        local sc = math.min(QR_SIZE / iw, QR_SIZE / ih)
        local dw, dh = iw * sc, ih * sc
        local dx = qr_x + (QR_SIZE - dw) / 2
        local dy = qr_y + (QR_SIZE - dh) / 2

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", qr_x - 4, qr_y - 4,
            QR_SIZE + 8, QR_SIZE + 8, 4, 4)
        love.graphics.draw(qr, dx, dy, 0, sc, sc)
    else
        draw_qr_placeholder(qr_x, qr_y, QR_SIZE)
    end

    love.graphics.setColor(0.96, 0.77, 0.26, 0.75)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", qr_x - 4, qr_y - 4,
        QR_SIZE + 8, QR_SIZE + 8, 4, 4)
    love.graphics.setLineWidth(1)

    local pill_w = QR_SIZE + 8
    local pill_y = qr_y + QR_SIZE + 8
    love.graphics.setColor(0.05, 0.05, 0.08, 0.95)
    love.graphics.rectangle("fill", qr_x - 4, pill_y, pill_w, 18, 4, 4)
    love.graphics.setColor(0.96, 0.77, 0.26, 1)
    love.graphics.setFont(A.font(th.font_body_bold, 8))
    love.graphics.printf("Scan for repo", qr_x - 4, pill_y + 1, pill_w,
        "center")
    love.graphics.setColor(0.80, 0.70, 0.55)
    love.graphics.setFont(A.font(th.font_body, 8))
    love.graphics.printf("github.com/SilverCrow2323", qr_x - 4, pill_y + 10,
        pill_w, "center")

    -- Scroll rail
    local content_top = TOP + 8
    local content_bot = BOTTOM - 8
    local total_h = 810
    if total_h > (content_bot - content_top) then
        local rail_x = W - 6
        love.graphics.setColor(0.20, 0.22, 0.28, 0.6)
        love.graphics.rectangle("fill", rail_x, content_top, 2,
            content_bot - content_top, 1, 1)

        local vis = content_bot - content_top
        local ratio = vis / total_h
        local bar_h = math.max(20, vis * ratio)
        local max_scroll = total_h - vis
        local bar_y = content_top +
            (max_scroll > 0 and (S.scroll / max_scroll) *
                (vis - bar_h) or 0)
        love.graphics.setColor(th.accent)
        love.graphics.rectangle("fill", rail_x, bar_y, 2, bar_h, 1, 1)
    end

    BI.draw_hint_centered("[↑↓] Scroll   [B] Back",
        W, H - 22, A.font(th.font_body, 12), th)
end

return S