-- ui/screens/hotkeys.lua — Hotkey designer.
-- Profile list first, then the designer for the chosen profile.
--   KEYBOARD  Hotkeys.ini: Keys/Save State Slot 1 = `F1`; the combo → key
--             pair goes to the profile's ext-dolphin.gptk (managed block).
--   PAD (SDL) Hotkeys.ini: Keys/... = (`Button 6` & `Button 4`)
-- [A] capture combo  [< >] change emitted key  [X] clear  [L1/R1] device
-- [Y] reload  [SELECT] copy profile  [START] save  [B] back
-- Capture: press the buttons together, hold 1.5 s to commit; idle 4 s cancels.
local SFX    = require("ui.sfx")
local State  = require("core.state")
local IM     = require("ui.input")
local AI     = require("core.app_input")
local K      = require("ui.kit")
local U      = require("ui.util")
local Notify = require("ui.notify")
local Modal  = require("ui.modal")
local sh     = require("core.shell")

local S = {}
local W, H = 640, 480

local HK_DIR = "workshop/hotkeys/"
local BLOCK_A = "# >>> HOTKEY DESIGNER (managed block, edit with the Hotkey Designer)"
local BLOCK_B = "# <<< HOTKEY DESIGNER"
local DEFAULT_PAD_DEVICE = "SDL/0/muOS-Keys"

local ACTIONS = {
    { key = "Keys/Save State Slot 1",    label = "Save State 1",   icon = "save" },
    { key = "Keys/Load State Slot 1",    label = "Load State 1",   icon = "save" },
    { key = "Keys/Save State Slot 2",    label = "Save State 2",   icon = "save" },
    { key = "Keys/Load State Slot 2",    label = "Load State 2",   icon = "save" },
    { key = "Keys/Save State Slot 3",    label = "Save State 3",   icon = "save" },
    { key = "Keys/Load State Slot 3",    label = "Load State 3",   icon = "save" },
    { key = "Keys/Toggle Pause",         label = "Toggle Pause",   icon = "controller" },
    { key = "Keys/Toggle Fast Forward",  label = "Fast Forward",   icon = "zap" },
    { key = "Keys/Decrease Frame Limit", label = "Frame Limit -",  icon = "zap" },
    { key = "Keys/Increase Frame Limit", label = "Frame Limit +",  icon = "zap" },
    { key = "Keys/Take Screenshot",      label = "Screenshot",     icon = "star" },
    { key = "Keys/Reset",                label = "Reset",          icon = "wrench" },
    { key = "Keys/Exit",                 label = "Safe Exit",      icon = "off" },
    { key = "Keys/Set State Slot to 1",  label = "State Slot 1",   icon = "save" },
    { key = "Keys/Set State Slot to 2",  label = "State Slot 2",   icon = "save" },
    { key = "Keys/Set State Slot to 3",  label = "State Slot 3",   icon = "save" },
}

local KEY_LIST = { "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
                   "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
                   "Escape", "Space", "Return", "Tab", "Backspace" }

local function to_gptk(k)
    if k:match("^F%d+$") then return k end
    return k:lower()
end
local function from_gptk(t)
    if t:match("^[fF]%d+$") then return t:upper() end
    if #t == 1 then return t:upper() == t and t or t:upper() end
    return t:sub(1, 1):upper() .. t:sub(2):lower()
end

-- SDL name → logical name (used while capturing from gamepad events)
local PAD_NAMES = { dpup = "UP", dpdown = "DOWN", dpleft = "LEFT", dpright = "RIGHT",
                    a = "A", b = "B", x = "X", y = "Y", start = "START", back = "SELECT",
                    guide = "MENU", leftshoulder = "L1", rightshoulder = "R1",
                    lefttrigger = "L2", righttrigger = "R2", leftstick = "L3", rightstick = "R3" }
local DPAD = { UP = true, DOWN = true, LEFT = true, RIGHT = true }

-- gptk button token <-> logical name. The MENU token is whatever the file
-- already uses ("m" or "guide") so an existing Exit binding keeps working.
S.menu_tok = "guide"
local function btn_to_gptk(n) if n == "MENU" then return S.menu_tok end return n:lower() end
local function btn_from_gptk(t)
    t = t:lower()
    if t == "guide" or t == "m" then return "MENU" end
    if t == "back" then return "SELECT" end
    return t:upper()
end

