-- ui/screens/keymap.lua — controller mapping con spritesheet 3D rotante.
--
-- params: { system = "GameCube"|"Wii", profile = "Default" }
--
-- A = remap tasto selezionato (capture input)
-- L1/R1 = cambia sistema
-- B = back
local K      = require("ui.kit")
local SFX    = require("ui.sfx")
local U      = require("ui.util")
local Notify = require("ui.notify")
local Modal  = require("ui.modal")
local Ini    = require("core.ini_edit")

local S = {}
S.system = "GameCube"
S.profile = "Default"
S.spin_t = 0
S.remap = nil

local SYSTEM_CFG = {
    GameCube = {
        file    = "GCPadNew.ini",
        section = "GCPad1",
        sprite  = { path = "assets/images/3d_assets/gcpad_spritesheet_256.png",
                    cols = 32, rows = 1, fps = 14 },
        color   = "gc",
    },
    Wii = {
        file    = "WiimoteNew.ini",
        section = "Wiimote1",
        sprite  = { path = "assets/images/3d_assets/wiimote_spritesheet_256.png",
                    cols = 32, rows = 1, fps = 14 },
        color   = "wii",
    },
}

local function valid_profile_name(name)
    return type(name) == "string" and #name > 0 and #name <= 64
        and name:match("^[%w_%-]+$") ~= nil
end

local NATIVE = {
    GameCube = {
        ["Buttons/A"]="A", ["Buttons/B"]="B", ["Buttons/X"]="X", ["Buttons/Y"]="Y",
        ["Buttons/Z"]="Z", ["Buttons/Start"]="START",
        ["Triggers/L"]="L", ["Triggers/L-Analog"]="L-ANALOG",
        ["Triggers/R"]="R", ["Triggers/R-Analog"]="R-ANALOG",
        ["Main Stick/Up"]="STICK UP", ["Main Stick/Down"]="STICK DOWN",
        ["Main Stick/Left"]="STICK LEFT", ["Main Stick/Right"]="STICK RIGHT",
        ["C-Stick/Up"]="C UP", ["C-Stick/Down"]="C DOWN",
        ["C-Stick/Left"]="C LEFT", ["C-Stick/Right"]="C RIGHT",
        ["D-Pad/Up"]="D-PAD UP", ["D-Pad/Down"]="D-PAD DOWN",
        ["D-Pad/Left"]="D-PAD LEFT", ["D-Pad/Right"]="D-PAD RIGHT",
    },
    Wii = {
        ["Buttons/A"]="A", ["Buttons/B"]="B",
        ["Buttons/1"]="1", ["Buttons/2"]="2",
        ["Buttons/+"]="+", ["Buttons/-"]="-", ["Buttons/Home"]="HOME",
        ["D-Pad/Up"]="D-PAD UP", ["D-Pad/Down"]="D-PAD DOWN",
        ["D-Pad/Left"]="D-PAD LEFT", ["D-Pad/Right"]="D-PAD RIGHT",
        ["Nunchuk/Stick/Up"]="NCK STICK UP", ["Nunchuk/Stick/Down"]="NCK STICK DOWN",
        ["Nunchuk/Stick/Left"]="NCK STICK LEFT", ["Nunchuk/Stick/Right"]="NCK STICK RIGHT",
        ["Nunchuk/Buttons/C"]="NCK C", ["Nunchuk/Buttons/Z"]="NCK Z",
        ["IR/Up"]="IR UP", ["IR/Down"]="IR DOWN",
        ["IR/Left"]="IR LEFT", ["IR/Right"]="IR RIGHT",
        ["Tilt/Left"]="TILT LEFT", ["Tilt/Right"]="TILT RIGHT",
        ["Tilt/Forward"]="TILT FWD", ["Tilt/Backward"]="TILT BACK",
    },
}

