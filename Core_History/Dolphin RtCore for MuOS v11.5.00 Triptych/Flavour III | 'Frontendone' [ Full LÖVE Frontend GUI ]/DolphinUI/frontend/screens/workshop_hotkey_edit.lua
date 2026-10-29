-- screens/workshop_hotkey_edit.lua — edit single hotkey binding.
--
-- Input model:
--   * State.raw_input is held true for the whole lifetime of this screen
--     so B reaches S.pad (S.pad handles it explicitly now).
--   * While capturing, State.capture_mode = true. main.lua routes ALL
--     pad/key input here without any logical translation, letting the
--     user bind any key including B / SELECT / START / Tab.

local A = require("assets")
local SFX = require("sfx")
local State = require("state")
local IM = require("input_map")
local D = require("ui.draw")
local BG = require("ui.bg")
local Header = require("ui.header")
local Icons = require("ui.icons")
local HE = require("hotkey_editor")
local Notify = require("notify")
local PMerger = require("profile_merger")

local S = {}
local W, H = 640, 480

local function shq(s)
    if s == nil then return "''" end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local BINDINGS = {
    { key = "Keys/Exit",                label = "Exit",          icon = "off" },
    { key = "Keys/Save State Slot 1",   label = "Save State 1",  icon = "save" },
    { key = "Keys/Load State Slot 1",   label = "Load State 1",  icon = "save" },
    { key = "Keys/Save State Slot 2",   label = "Save State 2",  icon = "save" },
    { key = "Keys/Load State Slot 2",   label = "Load State 2",  icon = "save" },
    { key = "Keys/Save State Slot 3",   label = "Save State 3",  icon = "save" },
    { key = "Keys/Load State Slot 3",   label = "Load State 3",  icon = "save" },
    { key = "Keys/Toggle Pause",        label = "Toggle Pause",  icon = "controller" },
    { key = "Keys/Toggle Fast Forward", label = "Fast Forward",  icon = "zap" },
    { key = "Keys/Reset",               label = "Reset",         icon = "wrench" },
    { key = "Keys/Take Screenshot",     label = "Screenshot",    icon = "star" },
    { key = "Keys/Volume Down",         label = "Volume Down",   icon = "off" },
    { key = "Keys/Volume Up",           label = "Volume Up",     icon = "off" },
}

S.sel = 1
S.profile = nil
S.bindings = {}
S.capturing = false
S.capture_target = nil
S.captured_buttons = {}
S.capture_hold_t = 0

local function profile_path(name)
    return "workshop/hotkeys/" .. name .. "/Hotkeys.ini"
end

local function load_bindings(profile_name)
    S.profile = profile_name
    S.bindings = {}

    local path = profile_path(profile_name)
    local parsed = PMerger.parse_ini(path)
    if not parsed then
        os.execute("mkdir -p " .. shq("workshop/hotkeys/" .. profile_name))
        local f = io.open(path, "w")
        if f then
            f:write("[Hotkeys1]\n")
            f:write("Device = SDL/0/muOS-Keys\n")
            f:close()
        end
        parsed = PMerger.parse_ini(path)
        if not parsed then
            Notify.show("error", "Cannot create " .. path)
            return
        end
    end

    local section = parsed.data["Hotkeys1"] or {}
    for _, b in ipairs(BINDINGS) do
        S.bindings[b.key] = section[b.key] or ""
    end
end

function S.enter(params)
    params = params or {}
    local profile = params.profile or "Default"
    load_bindings(profile)
    S.sel = 1
    S.capturing = false
    S.capture_target = nil
    S.captured_buttons = {}
    S.capture_hold_t = 0
    State.capture_mode = false
    State.raw_input = true
end

function S.leave()
    State.raw_input = false
    State.capture_mode = false
end

function S.re_enter()
    State.raw_input = true
    State.capture_mode = false
end

local function move(delta)
    if S.capturing then return end
    local n = #BINDINGS
    local ni = math.max(1, math.min(n, S.sel + delta))
    if ni ~= S.sel then
        S.sel = ni
        SFX.play("menu_move")
    end