-- ── State ───────────────────────────────────────────────────
S.profile = "Default"
S.device = "keyboard"
S.pad_device = DEFAULT_PAD_DEVICE
S.model = {}
S.dirty = false
S.capturing = false
S.cap, S.cap_t = {}, 0
S._t = 0
S.gptk_map = {}
S.conf = {}
S.list = K.List(K.MARGIN, 150, K.W - K.MARGIN * 2 - 14, K.BOT - 150, 38)
S.plist = K.List(K.MARGIN, 90, K.W - K.MARGIN * 2 - 14, K.BOT - 90, 38)
S.mode = "profiles"

local function valid_profile_name(name)
    return type(name) == "string" and #name > 0 and #name <= 64
        and name ~= "Disabled" and name:match("^[%w_%-]+$") ~= nil
end

local function ini_path(p)  return HK_DIR .. p .. "/Hotkeys.ini" end
local function gptk_path(p) return HK_DIR .. p .. "/ext-dolphin.gptk" end
local function meta_path(p) return HK_DIR .. p .. "/rthotkeys_data.ini" end

-- ── files ───────────────────────────────────────────────────
local function read_lines(path)
    local f = io.open(path, "r")
    local lines = {}
    if f then
        for l in f:lines() do lines[#lines + 1] = (l:gsub("\r$", "")) end
        f:close()
    end
    return lines
end

local function write_lines(path, lines)
    local text = table.concat(lines, "\n") .. "\n"
    local ok, r = pcall(sh.atomic_write, path, text)
    if ok and r then return true end
    local tmp = path .. ".tmp"
    local f = io.open(tmp, "w")
    if not f then return false end
    f:write(text); f:close()
    os.remove(path)
    return os.rename(tmp, path) and true or false
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function load_gptk(profile)
    local map = {}
    S.menu_tok = "guide"
    for _, l in ipairs(read_lines(gptk_path(profile))) do
        local t = trim(l)
        if t ~= "" and t:sub(1, 1) ~= "#" and t:sub(1, 1) ~= ";" then
            local lhs, rhs = t:match("^([%w%+_]+)%s*=%s*(%S+)")
            if lhs then
                map[lhs:lower()] = rhs
                for part in lhs:gmatch("[^%+]+") do
                    if part:lower() == "m" then S.menu_tok = "m" end
                end
            end
        end
    end
    return map
end

local function combo_str(combo)
    local p = {}
    for _, b in ipairs(combo) do p[#p + 1] = btn_to_gptk(b) end
    return table.concat(p, "+")
end
local function combo_from_str(s)
    local out = {}
    for part in s:gmatch("[^%+]+") do out[#out + 1] = btn_from_gptk(part) end
    return out
end

-- ── pad expressions (Dolphin SDL: `Button N` & `Button M`) ──
local function pad_raw(name)
    local pm = AI.pad_map() or {}
    local v = pm[name]
    if type(v) == "number" then return v end
end
local function expr_for(combo)
    if #combo == 0 then return "" end
    local parts = {}
    for _, name in ipairs(combo) do
        local raw = pad_raw(name)
        if raw == nil then return "", "dpad" end     -- D-pad / unmapped: not expressible
        parts[#parts + 1] = "`Button " .. raw .. "`"
    end
    if #parts == 1 then return parts[1] end
    return "(" .. table.concat(parts, " & ") .. ")"
end
local function parse_expr(v)
    local out = {}
    for n in tostring(v):gmatch("Button%s+(%d+)") do
        local lg = IM.from_raw(tonumber(n))
        if lg then out[#out + 1] = lg end
    end
    return out
end

-- ── model ───────────────────────────────────────────────────
local function used_keys()
    local u = {}
    for _, a in ipairs(ACTIONS) do
        local m = S.model[a.key]
        if m and m.key then u[m.key] = true end
    end
    return u
end
local function auto_key()
    local u = used_keys()
    for _, k in ipairs(KEY_LIST) do if not u[k] then return k end end
    return KEY_LIST[1]
end

local function recompute_conflicts()
    local seen, conf = {}, {}
    for _, a in ipairs(ACTIONS) do
        local m = S.model[a.key]
        if m and #m.combo > 0 then
            local cs = combo_str(m.combo)
            seen[cs] = (seen[cs] or 0) + 1
        end
    end
    for _, a in ipairs(ACTIONS) do
        local m = S.model[a.key]
        if m and #m.combo > 0 and seen[combo_str(m.combo)] > 1 then conf[a.key] = true end
    end
    S.conf = conf
end

local function load_profile(name)
    S.profile = name
    S.gptk_map = load_gptk(name)
    local rev = {}
    for lhs, rhs in pairs(S.gptk_map) do rev[to_gptk(from_gptk(rhs)):lower()] = lhs end
    S.model = {}
    local dev, vals, in_sec = nil, {}, false
    for _, l in ipairs(read_lines(ini_path(name))) do
        local sec = l:match("^%[([^%]]+)%]")
        if sec then in_sec = (sec == "Hotkeys1") end
        if in_sec then
            local k, v = l:match("^%s*([^=#]-)%s*=%s*(.-)%s*$")
            if k == "Device" then dev = v elseif k and k:match("^Keys/") then vals[k] = v end
        end
    end
    if dev and dev:lower():match("^keyboard") then S.device = "keyboard"
    elseif dev and dev ~= "" then S.device = "pad"; S.pad_device = dev
    else S.device = "keyboard" end
    for _, a in ipairs(ACTIONS) do
        local m = { combo = {}, key = nil }
        local v = vals[a.key]
        if v and v ~= "" then
            if S.device == "keyboard" then
                local key = v:match("`([^`]+)`") or v
                m.key = from_gptk(key)
                local lhs = rev[to_gptk(m.key):lower()]
                if lhs then m.combo = combo_from_str(lhs) end
            else
                m.combo = parse_expr(v)
            end
        end
        S.model[a.key] = m
    end
    S.dirty = false
    recompute_conflicts()
end

local function rebuild_rows()
    local rows = {}
    for i, a in ipairs(ACTIONS) do rows[i] = { kind = "action", a = a } end
    S.list:set(rows, true)
end

local function switch_device(d)
    if d == S.device then return end
    if d == "keyboard" then
        for _, a in ipairs(ACTIONS) do
            local m = S.model[a.key]
            if #m.combo > 0 and not m.key then
                local mapped = S.gptk_map[combo_str(m.combo)]
                m.key = mapped and from_gptk(mapped) or auto_key()
            end
        end
    end
    S.device = d
    S.dirty = true
    SFX.play("menu_pagescroll")
    rebuild_rows()
end

-- ── save ────────────────────────────────────────────────────
local function set_kv(lines, section, key, value)
    local s, e
    for i, l in ipairs(lines) do
        local sec = l:match("^%[([^%]]+)%]")
        if sec then
            if s and not e then e = i - 1 end
            if sec == section then s = i end
        end
    end
    if s and not e then e = #lines end
    if not s then
        if #lines > 0 and lines[#lines] ~= "" then lines[#lines + 1] = "" end
        lines[#lines + 1] = "[" .. section .. "]"
        lines[#lines + 1] = key .. " = " .. value
        return
    end
    for i = s + 1, e do
        local k = lines[i]:match("^%s*([^=#]-)%s*=")
        if k == key then lines[i] = key .. " = " .. value; return end
    end
    local at = e
    while at > s and lines[at]:match("^%s*$") do at = at - 1 end
    table.insert(lines, at + 1, key .. " = " .. value)
end

local function write_gptk()
    local lines = read_lines(gptk_path(S.profile))
    local out, skipping = {}, false
    for _, l in ipairs(lines) do
        if l == BLOCK_A then skipping = true
        elseif l == BLOCK_B then skipping = false
        elseif not skipping then out[#out + 1] = l end
    end
    local managed, block = {}, {}
    for _, a in ipairs(ACTIONS) do
        local m = S.model[a.key]
        if m and #m.combo > 0 and m.key then
            local lhs = combo_str(m.combo)
            if managed[lhs] then
                block[#block + 1] = ("# CONFLICT %-14s = %s    # %s"):format(lhs, to_gptk(m.key), a.label)
            else
                managed[lhs] = true
                block[#block + 1] = ("%-14s = %s    # %s"):format(lhs, to_gptk(m.key), a.label)
            end
        end
    end
    -- hand-written lines that clash with a managed combo go away
    local kept = {}
    for _, l in ipairs(out) do
        local t = trim(l)
        local lhs = t:match("^([%w%+_]+)%s*=")
        if not (lhs and t:sub(1, 1) ~= "#" and managed[lhs:lower()]) then kept[#kept + 1] = l end
    end
    while #kept > 0 and kept[#kept] == "" do kept[#kept] = nil end
    kept[#kept + 1] = ""
    kept[#kept + 1] = BLOCK_A
    for _, b in ipairs(block) do kept[#kept + 1] = b end
    kept[#kept + 1] = BLOCK_B
    local ok = write_lines(gptk_path(S.profile), kept)
    if ok then S.gptk_map = load_gptk(S.profile) end
    return ok
end

local function save()
    os.execute("mkdir -p " .. sh.shq(HK_DIR .. S.profile))
    local path = ini_path(S.profile)
    local lines = read_lines(path)
    if #lines == 0 then lines = { "[Hotkeys1]" } end
    set_kv(lines, "Hotkeys1", "Device", (S.device == "keyboard") and "Keyboard" or S.pad_device)
    local skipped = 0
    for _, a in ipairs(ACTIONS) do
        local m = S.model[a.key]
        local val = ""
        if S.device == "keyboard" then
            if m.key then val = "`" .. m.key .. "`" end
        else
            local why
            val, why = expr_for(m.combo)
            if why then skipped = skipped + 1 end
        end
        set_kv(lines, "Hotkeys1", a.key, val)
    end
    if skipped > 0 then
        Notify.show("warning", skipped .. " action(s) use the D-pad: left unbound in pad mode")
    end
    local ok = write_lines(path, lines)
    if ok and S.device == "keyboard" then ok = write_gptk() end
    if ok then
        S.dirty = false
        SFX.play("menu_select")
        Notify.show("success", "Saved: " .. S.profile .. (S.device == "keyboard" and " + gptk" or ""))
    else
        Notify.show("error", "Save failed")
    end
    return ok
end

-- ── lifecycle ───────────────────────────────────────────────
local function open_designer(profile)
    S.mode = "designer"
    S.capturing = false
    State.raw_input = false
    load_profile(profile)
    S.list:set({}, false)
    rebuild_rows()
end

-- ── capture ─────────────────────────────────────────────────
local function start_capture()
    S.capturing = true
    S.cap, S.cap_t = {}, 0
    State.raw_input = true             -- keyboard goes to S.key (ENTER / ESC)
    SFX.play("menu_select")
end

local function end_capture(commit)
    local names = S.cap
    S.capturing = false
    State.raw_input = false
    S.cap = {}
    if not commit or #names == 0 then SFX.play("menu_back"); return end
    local r = S.list:cur(); if not r then return end
    local m = S.model[r.a.key]
    if S.device == "pad" then
        local filtered = {}
        for _, n in ipairs(names) do if not DPAD[n] then filtered[#filtered + 1] = n end end
        if #filtered ~= #names then Notify.show("warning", "D-pad cannot be used in pad expressions") end
        names = filtered
        if #names == 0 then return end
    end
    table.sort(names, function(a, b)
        local wa = (a == "SELECT" or a == "MENU") and 0 or 1
        local wb = (b == "SELECT" or b == "MENU") and 0 or 1
        return wa < wb
    end)
    m.combo = names
    if S.device == "keyboard" and not m.key then
        local mapped = S.gptk_map[combo_str(names)]
        m.key = mapped and from_gptk(mapped) or auto_key()
    end
    recompute_conflicts()
    if S.conf[r.a.key] then
        for _, a in ipairs(ACTIONS) do
            if a.key ~= r.a.key and combo_str(S.model[a.key].combo) == combo_str(names) then
                Notify.show("warning", "Same combo as " .. a.label)
                break
            end
        end
    end
    S.dirty = true
    SFX.play("menu_toggleoption")
end

local function capture_add(name)
    if not name then return end
    for _, e in ipairs(S.cap) do if e == name then return end end
    S.cap[#S.cap + 1] = name
    S.cap_t = 0
    SFX.play("menu_toggleoption")
end

-- raw hook: fires before logical mapping, so a capture sees every button
function S.raw_pad(b)
    if not S.capturing then return false end
    local name
    if type(b) == "number" then name = IM.from_raw(b)
    else name = PAD_NAMES[tostring(b):lower()] or PAD_NAMES[b] end
    capture_add(name)
    return true
end

-- ── actions ─────────────────────────────────────────────────
local function cur_model()
    local r = S.list:cur()
    return r and S.model[r.a.key], r
end

local function cycle_key(d)
    if S.device ~= "keyboard" then return end
    local m = cur_model()
    if not m or not m.key then return end
    local idx = 1
    for i, k in ipairs(KEY_LIST) do if k == m.key then idx = i end end
    m.key = KEY_LIST[((idx - 1 + d) % #KEY_LIST) + 1]
    for _, a in ipairs(ACTIONS) do
        local o = S.model[a.key]
        if o ~= m and o.key == m.key then Notify.show("warning", m.key .. " is also used by " .. a.label) end
    end
    S.dirty = true
    SFX.play("menu_move")
end

local function clear()
    local m = cur_model()
    if not m then return end
    m.combo, m.key = {}, nil
    recompute_conflicts()
    S.dirty = true
    SFX.play("menu_back")
end

local function command_ok(command)
    local a, _, code = os.execute(command)
    return a == true or a == 0 or code == 0
end

local function duplicate()
    if not valid_profile_name(S.profile) then return false, "current hotkey profile name is invalid" end
    local n, name = 1, S.profile .. "_copy"
    while U.exists(ini_path(name)) do
        n = n + 1
        name = S.profile .. "_copy" .. n
        if n > 100 then return false, "too many duplicate profiles" end
    end

    local dst = HK_DIR .. name
    if not command_ok("mkdir -p " .. sh.shq(dst)) then
        return false, "could not create duplicate profile directory"
    end
    for _, filename in ipairs({ "Hotkeys.ini", "ext-dolphin.gptk", "rthotkeys_data.ini" }) do
        local src = HK_DIR .. S.profile .. "/" .. filename
        if U.exists(src) and not command_ok("cp -f " .. sh.shq(src) .. " " ..
                sh.shq(dst .. "/" .. filename) .. " 2>/dev/null") then
            os.execute("rm -rf " .. sh.shq(dst))
            return false, "could not copy " .. filename
        end
    end
    if not U.exists(ini_path(name)) then
        os.execute("rm -rf " .. sh.shq(dst))
        return false, "duplicate Hotkeys.ini was not created"
    end

    local previous_profile, previous_map = S.profile, S.gptk_map
    S.profile = name
    S.gptk_map = load_gptk(name)
    if not save() then
        S.profile, S.gptk_map = previous_profile, previous_map
        os.execute("rm -rf " .. sh.shq(dst))
        return false, "could not save duplicate hotkey profile"
    end

    Notify.show("success", "Copied to " .. name)
    return true, name
end

local function reload()
    load_profile(S.profile)
    rebuild_rows()
    SFX.play("menu_toggleoption")
    Notify.show("info", "Reloaded from disk")
end

local function profiles()
    local rows = {}
    for _, name in ipairs(U.ls(HK_DIR)) do
        if name ~= "Disabled" and U.exists(HK_DIR .. name .. "/Hotkeys.ini") then rows[#rows + 1] = { name = name } end
    end
    S.plist:set(rows, false)
end

function S.enter(params)
    params = params or {}
    S._t = 0
    K.set_accent("hot")
    profiles()
    if valid_profile_name(params.profile) and U.exists(ini_path(params.profile)) then
        open_designer(params.profile)
        S.direct = true
    else S.mode, S.direct = "profiles", false end
end
function S.leave() State.raw_input = false end

local function leave_designer()
    S.dirty = false; State.raw_input = false
    if S.direct then require("ui").back() else S.mode = "profiles" end
end
local function try_back()
    if S.dirty then
        Modal.show("Unsaved changes", "Leave without saving?", { accept_label = "Leave", cancel_label = "Stay", on_accept = leave_designer })
    else leave_designer() end
end

function S.update(dt)
    S._t = S._t + dt
    S.list:update(dt); S.plist:update(dt)
    if S.capturing then
        S.cap_t = S.cap_t + dt
        if S.cap_t > 1.5 and #S.cap > 0 then end_capture(true)
        elseif S.cap_t > 4 and #S.cap == 0 then end_capture(false) end   -- no keyboard on a handheld: auto-cancel
    end
end

function S.pad(b)
    if S.mode == "profiles" then
        local r = S.plist:cur()
        if b == "UP" then if S.plist:move(-1) then SFX.play("menu_move") end
        elseif b == "DOWN" then if S.plist:move(1) then SFX.play("menu_move") end
        elseif b == "A" and r then SFX.play("menu_select"); open_designer(r.name)
        elseif b == "B" then require("ui").back() end
        return
    end
    if S.capturing then capture_add(b); return end
    if     b == "UP"    then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN"  then if S.list:move(1)  then SFX.play("menu_move") end
    elseif b == "LEFT"  then cycle_key(-1)
    elseif b == "RIGHT" then cycle_key(1)
    elseif b == "A"     then start_capture()
    elseif b == "X"     then clear()
    elseif b == "Y"     then reload()
    elseif b == "L1"    then switch_device("keyboard")
    elseif b == "R1"    then switch_device("pad")
    elseif b == "SELECT" then duplicate()
    elseif b == "START" then save()
    elseif b == "B"     then try_back() end
end

function S.key(k)
    if S.capturing then
        if k == "escape" then end_capture(false) elseif k == "return" then end_capture(true) end
    end
end

-- ── drawing ─────────────────────────────────────────────────
local function keycap(text, x, yc, c)
    local f = K.font("key"); love.graphics.setFont(f)
    local w = f:getWidth(text) + 14
    K.color(c, 0.18); love.graphics.rectangle("fill", x, yc - 10, w, 20, 5, 5)
    K.color(c, 0.95); love.graphics.rectangle("line", x, yc - 10, w, 20, 5, 5)
    K.color(K.C.text, 1); love.graphics.print(text, x + 7, yc - f:getHeight() / 2)
    return w
end

local function arrow(x, yc, c)
    K.color(c, 0.9)
    love.graphics.polygon("fill", x, yc - 5, x + 10, yc, x, yc + 5)
end

local function draw_combo(combo, x, yc)
    if #combo == 0 then
        K.text("mono", S.device == "keyboard" and "direct key" or "unbound", x, yc - 7, K.C.faint)
        return 76
    end
    local cx = x
    for i, n in ipairs(combo) do
        if i > 1 then K.text("key", "+", cx + 2, yc - 8, K.acc); cx = cx + 14 end
        cx = cx + keycap(n, cx, yc, K.acc) + 1
    end
    return cx - x
end

local function draw_row(r, x, y, w, h, focused)
    local a, m = r.a, S.model[r.a.key]
    local cap = focused and S.capturing
    K.panel(x, y + 2, w, h - 4, { focus = focused, force = cap, accent = cap and K.C.bad or K.acc, cut = 6 })
    K.text("body", a.label, x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
    local bx, yc = x + 190, y + h / 2
    if cap then
        local txt = #S.cap > 0 and table.concat(S.cap, " + ") or "PRESS THE BUTTONS…"
        K.text("key", txt, bx, yc - 8, K.C.bad)
        return
    end
    local used = draw_combo(m.combo, bx, yc)
    if S.conf[a.key] then K.color(K.C.warn, 1); love.graphics.circle("fill", x + w - 12, y + 10, 4) end
    if S.device == "keyboard" and m.key then
        arrow(bx + used + 10, yc, K.acc)
        keycap(m.key, bx + used + 28, yc, K.ACC.sys)
    elseif S.device == "pad" and #m.combo > 0 then
        local ex, why = expr_for(m.combo)
        if why then K.text("mono", "D-pad: not expressible", bx, yc + 8, K.C.warn)
        else K.text("mono", K.clip("mono", (ex:gsub("`", "")), 230), bx, yc + 8, K.C.faint) end
    end
end

local function draw_profile(r, x, y, w, h, focused)
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    K.text("body", r.name, x + 14, y + h / 2 - 9, focused and K.C.text or K.C.dim)
    K.text("body", "›", x + w - 22, y + h / 2 - 9, focused and K.acc or K.C.faint)
end

function S.draw()
    if S.mode == "profiles" then
        K.header("Hotkeys", "Choose a profile to design", nil, nil, { icon = "hotkeys" })
        if #S.plist.items == 0 then K.text("body", "No hotkey profiles found in workshop/hotkeys.", 0, 200, K.C.dim, 1, K.W, "center")
        else S.plist:draw(draw_profile) end
        K.footer({ { key = "A", label = "Design" }, { key = "B", label = "Back" } })
        return
    end
    K.header("Hotkeys", "profile · " .. S.profile .. (S.dirty and "   ● unsaved" or ""), nil)
    local tw = (K.W - K.MARGIN * 2 - 8) / 2
    for i, it in ipairs({ { id = "keyboard", label = "KEYBOARD", sub = "gptokeyb2 F-keys" },
                          { id = "pad", label = "PAD (SDL)", sub = S.pad_device } }) do
        local x = K.MARGIN + (i - 1) * (tw + 8)
        local act = S.device == it.id
        K.panel(x, 90, tw, 44, { focus = act, cut = 8 })
        K.text("h", it.label, x + 14, 94, act and K.C.text or K.C.dim)
        K.text("mono", K.clip("mono", it.sub, tw - 28), x + 14, 116, act and K.acc or K.C.faint)
    end
    S.list:draw(draw_row)
    if S.capturing then
        K.footer({ { key = "HOLD", label = "Commit combo" }, { key = "IDLE 4s", label = "Cancel" } })
    else
        K.footer({ { key = "A", label = "Capture" }, { key = "X", label = "Clear" }, { key = "L1 R1", label = "Device" },
                   { key = "SELECT", label = "Copy" }, { key = "START", label = "Save" }, { key = "B", label = "Back" } })
    end
end

-- NEXUS adapters call the same profile, capture and persistence functions as the pad UI.
function S.register_actions(ui)
    if not ui or type(ui.register_action) ~= "function" then
        return false, "UI action registrar unavailable"
    end

    local function in_designer()
        return S.mode == "designer"
    end
    local function selected_row()
        return S.list and S.list:cur() or nil
    end
    local function selected_profile()
        return S.plist and S.plist:cur() or nil
    end
    local function captured_name(input)
        if type(input) == "number" then return IM.from_raw(input) end
        if type(input) ~= "string" then return nil end
        local value = input:match("^%s*(.-)%s*$")
        local upper = value:upper()
        local logical = {
            UP = true, DOWN = true, LEFT = true, RIGHT = true,
            A = true, B = true, X = true, Y = true,
            START = true, SELECT = true, MENU = true,
            L1 = true, R1 = true, L2 = true, R2 = true, L3 = true, R3 = true,
        }
        if logical[upper] then return upper end
        return PAD_NAMES[value:lower()]
    end
    local specs = {
        {
            id = "hotkeys.refresh_profiles", title = "Refresh hotkey profiles", order = 10,
            run = function()
                if S.mode ~= "profiles" then return false, "profile list is not active" end
                if S.capturing then return false, "cancel capture before refreshing profiles" end
                local selected = selected_profile()
                profiles()
                if selected then
                    for i, row in ipairs(S.plist.items) do
                        if row.name == selected.name then
                            S.plist.sel = i
                            if S.plist._aim then S.plist:_aim(true) end
                            break
                        end
                    end
                end
                return true
            end,
        },
        {
            id = "hotkeys.select_profile", title = "Select hotkey profile", order = 20,
            run = function(index)
                if S.mode ~= "profiles" then return false, "profile list is not active" end
                if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #S.plist.items then
                    return false, "hotkey profile index out of range"
                end
                S.plist.sel = index
                if S.plist._aim then S.plist:_aim(true) end
                return true
            end,
        },
        {
            id = "hotkeys.open_profile", title = "Open hotkey profile", order = 30,
            run = function(name)
                if S.mode ~= "profiles" then return false, "profile list is not active" end
                if not valid_profile_name(name) then return false, "invalid hotkey profile name" end
                if not U.exists(ini_path(name)) then return false, "hotkey profile not found" end
                open_designer(name)
                S.direct = false
                return true
            end,
        },
        {
            id = "hotkeys.open_selected_profile", title = "Open selected hotkey profile", order = 40,
            run = function()
                if S.mode ~= "profiles" then return false, "profile list is not active" end
                local row = selected_profile()
                if not row then return false, "no hotkey profile selected" end
                if not valid_profile_name(row.name) or not U.exists(ini_path(row.name)) then
                    return false, "selected hotkey profile is invalid or missing"
                end
                open_designer(row.name)
                S.direct = false
                return true
            end,
        },
        {
            id = "hotkeys.select_action", title = "Select hotkey action", order = 50,
            run = function(index)
                if not in_designer() or S.capturing then return false, "hotkey designer is not ready" end
                if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #S.list.items then
                    return false, "hotkey action index out of range"
                end
                S.list.sel = index
                if S.list._aim then S.list:_aim(true) end
                return true
            end,
        },
        {
            id = "hotkeys.set_device", title = "Set hotkey input device", order = 60,
            run = function(device)
                if not in_designer() or S.capturing then return false, "hotkey designer is not ready" end
                if device ~= "keyboard" and device ~= "pad" then
                    return false, "device must be keyboard or pad"
                end
                switch_device(device)
                return true
            end,
        },
        {
            id = "hotkeys.change_key", title = "Change emitted keyboard key", order = 70,
            run = function(direction)
                if not in_designer() or S.capturing then return false, "hotkey designer is not ready" end
                if direction ~= -1 and direction ~= 1 then return false, "direction must be -1 or 1" end
                if S.device ~= "keyboard" then return false, "emitted keys only apply to keyboard mode" end
                local model = cur_model()
                if not model or not model.key then return false, "selected action has no emitted key" end
                local previous = model.key
                cycle_key(direction)
                return model.key ~= previous
            end,
        },
        {
            id = "hotkeys.clear_selected", title = "Clear selected hotkey", order = 80,
            run = function()
                if not in_designer() or S.capturing then return false, "hotkey designer is not ready" end
                if not selected_row() then return false, "no hotkey action selected" end
                clear()
                return true
            end,
        },
        {
            id = "hotkeys.start_capture", title = "Start hotkey capture", order = 90,
            run = function()
                if not in_designer() then return false, "hotkey designer is not active" end
                if S.capturing then return false, "hotkey capture is already active" end
                if not selected_row() then return false, "no hotkey action selected" end
                start_capture()
                return true
            end,
        },
        {
            id = "hotkeys.capture_input", title = "Capture raw hotkey input", order = 100,
            run = function(input)
                if not S.capturing then return false, "hotkey capture is not active" end
                local name = captured_name(input)
                if not name then return false, "input was not recognised" end
                capture_add(name)
                return true
            end,
        },
        {
            id = "hotkeys.finish_capture", title = "Finish hotkey capture", order = 110,
            run = function(commit)
                if not S.capturing then return false, "hotkey capture is not active" end
                if type(commit) ~= "boolean" then return false, "commit must be boolean" end
                if commit and #S.cap == 0 then return false, "no input was captured" end
                if commit and S.device == "pad" then
                    local expressible = false
                    for _, name in ipairs(S.cap) do if not DPAD[name] then expressible = true; break end end
                    if not expressible then return false, "pad capture requires a non-D-pad button" end
                end
                end_capture(commit)
                return true
            end,
        },
        {
            id = "hotkeys.duplicate_profile", title = "Duplicate hotkey profile", order = 120,
            run = function()
                if not in_designer() or S.capturing then return false, "hotkey designer is not ready" end
                local ok, result = duplicate()
                if not ok then return false, result or "could not duplicate hotkey profile" end
                return true, result
            end,
        },
        {
            id = "hotkeys.reload", title = "Reload hotkey profile", order = 130,
            run = function()
                if not in_designer() or S.capturing then return false, "hotkey designer is not ready" end
                if not U.exists(ini_path(S.profile)) then return false, "hotkey profile file is missing" end
                reload()
                return true
            end,
        },
        {
            id = "hotkeys.save", title = "Save hotkey profile", order = 140,
            run = function()
                if not in_designer() or S.capturing then return false, "hotkey designer is not ready" end
                return save()
            end,
        },
        {
            id = "hotkeys.request_back", title = "Request exit from hotkey designer", order = 150,
            run = function()
                if not in_designer() then return false, "hotkey designer is not active" end
                if S.capturing then return false, "finish or cancel capture before leaving" end
                try_back()
                return true
            end,
        },
        {
            id = "hotkeys.state", title = "Get hotkey designer state", order = 160,
            run = function()
                local row = selected_row()
                local model = row and S.model[row.a.key] or nil
                local conflicts = 0
                for _ in pairs(S.conf or {}) do conflicts = conflicts + 1 end
                return {
                    mode = S.mode,
                    profile = S.profile,
                    device = S.device,
                    dirty = S.dirty == true,
                    capturing = S.capturing == true,
                    selected_action = row and row.a.label or nil,
                    selected_combo = model and combo_str(model.combo) or nil,
                    emitted_key = model and model.key or nil,
                    conflict_count = conflicts,
                    profile_count = S.plist and #S.plist.items or 0,
                    action_count = S.list and #S.list.items or 0,
                }
            end,
        },
    }

    for _, spec in ipairs(specs) do
        local ok, err = ui.register_action(spec.id, spec.run, {
            title = spec.title, group = "hotkeys", order = spec.order, screen = "hotkeys",
        })
        if not ok then return false, err or ("could not register " .. spec.id) end
    end
    return true
end

return S
