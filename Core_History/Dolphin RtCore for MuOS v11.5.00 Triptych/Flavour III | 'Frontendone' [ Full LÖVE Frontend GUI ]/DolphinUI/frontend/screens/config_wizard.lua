-- screens/config_wizard.lua — guided configuration flow.
-- Walks the user through a decision tree defined in data/guide/wizard.json
-- and writes the accumulated settings to either a new Rt:Core profile or
-- a per-game GameSettings file.
--
-- Modes:
--   "pick_game"  → only for per_game wizard: choose target from State.roms
--   "step"       → walking the wizard steps
--   "save"       → review + name entry
--
-- Save logic (complete-profile approach):
--   * core_profile: copy workshop/base/{Dolphin.ini,GFX.ini}, apply the
--     pending changes to the CORRECT file based on section name, write
--     into workshop/rtcoreprofile/<name>/. Plus a rtprofile_data.ini.
--   * per_game: build a namespaced INI ([Core], [Video_Hacks], ...) with
--     only the changed keys, write into workshop/gamesettings/<ID>/<ID>.ini.
--
-- State.raw_input is set to true for the entire lifetime of this screen
-- so every button (including B, R2, SELECT) reaches S.pad instead of
-- being intercepted by main.lua.

local A       = require("assets")
local SFX     = require("sfx")
local State   = require("state")
local IM      = require("input_map")
local D       = require("ui.draw")
local BG      = require("ui.bg")
local Header  = require("ui.header")
local BI      = require("ui.button_icons")
local Modal   = require("modal")
local Notify  = require("notify")
local json    = require("json")
local PMerger = require("profile_merger")

local S = {}
local W, H = 640, 480

local WIZARD_PATH = "data/guide/wizard.json"
local _wizard_data = nil

local function shq(s)
    if s == nil then return "''" end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function safe_profile_name(name)
    if type(name) ~= "string" then return nil end
    local n = name:gsub("[^%w_%-%s%.]", "")
    n = n:gsub("%.%.", "")
    n = n:gsub("^%s+", ""):gsub("%s+$", "")
    if n == "" then return nil end
    return n
end

local function load_wizard()
    if _wizard_data then return _wizard_data end
    local f = io.open(WIZARD_PATH, "r")
    if not f then
        local State2 = require("state")
        local alt = State2.frontend_path("data/guide/wizard.json")
        f = io.open(alt, "r")
    end
    if not f then
        print("[config_wizard] wizard.json not found at " .. WIZARD_PATH)
        return nil
    end
    local c = f:read("*a"); f:close()
    local ok, data = pcall(json.decode, c)
    if not ok or type(data) ~= "table" then
        print("[config_wizard] decode failed: " .. tostring(data))
        return nil
    end
    _wizard_data = data
    return data
end

-- ── State ───────────────────────────────────────────────────
S.mode       = "step"
S.wizard_id  = "core_profile"
S.step_id    = nil
S.path       = {}
S.pending    = {}
S.sel        = 1
S.pick_sel   = 1
S.draft      = nil
S.name_input = nil

local SECTION_TO_FILE = {
    ["General"]    = "Dolphin.ini",
    ["Interface"]  = "Dolphin.ini",
    ["GameList"]   = "Dolphin.ini",
    ["Core"]       = "Dolphin.ini",
    ["Movie"]      = "Dolphin.ini",
    ["Network"]    = "Dolphin.ini",
    ["Log"]        = "Dolphin.ini",
    ["Debug"]      = "Dolphin.ini",
    ["Analytics"]  = "Dolphin.ini",
    ["DSP"]        = "Dolphin.ini",
    ["Hardware"]     = "GFX.ini",
    ["Settings"]     = "GFX.ini",
    ["Enhancements"] = "GFX.ini",
    ["Hacks"]        = "GFX.ini",
    ["Stereoscopy"]  = "GFX.ini",
    ["ColorCorrection"] = "GFX.ini",
}

local function canonical_section(section)
    return (section:gsub("^Video_", ""))
end

local VIDEO_CAPABLE = {
    Settings = true, Enhancements = true, Hacks = true,
    Hardware = true, Stereoscopy = true, ColorCorrection = true,
}
local BARE_SECTIONS = { Core = true, DSP = true, Interface = true }

