-- ui/screens/controller_map.lua — controller mapping editor
local K      = require("ui.kit")
local SFX    = require("ui.sfx")
local Notify = require("ui.notify")
local Ini    = require("core.ini_edit")

local S = {}
S.system = "GameCube"
S.dir = nil
S.name = nil
S.rows = {}
S.sel = 1
S.scroll = 0
S.t = 0
S.remap = nil
S.sprite = nil
S._img_cache = {}

local SYS_CFG = {
    GameCube = { fname = "GCPadNew.ini", section = "GCPad1",
                 icon_dir = "assets/images/gc_buttons/",
                 sheet = "assets/images/3d_assets/gcpad_spritesheet_256.png",
                 color = "gc" },
    Wii = { fname = "WiimoteNew.ini", section = "Wiimote1",
            icon_dir = "assets/images/wii_buttons/",
            sheet = "assets/images/3d_assets/wiimote_spritesheet_256.png",
            color = "wii" },
}

local GC_BTN = {
    ["Buttons/A"]="A.png", ["Buttons/B"]="B.png", ["Buttons/X"]="X.png",
    ["Buttons/Y"]="Y.png", ["Buttons/Z"]="GCPad-Z.png",
    ["Buttons/Start"]="Start-Pause.png",
    ["Triggers/L"]="L.png", ["Triggers/L-Analog"]="l1_gamecube.png",
    ["Triggers/R"]="R.png", ["Triggers/R-Analog"]="r1_gamecube.png",
    ["Main Stick/Up"]="Control_Stick.png", ["Main Stick/Down"]="Control_Stick.png",
    ["Main Stick/Left"]="Control_Stick.png", ["Main Stick/Right"]="Control_Stick.png",
    ["C-Stick/Up"]="C-Stick.png", ["C-Stick/Down"]="C-Stick.png",
    ["C-Stick/Left"]="C-Stick.png", ["C-Stick/Right"]="C-Stick.png",
    ["D-Pad/Up"]="D-Pad.png", ["D-Pad/Down"]="D-Pad.png",
    ["D-Pad/Left"]="D-Pad.png", ["D-Pad/Right"]="D-Pad.png",
}
local WII_BTN = {
    ["Buttons/A"]="A.png", ["Buttons/B"]="B.png",
    ["Buttons/1"]="1.png", ["Buttons/2"]="2.png",
    ["Buttons/+"]="+.png", ["Buttons/-"]="-.png",
    ["Buttons/Home"]="home.png",
    ["D-Pad/Up"]="D-Pad_Up.png", ["D-Pad/Down"]="D-Pad_Down.png",
    ["D-Pad/Left"]="D-Pad.png", ["D-Pad/Right"]="D-Pad.png",
    ["Nunchuk/Stick/Up"]="NunchcukControlStick.png", ["Nunchuk/Stick/Down"]="NunchcukControlStick.png",
    ["Nunchuk/Stick/Left"]="NunchcukControlStick.png", ["Nunchuk/Stick/Right"]="NunchcukControlStick.png",
    ["Nunchuk/Buttons/C"]="NunchukCButton.png", ["Nunchuk/Buttons/Z"]="NunchuckZButton.png",
    ["IR/Up"]="Wiimote_Aim.png", ["IR/Down"]="Wiimote_Aim.png",
    ["IR/Left"]="Wiimote_Aim.png", ["IR/Right"]="Wiimote_Aim.png",
    ["Tilt/Left"]="Wiimote.png", ["Tilt/Right"]="Wiimote.png",
    ["Tilt/Forward"]="Wiimote.png", ["Tilt/Backward"]="Wiimote.png",
}
local NATIVE_LBL = {
    GameCube = {
        ["Buttons/A"]="A", ["Buttons/B"]="B", ["Buttons/X"]="X", ["Buttons/Y"]="Y",
        ["Buttons/Z"]="Z", ["Buttons/Start"]="START",
        ["Triggers/L"]="L", ["Triggers/L-Analog"]="L-AN",
        ["Triggers/R"]="R", ["Triggers/R-Analog"]="R-AN",
        ["Main Stick/Up"]="STK UP", ["Main Stick/Down"]="STK DN",
        ["Main Stick/Left"]="STK LT", ["Main Stick/Right"]="STK RT",
        ["C-Stick/Up"]="C UP", ["C-Stick/Down"]="C DN",
        ["C-Stick/Left"]="C LT", ["C-Stick/Right"]="C RT",
        ["D-Pad/Up"]="D-UP", ["D-Pad/Down"]="D-DN",
        ["D-Pad/Left"]="D-LT", ["D-Pad/Right"]="D-RT",
    },
    Wii = {
        ["Buttons/A"]="A", ["Buttons/B"]="B",
        ["Buttons/1"]="1", ["Buttons/2"]="2",
        ["Buttons/+"]="+", ["Buttons/-"]="-",
        ["Buttons/Home"]="HOME",
        ["D-Pad/Up"]="D-UP", ["D-Pad/Down"]="D-DN",
        ["D-Pad/Left"]="D-LT", ["D-Pad/Right"]="D-RT",
        ["Nunchuk/Stick/Up"]="N-UP", ["Nunchuk/Stick/Down"]="N-DN",
        ["Nunchuk/Stick/Left"]="N-LT", ["Nunchuk/Stick/Right"]="N-RT",
        ["Nunchuk/Buttons/C"]="N-C", ["Nunchuk/Buttons/Z"]="N-Z",
        ["IR/Up"]="IR-UP", ["IR/Down"]="IR-DN",
        ["IR/Left"]="IR-LT", ["IR/Right"]="IR-RT",
        ["Tilt/Left"]="T-LT", ["Tilt/Right"]="T-RT",
        ["Tilt/Forward"]="T-FW", ["Tilt/Backward"]="T-BK",
    },
}
local MUOS_COLORS = {
    a={0.35,0.90,0.45}, b={0.95,0.38,0.38}, x={0.38,0.66,1.00}, y={1.00,0.80,0.28},
    l1={0.60,0.60,0.65}, r1={0.60,0.60,0.65}, l2={0.55,0.55,0.60}, r2={0.55,0.55,0.60},
    select={0.55,0.55,0.60}, start={0.55,0.55,0.60}, menu={0.80,0.60,0.95},
}
local MUOS_LBL = {
    a="A", b="B", x="X", y="Y",
    l1="L1", r1="R1", l2="L2", r2="R2",
    select="SEL", start="STA", menu="MEN",
}
local RAW_TO_MUOS = {
    [0]="b", [1]="a", [2]="x", [3]="y",
    [4]="l1", [5]="r1", [6]="select", [7]="start",
    [8]="menu", [9]="l2", [12]="r2",
}
local STR_TO_RAW = {
    a=1, b=0, x=2, y=3, back=6, start=7, guide=8,
    leftshoulder=4, rightshoulder=5, lefttrigger=9, righttrigger=12,
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
    local cols = math.max(1, math.floor(W / frame))
    local rows_n = math.max(1, math.floor(H / frame))
    if cols * frame ~= W then cols = 1 end
    if rows_n * frame ~= H then rows_n = 1 end
    local quads, n = {}, 0
    for r = 0, rows_n - 1 do
        for c = 0, cols - 1 do
            n = n + 1
            quads[n] = love.graphics.newQuad(c*frame, r*frame, frame, frame, W, H)
        end
    end
    return { img = img, quads = quads, count = n, size = frame }
end

local function strip_bt(s) return (tostring(s or ""):gsub("`","")) end
local function muos_from_value(v)
    local n = tonumber(tostring(v or ""):match("Button%s+(%d+)"))
    if n then return RAW_TO_MUOS[n] end
end
local function icon_for(key)
    local map = (S.system == "GameCube") and GC_BTN or WII_BTN
    local file = map[key]
    if not file then return nil end
    return SYS_CFG[S.system].icon_dir .. file
end
local function native_label(key)
    local map = NATIVE_LBL[S.system] or {}
    return map[key] or (key:gsub("^Buttons/",""):gsub("^Triggers/",""):gsub("/"," "))
end

function S.reload()
    S.rows = {}
    if not S.dir then return end
    local cfg = SYS_CFG[S.system]
    local path = S.dir .. "/" .. cfg.fname
    local lines = Ini.read_lines(path)
    if #lines == 0 then return end
    local cur_sec, data, order = nil, {}, {}
    for _, line in ipairs(lines) do
        local sec = line:match("^%s*%[([^%]]+)%]")
        if sec then cur_sec = sec
        elseif cur_sec == cfg.section then
            local k, v = line:match("^%s*([^=]+)%s*=%s*(.*)$")
            if k then
                k = k:gsub("%s+$",""); v = v:gsub("^%s+","")
                if not data[k] then order[#order+1] = k end
                data[k] = v
            end
        end
    end
    for _, k in ipairs(order) do
        local skip = false
        if k == "Device" or k:match("^Options/") or k:match("Dead Zone") or k:match("Calibration")
           or k:match("Sensitivity") or k == "Extension" or k == "Source" then skip = true end
        if not skip and data[k] and data[k] ~= "" then
            S.rows[#S.rows+1] = { key = k, value = data[k] }
        end
    end
    S.sel = math.max(1, math.min(#S.rows, S.sel))
end

function S.enter(params)
    params = params or {}
    S.system = (params.system == "Wii") and "Wii" or "GameCube"
    S.dir = params.dir
    S.name = params.name or "Default"
    S.t = 0; S.sel = 1; S.scroll = 0; S.remap = nil
    S._img_cache = {}
    S.sprite = load_sheet(SYS_CFG[S.system].sheet)
    K.set_accent(SYS_CFG[S.system].color)
    S.reload()
end

function S.update(dt)
    S.t = S.t + dt
    if S.remap then
        S.remap.t = S.remap.t + dt
        if S.remap.phase == "wait" and S.remap.t >= S.remap.timeout then
            S.remap = nil; SFX.play("menu_back")
        end
    end
end

function S.raw_pad(b)
    if not S.remap or S.remap.phase ~= "wait" or S.remap.captured then return false end
    local raw
    if type(b) == "number" then raw = b
    elseif type(b) == "string" then raw = STR_TO_RAW[b:lower()] end
    if raw then
        S.remap.captured = raw
        S.remap.new_value = "`Button " .. raw .. "`"
        for _, r in ipairs(S.rows) do
            if r ~= S.remap.row and strip_bt(r.value) == strip_bt(S.remap.new_value) then
                S.remap.duplicate = r
            end
        end
        S.remap.phase = "confirm"
        S.remap.t = 0
        SFX.play("menu_toggleoption")
        return true
    end
    return false
end

local function save_and_reload()
    local cfg = SYS_CFG[S.system]
    local path = S.dir .. "/" .. cfg.fname
    local lines = Ini.read_lines(path)
    for _, r in ipairs(S.rows) do
        Ini.set(lines, cfg.section, r.key, r.value)
    end
    Ini.write_lines(path, lines)
end

function S.pad(b)
    if S.remap then
        if S.remap.phase == "confirm" then
            if b == "A" then
                local row = S.remap.row
                row.value = S.remap.new_value
                save_and_reload()
                S.remap = nil
                SFX.play("newupdate")
                Notify.show("success", "Remapped: " .. native_label(row.key))
            elseif b == "B" then
                S.remap = nil; SFX.play("menu_back")
            end
        elseif S.remap.phase == "wait" and b == "B" then
            S.remap = nil; SFX.play("menu_back")
        end
        return
    end
    local row = S.rows[S.sel]
    if b == "UP" then
        if S.sel > 1 then S.sel = S.sel - 1; SFX.play("menu_move") end
    elseif b == "DOWN" then
        if S.sel < #S.rows then S.sel = S.sel + 1; SFX.play("menu_move") end
    elseif b == "A" and row then
        S.remap = { row = row, phase = "wait", t = 0, timeout = 5.0 }
        SFX.play("menu_select")
    elseif b == "B" then
        require("ui").back()
    end
end

local function draw_hero_sprite(cx, cy, size)
    if not S.sprite then
        local img = cache_img("assets/images/"..(S.system=="Wii" and "WiiMote-front.png" or "GCPad-front.png"))
        if img then
            local iw, ih = img:getDimensions()
            local sc = math.min(size/iw, size/ih)
            love.graphics.setColor(1,1,1,1)
            love.graphics.draw(img, cx - iw*sc/2, cy - ih*sc/2, 0, sc, sc)
        end
        return
    end
    local frame = math.floor(S.t * 14) % S.sprite.count
    local sc = size / S.sprite.size
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(S.sprite.img, S.sprite.quads[frame+1],
        cx - S.sprite.size*sc/2, cy - S.sprite.size*sc/2, 0, sc, sc)
end

local function draw_native_btn(key, cx, cy, size)
    local img = cache_img(icon_for(key))
    if img then
        local iw, ih = img:getDimensions()
        local sc = math.min(size/iw, size/ih)
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(img, cx-iw*sc/2, cy-ih*sc/2, 0, sc, sc)
        return
    end
    local lbl = native_label(key)
    K.text("small", lbl, cx - K.width("small", lbl)/2, cy - 8, K.C.text)
end

local function draw_muos_badge(key, cx, cy, size)
    if not key then
        K.text("small","?", cx-4, cy-8, K.C.dim); return
    end
    local col = MUOS_COLORS[key] or {0.6,0.6,0.65}
    local lbl = MUOS_LBL[key] or key:upper()
    if key == "a" or key == "b" or key == "x" or key == "y" then
        K.color(col, 0.22); love.graphics.circle("fill", cx, cy, size/2)
        K.color(col, 1); love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", cx, cy, size/2)
        love.graphics.setLineWidth(1)
        K.text("key", lbl, cx - K.width("key", lbl)/2, cy - 8, K.C.text)
    else
        local tw = K.width("key", lbl) + 10
        local h = size * 0.72
        K.color(col, 0.22); love.graphics.rectangle("fill", cx-tw/2, cy-h/2, tw, h, 5, 5)
        K.color(col, 1); love.graphics.setLineWidth(1.2)
        love.graphics.rectangle("line", cx-tw/2, cy-h/2, tw, h, 5, 5)
        love.graphics.setLineWidth(1)
        K.text("key", lbl, cx - K.width("key", lbl)/2, cy - 8, K.C.text)
    end
end

function S.draw()
    K.bg()
    K.header("Key Map", S.name .. "  ·  " .. S.system, nil, { icon = "gamepad" })
    local acc = K.acc or K.ACC.gc
    -- left panel
    local lx, ly = K.MARGIN, 92
    local lw, lh = 220, K.BOT - ly
    K.panel(lx, ly, lw, lh, { cut = 8 })
    for i = 8, 1, -1 do
        K.color(acc, 0.03)
        love.graphics.circle("fill", lx + lw/2, ly + lh/2, (lh/2 - 10) * i/8)
    end
    draw_hero_sprite(lx + lw/2, ly + lh/2, math.min(lw, lh) - 30)
    K.text("key", S.system, lx + 10, ly + lh - 42, acc)
    K.text("small", K.clip("small", S.name, lw - 20), lx + 10, ly + lh - 24, K.C.text)

    -- right list
    local rx = lx + lw + 12
    local rw = K.W - rx - K.MARGIN
    local ry = 92
    local rh = K.BOT - ry
    K.panel(rx, ry, rw, rh, { cut = 8 })
    K.text("key", "NATIVE", rx + 16, ry + 8, K.C.faint)
    K.text("key", "MUOS", rx + rw - 180, ry + 8, K.C.faint)
    K.color(K.C.line, 0.5)
    love.graphics.rectangle("fill", rx + 8, ry + 24, rw - 16, 1)

    local row_h = 38
    local vis_top = ry + 30
    local vis_h = rh - 36
    local vis_n = math.floor(vis_h / row_h)
    if S.sel < S.scroll + 1 then S.scroll = S.sel - 1 end
    if S.sel > S.scroll + vis_n then S.scroll = S.sel - vis_n end
    S.scroll = math.max(0, math.min(math.max(0, #S.rows - vis_n), S.scroll))

    love.graphics.setScissor(rx, vis_top, rw, vis_h)
    for i = 1, #S.rows do
        local r = S.rows[i]
        local yy = vis_top - S.scroll*row_h + (i-1)*row_h
        if yy >= vis_top - row_h and yy < vis_top + vis_h then
            local focused = (i == S.sel)
            if focused then
                K.color(acc, 0.18)
                love.graphics.rectangle("fill", rx+6, yy+2, rw-12, row_h-4, 5, 5)
                K.color(acc, 1)
                love.graphics.rectangle("fill", rx+6, yy+2, 3, row_h-4)
            end
            draw_native_btn(r.key, rx+26, yy+row_h/2, 22)
            K.text("body", K.clip("body", native_label(r.key), 140),
                rx+46, yy+row_h/2-10, focused and K.C.text or K.C.dim)
            local mx = rx + rw - 170
            local muos = muos_from_value(r.value)
            draw_muos_badge(muos, mx+14, yy+row_h/2, 20)
            local n = r.value:match("Button%s+(%d+)")
            local txt = n and ("Button "..n) or r.value
            K.text("small", txt, mx+34, yy+row_h/2-8, focused and acc or K.C.dim)
        end
    end
    love.graphics.setScissor()

    K.footer({
        { key = "A", label = "Remap" },
        { key = "B", label = "Back" },
    })

    if S.remap then
        K.color({0,0,0}, 0.82); love.graphics.rectangle("fill", 0, 0, K.W, K.H)
        local bw, bh = 480, 240
        local bx = (K.W-bw)/2; local by = (K.H-bh)/2
        K.panel(bx, by, bw, bh, { cut = 8 })
        if S.remap.phase == "wait" then
            K.text("h", "Press a button", bx, by+20, K.C.text, 1, bw, "center")
            K.text("body", native_label(S.remap.row.key), bx, by+64, K.C.dim, 1, bw, "center")
            local p = 1 - S.remap.t/S.remap.timeout
            K.bar(bx+40, by+bh-60, bw-80, 8, p, K.acc)
            K.text("small", "B to cancel", bx, by+bh-32, K.C.faint, 1, bw, "center")
        else
            K.text("h", "Confirm?", bx, by+20, K.C.text, 1, bw, "center")
            K.text("body", native_label(S.remap.row.key), bx, by+64, K.C.dim, 1, bw, "center")
            local n = S.remap.new_value:match("Button%s+(%d+)") or "?"
            local muos = muos_from_value(S.remap.new_value)
            draw_muos_badge(muos, bx+bw/2, by+120, 32)
            K.text("body", "Button "..n, bx, by+150, K.C.text, 1, bw, "center")
            if S.remap.duplicate then
                K.text("small", "! duplicate: "..S.remap.duplicate.key, bx, by+180, K.C.warn, 1, bw, "center")
            end
            K.text("small", "A confirm  ·  B cancel", bx, by+bh-24, K.C.faint, 1, bw, "center")
        end
    end
end

return S