local ORDER = {
    GameCube = {
        "Buttons/A","Buttons/B","Buttons/X","Buttons/Y","Buttons/Z","Buttons/Start",
        "Triggers/L","Triggers/L-Analog","Triggers/R","Triggers/R-Analog",
        "Main Stick/Up","Main Stick/Down","Main Stick/Left","Main Stick/Right",
        "C-Stick/Up","C-Stick/Down","C-Stick/Left","C-Stick/Right",
        "D-Pad/Up","D-Pad/Down","D-Pad/Left","D-Pad/Right",
    },
    Wii = {
        "Buttons/A","Buttons/B","Buttons/1","Buttons/2","Buttons/+","Buttons/-","Buttons/Home",
        "D-Pad/Up","D-Pad/Down","D-Pad/Left","D-Pad/Right",
        "Nunchuk/Stick/Up","Nunchuk/Stick/Down","Nunchuk/Stick/Left","Nunchuk/Stick/Right",
        "Nunchuk/Buttons/C","Nunchuk/Buttons/Z",
        "IR/Up","IR/Down","IR/Left","IR/Right",
        "Tilt/Left","Tilt/Right","Tilt/Forward","Tilt/Backward",
    },
}

local _sheet = nil
local function load_sheet(system)
    if _sheet and _sheet.system == system then return _sheet end
    local cfg = SYSTEM_CFG[system]
    if not cfg or not cfg.sprite then return nil end
    local ok, img = pcall(love.graphics.newImage, cfg.sprite.path)
    if not ok or not img then
        print("[keymap] spritesheet not found: " .. cfg.sprite.path)
        return nil
    end
    img:setFilter("linear", "linear")
    local iw, ih = img:getDimensions()
    local fw = math.floor(iw / cfg.sprite.cols)
    local fh = math.floor(ih / cfg.sprite.rows)
    local quads = {}
    for r = 0, cfg.sprite.rows - 1 do
        for c = 0, cfg.sprite.cols - 1 do
            quads[#quads + 1] = love.graphics.newQuad(c * fw, r * fh, fw, fh, iw, ih)
        end
    end
    _sheet = { system = system, img = img, quads = quads,
               fw = fw, fh = fh, fps = cfg.sprite.fps, n = #quads,
               iw = iw, ih = ih }
    print(string.format("[keymap] sheet %s: %dx%d, %dx%d=%d frames, %dx%d",
        system, iw, ih, cfg.sprite.cols, cfg.sprite.rows, #quads, fw, fh))
    return _sheet
end

local function load_entries()
    local cfg = SYSTEM_CFG[S.system]
    S.path = "workshop/controller/" .. S.system .. "/" .. S.profile .. "/" .. cfg.file
    S.lines = Ini.read_lines(S.path)
    local rows = {}
    for _, key in ipairs(ORDER[S.system] or {}) do
        local v = Ini.get(S.lines, cfg.section, key)
        if v and v ~= "" then
            rows[#rows+1] = { key = key, value = v, label = NATIVE[S.system][key] or key }
        end
    end
    S.list:set(rows, false)
    S.list.sel = 1
end

function S.enter(params)
    params = params or {}
    S.system  = SYSTEM_CFG[params.system] and params.system or "GameCube"
    S.profile = valid_profile_name(params.profile) and params.profile or "Default"
    S.spin_t  = 0
    S.remap   = nil
    S.list = K.List(K.MARGIN + 216, 96,
                    K.W - (K.MARGIN + 216) - K.MARGIN,
                    K.BOT - 96, 44)
    load_entries()
    K.set_accent((S.system == "GameCube") and "gc" or "wii")
end

function S.update(dt)
    S.spin_t = S.spin_t + dt
    S.list:update(dt)
    if S.remap and S.remap.phase == "wait" then
        S.remap.t = (S.remap.t or 0) + dt
        if S.remap.t > 5.0 then
            S.remap = nil
            SFX.play("menu_back")
        end
    end
end

function S.raw_pad(raw)
    if S.remap and S.remap.phase == "wait" then
        local n = tonumber(raw)
        if n then
            S.remap.captured  = n
            S.remap.new_value = "`Button " .. n .. "`"
            S.remap.phase     = "confirm"
            SFX.play("menu_toggleoption")
            return true
        end
    end
    return false
end

local function switch_system()
    S.system = (S.system == "GameCube") and "Wii" or "GameCube"
    S.remap = nil
    load_entries()
    K.set_accent((S.system == "GameCube") and "gc" or "wii")
    SFX.play("menu_pagescroll")
end

local function open_remap()
    local row = S.list:cur()
    if not row then return end
    S.remap = { row = row, phase = "wait", t = 0 }
    SFX.play("menu_select")
end

local function commit_remap()
    local r = S.remap
    if not r or r.phase ~= "confirm" then
        return false, "no captured mapping to confirm"
    end
    local cfg = SYSTEM_CFG[S.system]
    if not cfg or not r.row or not r.row.key then
        return false, "controller mapping context is invalid"
    end
    local previous_lines = {}
    for i, line in ipairs(S.lines) do previous_lines[i] = line end
    local set_ok, set_err = pcall(Ini.set, S.lines, cfg.section, r.row.key, r.new_value)
    if not set_ok then
        S.lines = previous_lines
        return false, tostring(set_err)
    end
    local write_call, write_ok, write_err = pcall(Ini.write_lines, S.path, S.lines)
    if not write_call or not write_ok then
        S.lines = previous_lines
        Notify.show("error", "Could not save controller mapping")
        local detail
        if write_call then detail = write_err else detail = write_ok end
        return false, tostring(detail or "controller mapping write failed")
    end
    local label = r.row.label
    local captured = r.captured
    S.remap = nil
    load_entries()
    SFX.play("newupdate")
    Notify.show("success", label .. " → Button " .. captured)
    return true
end

local function cancel_remap()
    if not S.remap then return false, "no controller remap is active" end
    S.remap = nil
    SFX.play("menu_back")
    return true
end

function S.pad(b)
    if S.remap then
        if S.remap.phase == "confirm" then
            if b == "A" then commit_remap()
            elseif b == "B" then cancel_remap() end
        elseif S.remap.phase == "wait" then
            if b == "B" then cancel_remap() end
        end
        return
    end
    if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "A" then open_remap()
    elseif b == "L1" or b == "R1" then switch_system()
    elseif b == "B" then require("ui").back() end
end

-- ── draw ────────────────────────────────────────────────
local function draw_header()
    local m = K.MARGIN
    local acc = K.acc
    K.color(acc, 0.16); love.graphics.circle("fill", m + 26, 40, 26)
    K.color(acc, 1);    love.graphics.setLineWidth(1.6)
    love.graphics.circle("line", m + 26, 40, 26); love.graphics.setLineWidth(1)
    if K.draw_tool_icon then K.draw_tool_icon("gamepad", m + 26, 40, 26, acc, 1) end
    K.text("title", "Key Map", m + 60, 14, K.C.text)
    K.text("small", S.system .. "  ·  " .. S.profile, m + 60, 46, K.C.dim)
    K.color(acc, 1); love.graphics.rectangle("fill", m + 60, 68, 56, 3)
    K.color(K.C.line, 0.5); love.graphics.rectangle("fill", m + 116, 69, K.W - m*2 - 116, 1)
end

local function draw_sprite_panel()
    local m = K.MARGIN
    local px, py, pw, ph = m, 96, 200, 200
    K.panel(px, py, pw, ph, { cut = 8 })
    local s = load_sheet(S.system)
    if s then
        local frame = math.floor(S.spin_t * s.fps) % s.n
        local size = 180
        local sc = size / math.max(s.fw, s.fh)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(s.img, s.quads[frame + 1],
            px + pw / 2 - s.fw * sc / 2,
            py + ph / 2 - s.fh * sc / 2,
            0, sc, sc)
    else
        K.text("body", "spritesheet\nnot found",
            px, py + ph / 2 - 20, K.C.dim, 1, pw, "center")
    end
    K.text("small", "L1/R1 switch system", px + 8, py + ph - 18, K.C.faint)
end

local function draw_row(row, x, y, w, h, focused)
    if not row then return end
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    K.text("body", row.label, x + 14, y + h/2 - 11, focused and K.C.text or K.C.dim)
    local right = x + w - 14
    local v = tostring(row.value or "")
    local lw = K.width("value", v)
    K.text("value", v, right - lw, y + h/2 - 10, focused and K.acc or K.C.text)
end

local function draw_remap_overlay()
    local r = S.remap
    if not r then return end
    K.color({ 0, 0, 0 }, 0.80)
    love.graphics.rectangle("fill", 0, 0, K.W, K.H)
    local bw, bh = 480, 260
    local bx = (K.W - bw) / 2
    local by = (K.H - bh) / 2
    K.panel(bx, by, bw, bh, { cut = 12, accent = K.acc })
    K.text("h", "Remap: " .. r.row.label, bx + 20, by + 20, K.C.text)
    K.color(K.acc, 1)
    love.graphics.rectangle("fill", bx + 20, by + 50, 44, 3)
    K.text("body", "Press the button you want to assign to:",
           bx + 20, by + 70, K.C.dim, 1, bw - 40)
    K.text("h", r.row.label, bx + 20, by + 106, K.acc)
    if r.phase == "confirm" then
        K.text("body", "→ Button " .. (r.captured or "?"),
               bx + 20, by + 150, K.C.ok)
        K.text("small", "A confirm · B cancel", bx + 20, by + bh - 36, K.C.dim)
    else
        K.text("body", "waiting…", bx + 20, by + 150, K.C.dim)
        K.text("small", "B cancel", bx + 20, by + bh - 36, K.C.dim)
    end
end

function S.draw()
    K.bg()
    draw_header()
    draw_sprite_panel()
    if #S.list.items == 0 then
        K.text("body", "No mappings for " .. S.system .. " / " .. S.profile,
               232, 220, K.C.dim, 1, K.W - 232 - K.MARGIN, "center")
    else
        S.list:draw(draw_row)
    end
    K.footer({
        { key = "A",     label = "Remap" },
        { key = "L1 R1", label = "System" },
        { key = "B",     label = "Back" },
    })
    draw_remap_overlay()
end

-- NEXUS actions for the controller mapping editor. Writes are committed
-- only after confirmation, and failed writes leave the previous mapping intact.
function S.register_actions(ui)
    if not ui or type(ui.register_action) ~= "function" then
        return false, "UI action registrar unavailable"
    end
    local function valid_context()
        return SYSTEM_CFG[S.system] ~= nil and valid_profile_name(S.profile)
    end
    local function selected()
        return S.list and S.list:cur() or nil
    end
    local specs = {
        {
            id = "keymap.switch_system", title = "Switch controller system", order = 10,
            run = function()
                if not valid_context() then return false, "controller mapping context is invalid" end
                if S.remap then return false, "cancel remap before switching system" end
                switch_system()
                return true
            end,
        },
        {
            id = "keymap.select", title = "Select controller mapping", order = 20,
            run = function(index)
                if not valid_context() then return false, "controller mapping context is invalid" end
                if S.remap then return false, "finish or cancel remap before selecting" end
                if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #S.list.items then
                    return false, "controller mapping index out of range"
                end
                S.list.sel = index
                if S.list._aim then S.list:_aim(true) end
                return true
            end,
        },
        {
            id = "keymap.start_remap", title = "Start controller remap", order = 30,
            run = function()
                if not valid_context() then return false, "controller mapping context is invalid" end
                if S.remap then return false, "controller remap is already active" end
                if not selected() then return false, "no controller mapping selected" end
                open_remap()
                if not S.remap then return false, "could not start controller remap" end
                return true
            end,
        },
        {
            id = "keymap.capture_input", title = "Capture controller input", order = 40,
            run = function(raw)
                if not S.remap or S.remap.phase ~= "wait" then
                    return false, "controller remap is not waiting for input"
                end
                if type(raw) ~= "number" or raw % 1 ~= 0 or raw < 0 or raw > 255 then
                    return false, "raw input must be an integer from 0 to 255"
                end
                if S.raw_pad(raw) then return true end
                return false, "raw input was not accepted"
            end,
        },
        {
            id = "keymap.confirm_remap", title = "Confirm controller remap", order = 50,
            run = function()
                if not S.remap or S.remap.phase ~= "confirm" then
                    return false, "no captured mapping to confirm"
                end
                return commit_remap()
            end,
        },
        {
            id = "keymap.cancel_remap", title = "Cancel controller remap", order = 60,
            run = function()
                return cancel_remap()
            end,
        },
        {
            id = "keymap.state", title = "Get controller mapping state", order = 70,
            run = function()
                local row = selected()
                return {
                    system = S.system,
                    profile = S.profile,
                    selected_key = row and row.key or nil,
                    selected_label = row and row.label or nil,
                    mapping_count = S.list and #S.list.items or 0,
                    remap_phase = S.remap and S.remap.phase or nil,
                    captured_button = S.remap and S.remap.captured or nil,
                    proposed_value = S.remap and S.remap.new_value or nil,
                }
            end,
        },
    }
    for _, spec in ipairs(specs) do
        local ok, err = ui.register_action(spec.id, spec.run, {
            title = spec.title, group = "controller", order = spec.order, screen = "keymap",
        })
        if not ok then return false, err or ("could not register " .. spec.id) end
    end
    return true
end

return S