end

-- ── Save bindings ───────────────────────────────────────────
local function save_bindings()
    local path = profile_path(S.profile)
    local parsed = PMerger.parse_ini(path)
    if not parsed then
        os.execute("mkdir -p " .. shq("workshop/hotkeys/" .. S.profile))
        local f = io.open(path, "w")
        if f then
            f:write("[Hotkeys1]\n")
            f:write("Device = SDL/0/muOS-Keys\n")
            f:close()
        end
        parsed = PMerger.parse_ini(path)
        if not parsed then
            Notify.show("error", "Cannot save — profile directory missing")
            return false
        end
    end

    parsed.data["Hotkeys1"] = parsed.data["Hotkeys1"] or {}
    parsed.order["Hotkeys1"] = parsed.order["Hotkeys1"] or {}

    for _, b in ipairs(BINDINGS) do
        local val = S.bindings[b.key] or ""
        if parsed.data["Hotkeys1"][b.key] == nil then
            table.insert(parsed.order["Hotkeys1"], b.key)
        end
        parsed.data["Hotkeys1"][b.key] = val
    end

    local tmp = path .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then
        Notify.show("error", "Cannot write")
        return false
    end

    for section, kv in pairs(parsed.data) do
        f:write("[" .. section .. "]\n")
        local keys = parsed.order[section] or {}
        for _, k in ipairs(keys) do
            if kv[k] ~= nil then
                f:write(k .. " = " .. kv[k] .. "\n")
            end
        end
        for k, v in pairs(kv) do
            local found = false
            for _, ok in ipairs(keys) do
                if ok == k then found = true break end
            end
            if not found then f:write(k .. " = " .. v .. "\n") end
        end
        f:write("\n")
    end
    f:close()

    os.remove(path)
    os.rename(tmp, path)
    return true
end

-- ── Capture lifecycle ───────────────────────────────────────
local function start_capture()
    S.capturing = true
    S.captured_buttons = {}
    S.capture_hold_t = 0
    S.capture_target = BINDINGS[S.sel]
    State.capture_mode = true
    SFX.play("menu_select")
end

local function cancel_capture()
    S.capturing = false
    S.captured_buttons = {}
    S.capture_target = nil
    State.capture_mode = false
    SFX.play("menu_back")
end

local function commit_capture()
    if #S.captured_buttons == 0 then
        cancel_capture()
        return
    end

    local expr = HE.build_expression(S.captured_buttons)
    if not expr then
        Notify.show("warning", "No valid buttons captured")
        cancel_capture()
        return
    end

    S.bindings[S.capture_target.key] = expr
    if save_bindings() then
        Notify.show("success",
            "Bound: " .. S.capture_target.label .. " = " .. expr)
    else
        Notify.show("error", "Save failed")
    end

    S.capturing = false
    S.captured_buttons = {}
    S.capture_target = nil
    State.capture_mode = false
end

-- ── Input handlers ──────────────────────────────────────────
function S.pad(b)
    if S.capturing then
        for _, existing in ipairs(S.captured_buttons) do
            if existing == b then return end
        end
        table.insert(S.captured_buttons, b)
        S.capture_hold_t = 0
        SFX.play("menu_toggleoption")
        return
    end

    if b == IM.A then
        start_capture()
    elseif b == IM.X then
        S.bindings[BINDINGS[S.sel].key] = ""
        if save_bindings() then
            Notify.show("info", "Cleared: " .. BINDINGS[S.sel].label)
        end
    elseif b == IM.Y then
        load_bindings("Default")
        Notify.show("info", "Reloaded from Default")
    elseif b == IM.B then
        State.raw_input = false
        State.back()
    end
end

function S.hat(dir)
    if S.capturing then return end
    if     dir == "up"   then move(-1)
    elseif dir == "down" then move(1) end
end

