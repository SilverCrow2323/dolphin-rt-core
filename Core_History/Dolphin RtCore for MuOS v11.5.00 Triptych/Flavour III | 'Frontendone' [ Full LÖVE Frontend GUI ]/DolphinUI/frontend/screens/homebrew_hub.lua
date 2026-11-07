-- screens/homebrew_hub.lua — Homebrew Hub landing splash.
--
-- v0.5.1 — visual redesign
--   * The ENTER button is now a large beveled 3D button with a
--     gradient, a specular highlight, and a strong "press" state.
--   * The three "popular apps" banners have per-app colored rails
--     and icon chips; empty slots render a subtle "no app" strip.
--   * GC System and Wii System launch buttons have distinct colors,
--     a big icon, a BIOS/NAND status LED, and a sub-status line.
--   * advanced.homebrew_hub_splash (default true) still disables the
--     whole screen and forwards to homebrew.

local A     = require("assets")
local SFX   = require("sfx")
local State = require("state")
local IM    = require("input_map")
local D     = require("ui.draw")
local BG    = require("ui.bg")
local Icons = require("ui.icons")
local BI    = require("ui.button_icons")
local Modal = require("modal")
local Launcher = require("launcher")

local S = {}
local W, H = 640, 480

-- Layout
local PANEL      = { x = 20,  y = 40,  w = 600, h = 400 }
local ENTER_BTN  = { x = 42,  y = 200, w = 300, h = 130 }
local BANNER_W   = 232
local BANNER_H   = 40
local BANNER_GAP = 6
local BANNERS_X  = PANEL.x + PANEL.w - 20 - BANNER_W
local GC_BTN     = { x = 42,  y = 344, w = 260, h = 76 }
local WII_BTN    = { x = 320, y = 344, w = 260, h = 76 }

S.focus = "enter"
S.enter_press = 0
S.side_apps = {}
S.icon_cache = {}
S.has_gc_bios = false
S.has_wii_nand = false
S._pending_transition = 0

local function shq(s)
    if s == nil then return "''" end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function read_meta_text(text)
    local meta, section = {}, nil
    for line in text:gmatch("[^\n]+") do
        local s = line:match("^%s*%[([^%]]+)%]")
        if s then
            section = s
        elseif section == "Info" or section == "homebrew" then
            local k, v = line:match("^%s*([^=]+)%s*=%s*(.*)$")
            if k then
                meta[k:match("^%s*(.-)%s*$")] = v:match("^%s*(.-)%s*$")
            end
        end
    end
    return meta
end

local function fs_exists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

local function is_dir(path)
    local h = io.popen('timeout 1 [ -d ' .. shq(path) ..
                       ' ] && echo 1 2>/dev/null')
    if not h then return false end
    local r = h:read("*a"); h:close()
    return r:match("1") ~= nil
end

local function scan_popular_apps()
    S.side_apps = {}
    S.icon_cache = {}

    local p = io.popen('timeout 2 ls -1 ' .. shq("hb") .. ' 2>/dev/null')
    if not p then
        print("[homebrew_hub] hb/ not accessible")
        return
    end

    local dirs = {}
    for name in p:lines() do
        if name ~= "" and name:sub(1, 1) ~= "." then
            local dir = "hb/" .. name
            if is_dir(dir) then
                table.insert(dirs, name)
            end
        end
    end
    p:close()

    for _, dir_name in ipairs(dirs) do
        local meta_path = "hb/" .. dir_name .. "/rtcore_hb.ini"
        local c = nil
        local f = io.open(meta_path, "r")
        if f then c = f:read("*a"); f:close() end

        local meta = {}
        if c then meta = read_meta_text(c) end

        local icon_name = meta.icon or "icon.png"
        local icon_rel  = "hb/" .. dir_name .. "/" .. icon_name
        if fs_exists(icon_rel) then
            table.insert(S.side_apps, {
                dir       = dir_name,
                name      = meta.name or dir_name,
                icon_path = icon_rel,
            })
        end
        if #S.side_apps >= 3 then break end
    end
end

local function check_gc_bios()
    for _, p in ipairs({
        "dolphin-emu/GC/USA/IPL.bin",
        "dolphin-emu/GC/EUR/IPL.bin",
        "dolphin-emu/GC/JAP/IPL.bin",
    }) do
        if fs_exists(p) then return true end
    end
    return false
end

local function check_wii_nand()
    return is_dir("dolphin-emu/Wii/title/00000001/00000002")
end

function S.enter()
    local Store = require("settings_store")
    if Store.get("advanced", "homebrew_hub_splash") == false then
        print("[homebrew_hub] skipped")
        State.raw_input = false
        State.go("homebrew")
        return
    end

    S.focus = "enter"
    S.enter_press = 0
    S._pending_transition = 0
    scan_popular_apps()
    S.has_gc_bios  = check_gc_bios()
    S.has_wii_nand = check_wii_nand()