local function namespaced_section(logical, target_kind)
    if target_kind ~= "gamesettings" then
        return canonical_section(logical)
    end
    if logical:sub(1, 6) == "Video_" then return logical end
    if BARE_SECTIONS[logical] then return logical end
    if VIDEO_CAPABLE[logical] then return "Video_" .. logical end
    return logical
end

-- ── Lifecycle ───────────────────────────────────────────────
function S.enter(params)
    params = params or {}
    local data = load_wizard()
    if not data then
        Notify.show("error", "Wizard data missing")
        State.raw_input = false
        State.back()
        return
    end
    S.wizard_id = params.wizard_id or "core_profile"
    local w = data.wizards[S.wizard_id]
    if not w then
        Notify.show("error", "Unknown wizard: " .. S.wizard_id)
        State.raw_input = false
        State.back()
        return
    end

    S.path     = {}
    S.pending  = {}
    S.sel      = 1
    S.pick_sel = 1
    S.name_input = nil

    S.draft = {
        name        = "",
        description = "",
        target_kind = w.target_kind or S.wizard_id,
        game_id     = params.game_id or nil,
        game_title  = params.game_title or nil,
    }

    if S.draft.target_kind == "rtcoreprofile" then
        S.draft.name = "Custom Profile " .. os.date("%m%d")
        S.draft.description = "Created by Config Wizard"
    elseif S.draft.target_kind == "gamesettings" and S.draft.game_id then
        S.draft.name = S.draft.game_id
        S.draft.description = "Per-game override for " ..
            (S.draft.game_title or S.draft.game_id)
    end

    if w.start == "select_game" and not S.draft.game_id then
        S.mode = "pick_game"
    else
        S.mode    = "step"
        S.step_id = (w.start == "select_game") and "goal" or w.start
    end

    -- Take over input for the whole lifetime of this screen.
    State.raw_input = true
end

function S.leave()
    State.raw_input = false
end

function S.re_enter()
    State.raw_input = true
end

local function wizard()
    local data = load_wizard()
    return data and data.wizards[S.wizard_id]
end

local function current_step()
    local w = wizard()
    if not w then return nil end
    return w.steps[S.step_id]
end

local function accumulate(opt)
    if opt.apply then
        for _, a in ipairs(opt.apply) do
            table.insert(S.pending, a)
        end
    end
end

local function recompute_pending()
    S.pending = {}
    local w = wizard()
    if not w then return end
    for _, entry in ipairs(S.path) do
        local step = w.steps[entry.step_id]
        if step and step.options then
            for _, o in ipairs(step.options) do
                if o.key == entry.option_key then accumulate(o) end
            end
        end
    end
end

-- ── Navigation ──────────────────────────────────────────────
local function go_back()
    if S.mode == "pick_game" then
        State.raw_input = false
        State.back(); return
    end
    if S.mode == "save" then
        S.mode = "step"
        SFX.play("menu_back")
        return
    end
    if #S.path == 0 then
        State.raw_input = false
        State.back(); return
    end
    local last = table.remove(S.path)
    S.step_id = last.step_id
    recompute_pending()
    S.sel = 1
    SFX.play("menu_back")
end

local function choose(opt)
    if not opt then return end
    accumulate(opt)
    table.insert(S.path, { step_id = S.step_id, option_key = opt.key })

    if opt.terminal or not opt.next then
        S.mode = "save"
        SFX.play("menu_select")
        return
    end
    S.step_id = opt.next
    S.sel = 1
    SFX.play("menu_move")
end

-- ── Save: core profile ──────────────────────────────────────
local function apply_pending_to_ini(parsed, target_kind, only_file)
    for _, chg in ipairs(S.pending) do
        local sec_name = namespaced_section(chg.section, target_kind)
        local belongs_to = SECTION_TO_FILE[canonical_section(chg.section)] or "Dolphin.ini"

        if target_kind == "gamesettings" then
            parsed.data[sec_name] = parsed.data[sec_name] or {}
            parsed.order[sec_name] = parsed.order[sec_name] or {}
            if parsed.data[sec_name][chg.key] == nil then
                table.insert(parsed.order[sec_name], chg.key)
            end
            parsed.data[sec_name][chg.key] = chg.val
        else
            if only_file == nil or only_file == belongs_to then
                parsed.data[sec_name] = parsed.data[sec_name] or {}
                parsed.order[sec_name] = parsed.order[sec_name] or {}
                if parsed.data[sec_name][chg.key] == nil then
                    table.insert(parsed.order[sec_name], chg.key)
                end
                parsed.data[sec_name][chg.key] = chg.val
            end
        end
    end