function S.key(k)
    if S.capturing then
        if k == "escape" then cancel_capture()
        elseif k == "return" then commit_capture()
        end
        return
    end

    if     k == "up"   then move(-1)
    elseif k == "down" then move(1)
    elseif k == "return" or k == "space" then start_capture()
    elseif k == "escape" then
        State.raw_input = false
        State.back()
    end
end

function S.update(dt)
    if S.capturing then
        S.capture_hold_t = S.capture_hold_t + dt
        if S.capture_hold_t > 1.5 and #S.captured_buttons > 0 then
            commit_capture()
        end
    end
end

-- ── Drawing ────────────────────────────────────────────────
local function draw_binding_row(b, i, focused, y)
    local th = State.theme
    local t = State.t_ui
    local pulse = 0.5 + 0.5 * math.sin(t * 4 + i * 0.2)
    local c = {0.20, 0.72, 0.98}
    local x, w, h = 20, W - 40, 26

    local is_capturing_this = S.capturing and S.capture_target
        and S.capture_target.key == b.key

    if focused or is_capturing_this then
        if is_capturing_this then
            D.glow(x + w/2, y + h/2, 50, {0.90, 0.25, 0.25}, 1.0)
        else
            D.glow(x + w/2, y + h/2, 40, c, 0.7)
        end
    end

    local bg = focused and c[1]*0.25 or (is_capturing_this and 0.6 or c[1]*0.08)
    love.graphics.setColor(
        bg,
        focused and c[2]*0.25 or (is_capturing_this and 0.15 or c[2]*0.08),
        focused and c[3]*0.25 or (is_capturing_this and 0.15 or c[3]*0.08),
        0.95)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)

    if is_capturing_this then
        love.graphics.setColor(0.90, 0.25, 0.25, 0.8 + pulse * 0.2)
    else
        love.graphics.setColor(c[1], c[2], c[3], focused and 1 or 0.45)
    end
    D.rough_rect(x, y, w, h, { jitter = focused and 1.0 or 0.6,
        thickness = focused and 2 or 1.2, seed = i * 11 })

    love.graphics.setColor(focused and {1,1,1} or th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print(b.label, x + 12, y + 7)

    local val = S.bindings[b.key] or ""
    if is_capturing_this then
        love.graphics.setColor(0.90, 0.25, 0.25)
        love.graphics.setFont(A.font(th.font_body_bold, 10))
        love.graphics.print("▶ PRESS BUTTONS...", x + 220, y + 7)
        if #S.captured_buttons > 0 then
            local names = {}
            for _, btn in ipairs(S.captured_buttons) do
                table.insert(names, HE.name_for(btn))
            end
            love.graphics.setColor({1,1,1})
            love.graphics.print("  [" .. table.concat(names, " + ") .. "]",
                x + 360, y + 7)
        end
    elseif val == "" then
        love.graphics.setColor(0.45, 0.45, 0.50)
        love.graphics.setFont(A.font("assets/fonts/Oxanium-Regular.ttf", 10))
        love.graphics.print("(unbound)", x + 220, y + 7)
    else
        local names = HE.parse_expression(val)
        love.graphics.setColor(0.30, 0.80, 0.40)
        love.graphics.setFont(A.font(th.font_body_bold, 10))
        love.graphics.print(table.concat(names, " + "), x + 220, y + 7)
    end
end

function S.draw()
    local th = State.theme
    BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
    Header.draw("EDIT: " .. (S.profile or "?"), "hotkeys")

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print(
        "Editing: workshop/hotkeys/" .. (S.profile or "?") .. "/Hotkeys.ini",
        20, 60)

    local y = 84
    for i, b in ipairs(BINDINGS) do
        draw_binding_row(b, i, i == S.sel and not S.capturing, y)
        y = y + 28
    end

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 9))
    local hint = S.capturing
        and "[Buttons] Press to bind   [Enter] Commit   [Esc] Cancel"
        or  "[↑↓] Nav   [A] Capture   [X] Clear   [Y] Reset to Default   [B] Back"
    love.graphics.printf(hint, 0, H - 18, W, "center")
end

return S