end

function S.leave()
    State.raw_input = false
end

function S.re_enter()
    scan_popular_apps()
    S.has_gc_bios  = check_gc_bios()
    S.has_wii_nand = check_wii_nand()
end

local ORDER = { "enter", "gc", "wii" }

local function move(dir)
    local idx = 1
    for i, k in ipairs(ORDER) do if k == S.focus then idx = i break end end
    local ni = ((idx - 1 + dir) % #ORDER) + 1
    if ni ~= idx then
        S.focus = ORDER[ni]
        SFX.play("menu_move")
    end
end

local function press_enter()
    S.enter_press = 1.0
    SFX.play("menu_select")
    S._pending_transition = 0.28
end

local function launch_gc()
    if not S.has_gc_bios then
        Modal.show("GameCube BIOS missing",
            "To boot the GameCube System Menu you need a valid IPL.bin.\n\n" ..
            "Place it in one of these paths:\n" ..
            "  dolphin-emu/GC/USA/IPL.bin\n" ..
            "  dolphin-emu/GC/EUR/IPL.bin\n" ..
            "  dolphin-emu/GC/JAP/IPL.bin\n\n" ..
            "Then try again.")
        return
    end
    SFX.play("gamecube_startup")
    Launcher.launch({ title = "GameCube Console", sys = "GC",
                     virtual = "gc" })
end

local function launch_wii()
    if not S.has_wii_nand then
        Modal.show("Wii NAND missing",
            "To boot the Wii System Menu you need a NAND dump.\n\n" ..
            "Expected path:\n" ..
            "  dolphin-emu/Wii/title/00000001/00000002/\n\n" ..
            "Import a NAND through Dolphin, or copy a\n" ..
            "compatible dump into the folder above.\n\n" ..
            "Then try again.")
        return
    end
    SFX.play("gamecube_startup")
    Launcher.launch({ title = "Wii System Menu", sys = "Wii",
                     virtual = "wii" })
end

local function activate_focused()
    if     S.focus == "enter" then press_enter()
    elseif S.focus == "gc"    then launch_gc()
    elseif S.focus == "wii"   then launch_wii() end
end

function S.update(dt)
    if S.enter_press > 0 then
        S.enter_press = math.max(0, S.enter_press - dt * 4)
    end
    if S._pending_transition > 0 then
        S._pending_transition = S._pending_transition - dt
        if S._pending_transition <= 0 then
            S._pending_transition = 0
            State.go("homebrew")
        end
    end
end

function S.pad(b) if b == IM.A then activate_focused() end end

function S.hat(dir)
    if     dir == "left"  then move(-1)
    elseif dir == "right" then move(1)
    elseif dir == "up"    then move(-1)
    elseif dir == "down"  then move(1) end
end

function S.key(k)
    if     k == "left"  or k == "up"    then move(-1)
    elseif k == "right" or k == "down"  then move(1)
    elseif k == "return" or k == "space" then activate_focused() end
end

local function get_icon(app)
    if not app or not app.icon_path then return nil end
    local cached = S.icon_cache[app.dir]
    if cached ~= nil then return cached or nil end
    local ok, img = pcall(love.graphics.newImage, app.icon_path)
    if ok then
        img:setFilter("linear", "linear")
        S.icon_cache[app.dir] = img
        return img
    end
    S.icon_cache[app.dir] = false
    return nil
end

-- ── Rendering ───────────────────────────────────────────────

-- Huge 3D "ENTER" button. Face + top bevel + bottom shadow + specular.
local function draw_enter_button(th)
    local btn = ENTER_BTN
    local focused = (S.focus == "enter")
    local pressed = (S.enter_press > 0.3)
    local c = {0.20, 0.72, 0.98}
    local depth = pressed and 4 or 8
    local y_off = pressed and depth or 0

    local x, y, w, h = btn.x, btn.y, btn.w, btn.h

    -- Bottom shadow slab
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x + 4, y + h + 4, w, 4, 3, 3)

    -- Depth slab (colored dark)
    love.graphics.setColor(c[1]*0.25, c[2]*0.25, c[3]*0.25, 1)
    love.graphics.rectangle("fill", x, y + depth, w, h, 6, 6)

    -- Face
    local fy = y + y_off
    love.graphics.setColor(c[1]*0.65, c[2]*0.65, c[3]*0.65, 1)
    love.graphics.rectangle("fill", x, fy, w, h, 6, 6)

    -- Top gradient highlight
    love.graphics.setColor(c[1], c[2], c[3], 0.95)
    love.graphics.rectangle("fill", x, fy, w, h * 0.55, 6, 6)

    -- Specular sweep
    love.graphics.setColor(1, 1, 1, 0.14)
    love.graphics.rectangle("fill", x + 8, fy + 8, w - 16, 8, 4, 4)

    -- Border
    if focused then
        local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 4)
        D.glow(x + w/2, fy + h/2, w * 0.75, c, 0.55 + pulse * 0.35)

        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 1, fy - 1, w + 2, h + 2, 7, 7)
        love.graphics.setLineWidth(1)
        D.corner_brackets(x - 6, fy - 6, w + 12, h + 12, c, 22)
    else
        love.graphics.setColor(c[1], c[2], c[3], 0.65)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", x, fy, w, h, 6, 6)
        love.graphics.setLineWidth(1)
    end

    -- Icon
    Icons.draw("play", x + 22, fy + 30, 60, {1, 1, 1})

    -- Label
    love.graphics.setColor({1, 1, 1})
    love.graphics.setFont(A.font(th.font_title, 30))
    love.graphics.print("ENTER", x + 100, fy + 24)

    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print("Open the Homebrew Grid", x + 100, fy + 66)

    -- Bottom strip inside button
    love.graphics.setColor(0, 0, 0, 0.30)
    love.graphics.rectangle("fill", x + 16, fy + h - 26, w - 32, 16, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.90)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.printf("[A] PRESS TO ENTER", x + 16, fy + h - 23, w - 32,
        "center")