end

local function write_profile_core()
    local name = safe_profile_name(S.draft.name)
    if not name then
        Notify.show("error", "Invalid profile name")
        return false
    end
    S.draft.name = name

    local dir = "workshop/rtcoreprofile/" .. name
    local chk = io.open(dir .. "/rtprofile_data.ini", "r")
    if chk then
        chk:close()
        Notify.show("error", "Profile exists: " .. name)
        return false
    end
    os.execute("mkdir -p " .. shq(dir))

    local files = { "Dolphin.ini", "GFX.ini" }
    for _, fname in ipairs(files) do
        local base_path = "workshop/base/" .. fname
        local src = PMerger.parse_ini(base_path)
        if not src then
            Notify.show("error", "Missing base: " .. base_path)
            return false
        end
        apply_pending_to_ini(src, "rtcoreprofile", fname)
        PMerger.write_ini(dir .. "/" .. fname, src)
    end

    local mf = io.open(dir .. "/rtprofile_data.ini", "w")
    if mf then
        mf:write("[Profile]\n")
        mf:write("Name        = " .. name .. "\n")
        mf:write("Type        = Custom\n")
        mf:write("Description = " .. (S.draft.description or "") .. "\n")
        mf:write("Author      = Config Wizard\n")
        mf:write("Version     = 1.0.0\n")
        mf:write("Date        = " .. os.date("%Y-%m-%d") .. "\n\n")
        mf:write("[UI]\n")
        mf:write("Color       = #4FA8C7\n")
        mf:write("BorderStyle = rounded\n")
        mf:write("Icon        = balanced\n")
        mf:write("Order       = 200\n")
        mf:write("Tags        = custom, wizard\n\n")
        mf:write("[Runtime]\n")
        mf:write("Locked       = False\n")
        mf:close()
    end
    return true
end

local function write_profile_game()
    local id = S.draft.game_id
    if not id or id == "" then
        Notify.show("error", "No game selected")
        return false
    end
    local dir = "workshop/gamesettings/" .. id
    os.execute("mkdir -p " .. shq(dir))

    local parsed = { data = {}, order = {} }
    apply_pending_to_ini(parsed, "gamesettings", nil)
    PMerger.write_ini(dir .. "/" .. id .. ".ini", parsed)

    local mf = io.open(dir .. "/rtgameset_data.ini", "w")
    if mf then
        mf:write("[GameSettings]\n")
        mf:write("GameID      = " .. id .. "\n")
        mf:write("GameName    = " .. (S.draft.game_title or "") .. "\n")
        mf:write("System      = \n")
        mf:write("Region      = \n")
        mf:write("Description = " .. (S.draft.description or "") .. "\n")
        mf:write("Author      = Config Wizard\n")
        mf:write("Version     = 1.0.0\n\n")
        mf:write("[UI]\n")
        mf:write("Color       = #4CC850\n")
        mf:write("BorderStyle = rounded\n")
        mf:write("Icon        = save\n")
        mf:write("Order       = 10\n")
        mf:close()
    end
    return true
end

local function commit_save()
    local ok = false
    if S.draft.target_kind == "rtcoreprofile" then
        ok = write_profile_core()
    elseif S.draft.target_kind == "gamesettings" then
        ok = write_profile_game()
    end
    if ok then
        Notify.show("success", "Saved: " .. S.draft.name)
        pcall(function()
            local Chips = require("chips")
            if Chips and Chips.invalidate then Chips.invalidate() end
        end)
        State.raw_input = false
        State.back()
    end
end

-- ── Text input ──────────────────────────────────────────────
local function start_name_input()
    S.name_input = { field = "name", buffer = S.draft.name }
    SFX.play("menu_select")
end

local function start_desc_input()
    S.name_input = { field = "description", buffer = S.draft.description }
    SFX.play("menu_select")
end

local function commit_name_input()
    if not S.name_input then return end
    if S.name_input.field == "name" then
        S.draft.name = S.name_input.buffer
    elseif S.name_input.field == "description" then
        S.draft.description = S.name_input.buffer
    end
    S.name_input = nil
    SFX.play("menu_select")
end