end

-- Small banner with a colored left rail and an icon chip.
local function draw_banner(app, x, y, w, h)
    local th = State.theme
    local c = {0.30, 0.80, 0.60}

    -- Card
    love.graphics.setColor(0.05, 0.06, 0.10, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(c[1]*0.20, c[2]*0.20, c[3]*0.20, 1)
    love.graphics.rectangle("fill", x, y, w, 14, 4, 4)

    -- Left rail
    love.graphics.setColor(c[1], c[2], c[3], 0.95)
    love.graphics.rectangle("fill", x, y, 4, h)

    -- Border
    love.graphics.setColor(c[1], c[2], c[3], 0.60)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)

    -- Icon chip
    local chip_s = h - 10
    local chip_x = x + 8
    local chip_y = y + (h - chip_s) / 2
    love.graphics.setColor(c[1]*0.20, c[2]*0.20, c[3]*0.20, 1)
    love.graphics.rectangle("fill", chip_x, chip_y, chip_s, chip_s, 3, 3)
    love.graphics.setColor(c[1], c[2], c[3], 0.55)
    love.graphics.rectangle("line", chip_x, chip_y, chip_s, chip_s, 3, 3)

    local img = get_icon(app)
    if img then
        local iw, ih = img:getDimensions()
        local sc = math.min((chip_s - 4) / iw, (chip_s - 4) / ih)
        local dw, dh = iw * sc, ih * sc
        love.graphics.setColor(1, 1, 1, 0.98)
        love.graphics.draw(img,
            chip_x + (chip_s - dw)/2,
            chip_y + (chip_s - dh)/2,
            0, sc, sc)
    else
        Icons.draw("homebrew", chip_x + 4, chip_y + 4,
            chip_s - 8, c)
    end

    -- Name
    local text_x = chip_x + chip_s + 8
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.setColor(0.92, 0.96, 1.0)
    local name = app.name
    if #name > 20 then name = name:sub(1, 18) .. "…" end
    love.graphics.print(name, text_x, y + 6)

    love.graphics.setFont(A.font(th.font_body, 9))
    love.graphics.setColor(c[1], c[2], c[3], 0.75)
    love.graphics.print("quick app", text_x, y + h - 15)
end

local function draw_empty_banner(x, y, w, h, idx)
    love.graphics.setColor(0.08, 0.10, 0.14, 0.65)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(0.28, 0.30, 0.36, 0.6)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    love.graphics.setColor(0.40, 0.45, 0.55)
    love.graphics.setFont(A.font("assets/fonts/Oxanium-Regular.ttf", 9))
    love.graphics.printf("(slot " .. idx .. ")", x, y + h/2 - 6, w, "center")
end

-- Big "system launch" button for GC / Wii.
local function draw_system_button(th, btn, focused, color, icon_key,
                                   label, sublabel, ok)
    local x, y, w, h = btn.x, btn.y, btn.w, btn.h
    local depth = 6
    local c = color

    if focused then
        local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 4)
        D.glow(x + w/2, y + h/2, w * 0.6, c, 0.55 + pulse * 0.35)
    end

    -- Shadow slab
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x + 3, y + h + 2, w, 3, 3, 3)

    -- Body
    love.graphics.setColor(c[1]*0.30, c[2]*0.30, c[3]*0.30, 1)
    love.graphics.rectangle("fill", x, y, w, h, 5, 5)

    -- Top highlight
    love.graphics.setColor(c[1]*0.75, c[2]*0.75, c[3]*0.75, 1)
    love.graphics.rectangle("fill", x, y, w, h * 0.55, 5, 5)

    -- Border
    if focused then
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.setLineWidth(2.6)
    else
        love.graphics.setColor(c[1], c[2], c[3], 0.70)
        love.graphics.setLineWidth(1.5)
    end
    love.graphics.rectangle("line", x, y, w, h, 5, 5)
    love.graphics.setLineWidth(1)

    -- Icon chip on left
    local chip_s = h - 20
    local chip_x = x + 12
    local chip_y = y + 10
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", chip_x, chip_y, chip_s, chip_s, 4, 4)
    Icons.draw(icon_key, chip_x + 6, chip_y + 6, chip_s - 12, {1, 1, 1})

    -- Label + status
    local text_x = chip_x + chip_s + 12
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(A.font(th.font_body_bold, 15))
    love.graphics.print(label, text_x, y + 12)

    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(sublabel, text_x, y + 34)

    -- Status LED
    local led_x = x + w - 16
    local led_y = y + 14
    local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 5)
    local led_col = ok and {0.30, 0.85, 0.40} or {0.90, 0.30, 0.30}
    love.graphics.setColor(led_col[1], led_col[2], led_col[3],
        0.35 + pulse * 0.35)
    love.graphics.circle("fill", led_x, led_y, 6)
    love.graphics.setColor(led_col[1], led_col[2], led_col[3], 1)
    love.graphics.circle("fill", led_x, led_y, 3)

    -- Status text (small, right)
    love.graphics.setColor(led_col[1], led_col[2], led_col[3], 0.90)
    love.graphics.setFont(A.font(th.font_body_bold, 9))
    local status = ok and "READY" or "MISSING"
    local sw = love.graphics.getFont():getWidth(status)
    love.graphics.print(status, led_x - sw, led_y + 12)
end

function S.draw()
    local th = State.theme
    local c  = {0.20, 0.72, 0.98}

    BG.draw_hexgrid(W, H, love.timer.getDelta(), c)

    -- Panel
    local p = PANEL
    love.graphics.setColor(0.06, 0.08, 0.13, 0.98)
    love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, 8, 8)
    D.glow(p.x + p.w/2, p.y + p.h/2, 220, c, 0.30)
    love.graphics.setColor(c)
    D.rough_rect(p.x, p.y, p.w, p.h,
        { jitter = 1.5, thickness = 3, seed = 17 })
    D.corner_brackets(p.x, p.y, p.w, p.h, c, 22)

    -- Header inside panel
    love.graphics.setColor(c[1]*0.15, c[2]*0.15, c[3]*0.15, 1)
    love.graphics.rectangle("fill", p.x, p.y, p.w, 44, 8, 8)
    love.graphics.setColor(c[1], c[2], c[3], 0.55)
    love.graphics.rectangle("fill", p.x, p.y + 43, p.w, 1)

    A.drawImage(th.boot_icon, p.x + 14, p.y + 6, 32, 32)
    love.graphics.setColor(c)
    love.graphics.setFont(A.font(th.font_title, 20))
    love.graphics.print("HOMEBREW HUB", p.x + 56, p.y + 8)

    love.graphics.setColor(0.60, 0.80, 0.98, 0.95)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print(
        ("// %d quick apps   ·   hb/"):format(#S.side_apps),
        p.x + 58, p.y + 28)

    -- Popular apps header
    love.graphics.setColor(0.60, 0.80, 0.98, 0.90)
    love.graphics.setFont(A.font(th.font_body_bold, 10))
    love.graphics.print("> POPULAR APPS", BANNERS_X, ENTER_BTN.y - 16)

    -- Popular apps banners
    for i = 1, 3 do
        local app = S.side_apps[i]
        local by = ENTER_BTN.y + (i - 1) * (BANNER_H + BANNER_GAP)
        if app then
            draw_banner(app, BANNERS_X, by, BANNER_W, BANNER_H)
        else
            draw_empty_banner(BANNERS_X, by, BANNER_W, BANNER_H, i)
        end
    end

    -- ENTER
    draw_enter_button(th)

    -- GC / Wii
    draw_system_button(th, GC_BTN,  S.focus == "gc",
        {0.55, 0.35, 0.95}, "library",
        "LAUNCH", "GameCube System", S.has_gc_bios)
    draw_system_button(th, WII_BTN, S.focus == "wii",
        {0.20, 0.63, 0.91}, "library",
        "LAUNCH", "Wii System", S.has_wii_nand)

    BI.draw_footer(th, {
        { key = "dpad", label = "Navigate" },
        { key = "a",    label = "Confirm"  },
        { key = "b",    label = "Back"     },
    }, W, H - 22, A.font(th.font_body, 12))

    Modal.draw()
end

return S