-- ── Input ───────────────────────────────────────────────────
function S.pad(b)
    if S.name_input then
        if b == IM.A then commit_name_input()
        elseif b == IM.B then S.name_input = nil; SFX.play("menu_back") end
        return
    end

    if S.mode == "pick_game" then
        if b == IM.A then
            local list = {}
            for _, g in ipairs(State.roms or {}) do
                if not g.virtual then table.insert(list, g) end
            end
            local g = list[S.pick_sel]
            if g then
                S.draft.game_id    = g.id or
                    (g.file and g.file:match("%(([A-Z0-9]+)%)")) or ""
                S.draft.game_title = g.title or ""
                S.draft.description = "Per-game override for " ..
                    (g.title or "?")
                S.mode = "step"
                S.step_id = "goal"
                SFX.play("menu_select")
            end
        elseif b == IM.B then
            State.raw_input = false
            State.back()
        end
        return
    end

    if S.mode == "step" then
        local step = current_step()
        if b == IM.A and step and step.options then
            choose(step.options[S.sel])
        elseif b == IM.B then
            go_back()
        end
        return
    end

    if S.mode == "save" then
        if b == IM.A then commit_save()
        elseif b == IM.B then go_back()
        elseif b == IM.X then start_name_input()
        elseif b == IM.Y then start_desc_input() end
        return
    end
end

function S.hat(dir)
    if S.name_input then return end
    if S.mode == "pick_game" then
        local n = 0
        for _, g in ipairs(State.roms or {}) do
            if not g.virtual then n = n + 1 end
        end
        if dir == "up"   then
            S.pick_sel = math.max(1, S.pick_sel - 1); SFX.play("menu_move")
        elseif dir == "down" then
            S.pick_sel = math.min(n, S.pick_sel + 1); SFX.play("menu_move")
        end
        return
    end
    if S.mode == "step" then
        local step = current_step()
        if not step or not step.options then return end
        local n = #step.options
        if dir == "up" then
            S.sel = math.max(1, S.sel - 1); SFX.play("menu_move")
        elseif dir == "down" then
            S.sel = math.min(n, S.sel + 1); SFX.play("menu_move")
        end
    end
end

function S.key(k)
    if S.name_input then
        if k == "backspace" then
            S.name_input.buffer = S.name_input.buffer:sub(1, -2)
        elseif k == "return" then
            commit_name_input()
        elseif k == "escape" then
            S.name_input = nil
        elseif #k == 1 and k:match("[%w_%-%s%.]") then
            S.name_input.buffer = S.name_input.buffer .. k
        end
        return
    end
    if k == "up" then S.hat("up")
    elseif k == "down" then S.hat("down")
    elseif k == "return" or k == "space" then S.pad(IM.A)
    elseif k == "escape" then go_back()
    end
end

-- ── Rendering ───────────────────────────────────────────────
local function draw_step()
    local th = State.theme
    local step = current_step()
    if not step then
        love.graphics.setColor(th.text_dim)
        love.graphics.printf("(missing step)", 0, H/2, W, "center")
        return
    end

    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_title, 18))
    love.graphics.printf(step.prompt, 0, 78, W, "center")

    if #S.path > 0 then
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 9))
        local crumbs = {}
        for _, e in ipairs(S.path) do
            crumbs[#crumbs+1] = e.option_key
        end
        love.graphics.printf("> " .. table.concat(crumbs, " › "),
            0, 106, W, "center")
    end

    local y = 138
    for i, opt in ipairs(step.options or {}) do
        local focused = (i == S.sel)
        if focused then
            local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 4)
            D.glow(W/2, y + 22, 60, th.focus, 0.5 + pulse * 0.3)
        end
        love.graphics.setColor(focused and th.focus[1]*0.20 or 0.06,
                               focused and th.focus[2]*0.20 or 0.07,
                               focused and th.focus[3]*0.20 or 0.10, 0.95)
        love.graphics.rectangle("fill", 50, y, W - 100, 44, 4, 4)
        if focused then
            love.graphics.setColor(th.focus)
            love.graphics.rectangle("fill", 50, y, 3, 44, 1, 1)
        end

        love.graphics.setColor(focused and {1,1,1} or th.text)
        love.graphics.setFont(A.font(th.font_body_bold, 13))
        love.graphics.print(opt.label, 66, y + 5)

        if opt.desc and opt.desc ~= "" then
            love.graphics.setColor(th.text_dim)
            love.graphics.setFont(A.font(th.font_body, 10))
            love.graphics.print(opt.desc, 66, y + 24)
        end

        y = y + 52
    end
end

local function draw_picker()
    local th = State.theme
    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_title, 18))
    love.graphics.printf("Select the target game", 0, 78, W, "center")

    local visible = {}
    for _, g in ipairs(State.roms or {}) do
        if not g.virtual then table.insert(visible, g) end
    end

    local y = 120
    local max_show = 7
    local start_i = math.max(1, S.pick_sel - math.floor(max_show / 2))
    for i = start_i, math.min(#visible, start_i + max_show - 1) do
        local g = visible[i]
        local focused = (i == S.pick_sel)
        if focused then
            love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.18)
            love.graphics.rectangle("fill", 40, y - 2, W - 80, 26, 4, 4)
            love.graphics.setColor(th.focus)
            love.graphics.rectangle("fill", 40, y - 2, 3, 26, 1, 1)
        end
        love.graphics.setColor(focused and {1,1,1} or th.text)
        love.graphics.setFont(A.font(th.font_body_bold, 12))
        local title = g.title or g.file or "?"
        if #title > 48 then title = title:sub(1, 46) .. "…" end
        love.graphics.print(title, 56, y + 2)
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 9))
        love.graphics.printf(g.id or "—", 0, y + 4, W - 24, "right")
        y = y + 30
    end

    if #visible == 0 then
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 11))
        love.graphics.printf("No games in library.", 0, H/2, W, "center")
    end
end

local function draw_save()
    local th = State.theme
    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_title, 18))
    love.graphics.printf("Review and save", 0, 78, W, "center")

    love.graphics.setFont(A.font(th.font_body, 11))
    local y = 116
    local function row(label, value, col)
        love.graphics.setColor(th.text_dim)
        love.graphics.print(label, 60, y)
        love.graphics.setColor(col or th.text)
        love.graphics.print(value, 220, y)
        y = y + 18
    end

    row("Target kind", S.draft.target_kind)
    if S.draft.game_id and S.draft.game_id ~= "" then
        row("Game", S.draft.game_id .. " — " .. (S.draft.game_title or ""))
    end
    row("Name", S.draft.name, {0.85, 0.95, 1.0})
    row("Description", S.draft.description, {0.85, 0.95, 1.0})

    y = y + 10
    love.graphics.setColor(th.accent)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print("Changes to apply (" .. #S.pending .. "):", 60, y)
    y = y + 18
    love.graphics.setFont(A.font(th.font_body, 10))
    for _, a in ipairs(S.pending) do
        love.graphics.setColor(th.text_dim)
        love.graphics.print(a.section .. " / " .. a.key, 70, y)
        love.graphics.setColor({0.30, 0.85, 0.40})
        love.graphics.print("= " .. a.val, 380, y)
        y = y + 14
        if y > H - 80 then
            love.graphics.setColor(th.text_dim)
            love.graphics.print("... and more", 70, y)
            break
        end
    end
end

local function draw_name_input()
    local th = State.theme
    local bw, bh = 460, 130
    local bx, by = (W - bw)/2, (H - bh)/2
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setColor(0.06, 0.07, 0.10, 0.98)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
    love.graphics.setColor(th.focus)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print(
        (S.name_input.field == "name") and "PROFILE NAME" or "DESCRIPTION",
        bx + 20, by + 16)

    love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.12)
    love.graphics.rectangle("fill", bx + 16, by + 40, bw - 32, 34, 4, 4)
    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 14))
    local cursor = (math.floor((State.t_ui or 0) * 2) % 2 == 0) and "_" or " "
    love.graphics.print(S.name_input.buffer .. cursor, bx + 28, by + 48)

    BI.draw_hint_centered("[Enter] OK   [Esc] Cancel",
        W, by + bh + 8, A.font(th.font_body, 11), th)
end

function S.draw()
    local th = State.theme
    BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
    Header.draw("CONFIG WIZARD", "settings")

    if S.mode == "pick_game" then draw_picker()
    elseif S.mode == "save" then draw_save()
    else draw_step() end

    if S.name_input then
        draw_name_input()
    else
        local hint = "[↑↓] Navigate   [A] Select   [B] Back"
        if S.mode == "save" then
            hint = "[A] Save   [X] Name   [Y] Description   [B] Back"
        end
        BI.draw_hint_centered(hint, W, H - 22, A.font(th.font_body, 12), th)
    end

    Modal.draw()
end

return S