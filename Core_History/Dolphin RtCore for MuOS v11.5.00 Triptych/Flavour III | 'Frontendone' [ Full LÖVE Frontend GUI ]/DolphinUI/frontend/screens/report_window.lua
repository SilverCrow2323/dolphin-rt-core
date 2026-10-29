-- screens/report_window.lua — Test Report window (New / Saved / Info).
--
-- New in this version:
--   * In the Saved tab, pressing [A] on a report loads it into the New tab
--     for editing. Saving creates a new report with a fresh ID.
--   * Pressing [X] on a report still deletes it (unchanged).
--
-- When a modal overlay is open (text input), State.raw_input = true so
-- main.lua routes ALL pad/key input here.
--
-- v0.5.1 — procedural rating stars
--   * The rating field used to print the U+2605 "★" glyph, which has
--     no coverage in Oxanium.ttf or GameCube.ttf: on device it
--     rendered as a white square. Stars are now drawn as 5-point
--     polygons, filled for achieved levels and outlined for the rest.

local A       = require("assets")
local SFX     = require("sfx")
local State   = require("state")
local IM      = require("input_map")
local D       = require("ui.draw")
local BG      = require("ui.bg")
local Header  = require("ui.header")
local Icons   = require("ui.icons")
local BI      = require("ui.button_icons")
local Notify  = require("notify")
local RS      = require("report_store")
local RG      = require("report_generator")
local Sys     = require("system_info")
local Modal   = require("modal")

local S = {}
local W, H = 640, 480

local TABS = { "New Report", "Saved Reports", "Info" }
S.tab       = 1
S.field     = 1
S.draft     = nil
S.saved     = {}
S.saved_sel = 1
S.input     = nil
S.editing_id = nil       -- if non-nil, we loaded this from a saved report

local FIELDS = {
    { key = "game_id",       label = "Game ID",         type = "text" },
    { key = "game_name",     label = "Game Name",       type = "text" },
    { key = "system",        label = "System",          type = "enum", values = {"GC", "Wii"} },
    { key = "region",        label = "Region",          type = "enum", values = {"PAL", "NTSC", "NTSC-J"} },
    { key = "rtcore",        label = "Rt:Core Version", type = "text" },
    { key = "profile",       label = "Core Profile",    type = "enum",
      values = {"Default", "Performance", "Compatibility", "Speedhack",
                "Sweet Spot", "Ultra", "Ultra Extreme", "Black Screen Fix"} },
    { key = "rating",        label = "Rating",          type = "range", min = 0, max = 5 },
    { key = "fps_min",       label = "FPS Min",         type = "range", min = 0, max = 60 },
    { key = "fps_max",       label = "FPS Max",         type = "range", min = 0, max = 60 },
    { key = "boot",          label = "Boot",            type = "enum", values = {"YES", "NO"} },
    { key = "playable",      label = "Playable",        type = "enum",
      values = {"YES", "YES WITH ISSUES", "NO"} },
    { key = "tester",        label = "Tester",          type = "text" },
    { key = "device",        label = "Device",          type = "text" },
    { key = "muos",          label = "muOS Version",    type = "text" },
    { key = "considerations",label = "Considerations",  type = "text" },
    { key = "_autofill",     label = "[ AUTO-DETECT ]", type = "action" },
    { key = "_loadlog",      label = "[ LOAD LAST LOG ]",type = "action" },
    { key = "_save",         label = "[ SAVE REPORT ]", type = "action" },
}

local function update_raw_input()
    State.raw_input = (S.input ~= nil)
end

local function get_draft()
    if not S.draft then S.draft = RS.empty() end
    return S.draft
end

local function draft_get(key)
    local d = get_draft()
    if key == "game_id"        then return d.game_info.game_id end
    if key == "game_name"      then return d.game_info.game end
    if key == "system"         then return d.game_info.system end
    if key == "region"         then return d.game_info.region end
    if key == "rtcore"         then return d.test_details.rtcore_version end
    if key == "profile"        then return d.test_details.core_profile end
    if key == "rating"         then return d.test_review.rating end
    if key == "fps_min"        then return d.test_review.fps_min end
    if key == "fps_max"        then return d.test_review.fps_max end
    if key == "boot"           then return d.test_review.boot end
    if key == "playable"       then return d.test_review.playable end
    if key == "tester"         then return d.test_environment.tester end
    if key == "device"         then return d.test_environment.device end
    if key == "muos"           then return d.test_environment.muos_version end
    if key == "considerations" then return d.test_details.considerations end
    return ""
end

local function draft_set(key, val)
    local d = get_draft()
    if     key == "game_id"        then d.game_info.game_id = val
    elseif key == "game_name"      then d.game_info.game = val
    elseif key == "system"         then d.game_info.system = val
    elseif key == "region"         then d.game_info.region = val
    elseif key == "rtcore"         then d.test_details.rtcore_version = val
    elseif key == "profile"        then d.test_details.core_profile = val
    elseif key == "rating"         then d.test_review.rating = val
    elseif key == "fps_min"        then d.test_review.fps_min = val
    elseif key == "fps_max"        then d.test_review.fps_max = val
    elseif key == "boot"           then d.test_review.boot = val
    elseif key == "playable"       then d.test_review.playable = val
    elseif key == "tester"         then d.test_environment.tester = val
    elseif key == "device"         then d.test_environment.device = val
    elseif key == "muos"           then d.test_environment.muos_version = val
    elseif key == "considerations" then d.test_details.considerations = val
    end
end

local TEXT_PRESETS = {
    game_id        = {"GZLP01", "GM8P01", "GALE01", "GZ3PB2", ""},
    game_name      = {"The Legend of Zelda: The Wind Waker",
                      "Metroid Prime", "Super Smash Bros. Melee",
                      "Dragon Ball Z Budokai 2", ""},
    rtcore         = {"v11.0.0 'Light Arsenal'", "v10.5.3",
                      "v10.6 (prerelease)", "v9 Goose or prior", ""},
    tester         = {"sirpips", "Sexy_Shrek", "SkullXavier", ""},
    device         = {"RG35XX H", "RG40XX H", "RG CubeXX", ""},
    muos           = {"2601.1 Funky Jacaranda", "2601.0 Jacaranda", ""},
    considerations = {"", "Auto-generate", "Manual edit"},
}

local function advance_field(field_idx, delta)
    local f = FIELDS[field_idx]
    if not f then return end
    local v = draft_get(f.key)

    if f.type == "range" then
        local nv = math.max(f.min, math.min(f.max, (tonumber(v) or 0) + delta))
        draft_set(f.key, nv)
        return
    end
    if f.type == "enum" then
        local idx = 1
        for i, val in ipairs(f.values) do
            if val == v then idx = i break end
        end
        idx = ((idx - 1 + delta) % #f.values) + 1
        draft_set(f.key, f.values[idx])
        return
    end
    if f.type == "text" then
        local list = TEXT_PRESETS[f.key] or {""}
        local idx = 1
        for i, val in ipairs(list) do
            if val == v then idx = i break end
        end
        idx = ((idx - 1 + delta) % #list) + 1
        draft_set(f.key, list[idx])
    end
end

local function open_text_input(field_idx)
    local f = FIELDS[field_idx]
    if not f or f.type ~= "text" then return end
    S.input = {
        target = { key = f.key },
        buffer = tostring(draft_get(f.key) or ""),
        label  = f.label,
    }
    update_raw_input()
    SFX.play("menu_select")
end

-- ── Load a saved report into draft ──────────────────────────
local function load_report_into_draft(rep)
    if not rep then return end
    -- Deep-copy relevant fields
    local d = RS.empty()
    d.game_info      = {}
    d.test_review    = {}
    d.test_details   = {}
    d.test_environment = {}
    d._extended      = {}

    for k, v in pairs(rep.game_info or {})        do d.game_info[k] = v end
    for k, v in pairs(rep.test_review or {})      do d.test_review[k] = v end
    for k, v in pairs(rep.test_details or {})     do d.test_details[k] = v end
    for k, v in pairs(rep.test_environment or {}) do d.test_environment[k] = v end
    for k, v in pairs(rep._extended or {})        do d._extended[k] = v end

    S.draft = d
    S.editing_id = rep._meta and rep._meta.id or nil
    S.tab   = 1
    S.field = 1

    Notify.show("info", "Loaded: " .. (S.editing_id or "?"))
    SFX.play("menu_select")
end

-- ── Actions ─────────────────────────────────────────────────
local function autofill_system_info()
    local sys = Sys.snapshot()
    local d = get_draft()
    if sys.muos   and sys.muos   ~= "" then d.test_environment.muos_version = sys.muos end
    if sys.device and sys.device ~= "" then d.test_environment.device     = sys.device end
    if sys.tester and sys.tester ~= "" then d.test_environment.tester     = sys.tester end
    Notify.show("success", "System info auto-detected")
end

local function load_last_log()
    local path = Sys.latest_session_log()
    if not path then Notify.show("warning", "No session log found"); return end
    local parsed = Sys.parse_session_log(path)
    if not parsed then Notify.show("error", "Cannot parse log"); return end

    local d = get_draft()
    if d.game_info.game_id == "" or d.game_info.game_id == "RVZ" then
        local rom_base = (parsed.rom_path or ""):match("([^/]+)$") or ""
        local id_from_name = rom_base:match("%(([A-Z][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])%)")
        if id_from_name then
            d.game_info.game_id = id_from_name
        elseif parsed.game_id_log
           and parsed.game_id_log ~= "RVZ"
           and parsed.game_id_log ~= "UNKNOWN" then
            d.game_info.game_id = parsed.game_id_log
        end
    end
    if parsed.game_name and parsed.game_name ~= "" then
        d.game_info.game = parsed.game_name:gsub("%s*%(.+$", "")
    end
    if parsed.core and parsed.core ~= "" then
        local s = parsed.core:lower()
        if     s:match("performance")   then d.test_details.core_profile = "Performance"
        elseif s:match("compatibility") then d.test_details.core_profile = "Compatibility"
        elseif s:match("rintromping")   then d.test_details.core_profile = "Ultra"
        elseif s:match("sweetspot")     then d.test_details.core_profile = "Sweet Spot"
        elseif s:match("speedhack")     then d.test_details.core_profile = "Speedhack"
        elseif s:match("blackscreen")   then d.test_details.core_profile = "Black Screen Fix"
        else d.test_details.core_profile = "Default" end
    end
    if parsed.dolphin_line and parsed.dolphin_line ~= "" then
        d.test_details.rtcore_version =
            (d.test_details.rtcore_version ~= "" and d.test_details.rtcore_version)
            or "v11.0.0 'Light Arsenal'"
    end

    d._extended = d._extended or {}
    d._extended.session_log_path = parsed.path
    d._extended.session_log_name = parsed.name
    d._extended.exit_code        = parsed.exit_code
    d._extended.crash_signal     = parsed.crash_signal
    d._extended.dolphin_line     = parsed.dolphin_line
    d._extended.tail             = parsed.tail
    d._extended.start_date       = parsed.start_date

    if parsed.exit_code == 0 then
        d.test_review.boot = "YES"
    elseif parsed.exit_code == 134 or parsed.exit_code == 139 then
        d.test_review.boot = "YES"
        d.test_review.playable = "NO"
        d.test_review.rating = 1
    elseif parsed.exit_code == 143 then
        d.test_review.boot = "YES"
    end

    Notify.show("success", "Loaded: " .. parsed.name)
end

local function auto_generate()
    local d = get_draft()
    d.test_details.considerations = RG.generate(d)
    Notify.show("success", "Considerations auto-generated")
end

local function save_report()
    local d = get_draft()
    if d.game_info.game_id == "" then
        Notify.show("error", "Game ID is required")
        return
    end
    if d.test_details.considerations == "" then auto_generate() end
    local ext = d._extended or {}
    if ext.exit_code and ext.exit_code ~= 0 then
        d.test_details.considerations = d.test_details.considerations ..
            " Emulator exited with code " .. tostring(ext.exit_code) .. "."
    end
    -- Clear meta so a new ID is generated (editing creates a new copy)
    d._meta = {}
    if RS.save(d) then
        Notify.show("success", "Report saved: " .. d._meta.id)
        S.draft = RS.empty()
        S.field = 1
        S.editing_id = nil
        S.saved = RS.list()
    else
        Notify.show("error", "Save failed")
    end
end

function S.enter()
    S.tab       = 1
    S.field     = 1
    S.input     = nil
    S.draft     = RS.empty()
    S.saved     = RS.list()
    S.saved_sel = 1
    S.editing_id = nil
    update_raw_input()

    local sys = Sys.snapshot()
    local d = S.draft
    if sys.muos   and sys.muos   ~= "" then d.test_environment.muos_version = sys.muos end
    if sys.device and sys.device ~= "" then d.test_environment.device     = sys.device end
    if sys.tester and sys.tester ~= "" then d.test_environment.tester     = sys.tester end

    local ov = io.open("/opt/muos/share/emulator/dolphin/rtdata/logs/overview.log", "r")
    if ov then
        local content = ov:read("*a"); ov:close()
        local ver = content:match("Dolphin Rt:Core%s+(v[^%s]+)")
        if ver then d.test_details.rtcore_version = ver .. " 'Light Arsenal'" end
    end
    if d.test_details.rtcore_version == "" then
        d.test_details.rtcore_version = "v11.0.0 'Light Arsenal'"
    end
end

local function next_tab(delta)
    S.tab = ((S.tab - 1 + delta) % #TABS) + 1
    SFX.play("menu_pagescroll")
end

local function move(delta)
    if S.tab == 1 then
        S.field = math.max(1, math.min(#FIELDS, S.field + delta))
        SFX.play("menu_move")
    elseif S.tab == 2 then
        local n = #S.saved
        if n == 0 then return end
        S.saved_sel = math.max(1, math.min(n, S.saved_sel + delta))
        SFX.play("menu_move")
    end
end

function S.pad(b)
    if S.input then
        if b == IM.A then
            draft_set(S.input.target.key, S.input.buffer)
            S.input = nil
            update_raw_input()
            SFX.play("menu_select")
        elseif b == IM.B then
            S.input = nil
            update_raw_input()
            SFX.play("menu_back")
        end
        return
    end

    if b == IM.L1 then next_tab(-1)
    elseif b == IM.R1 then next_tab(1)
    elseif b == IM.A then
        if S.tab == 1 then
            local f = FIELDS[S.field]
            if     f.key == "_save"     then save_report()
            elseif f.key == "_autofill" then autofill_system_info()
            elseif f.key == "_loadlog"  then load_last_log()
            elseif f.key == "considerations" then auto_generate()
            else advance_field(S.field, 1) end
        elseif S.tab == 2 then
            local rep = S.saved[S.saved_sel]
            if rep then
                -- Load into draft (edit mode)
                load_report_into_draft(rep)
            end
        end
    elseif b == IM.X then
        if S.tab == 1 then
            local f = FIELDS[S.field]
            if f.type == "text" then
                open_text_input(S.field)
            elseif f.type ~= "action" then
                advance_field(S.field, -1)
            end
        elseif S.tab == 2 then
            -- Delete report
            local rep = S.saved[S.saved_sel]
            if rep then
                Modal.show("Delete report?",
                    (rep._meta and rep._meta.id or "?") ..
                    "\n\nThis cannot be undone.",
                    {
                        accept_label = "Delete",
                        color = {0.90, 0.30, 0.30},
                        on_accept = function()
                            RS.delete(rep._meta.id)
                            Notify.show("info", "Deleted: " .. rep._meta.id)
                            S.saved = RS.list()
                            S.saved_sel = 1
                        end,
                    })
            end
        end
    elseif b == IM.Y then
        -- Clear draft (New Report only)
        if S.tab == 1 then
            S.draft = RS.empty()
            S.editing_id = nil
            Notify.show("info", "Draft cleared")
        end
    elseif b == IM.B then
        State.back()
    end
end

function S.hat(dir)
    if S.input then return end
    if     dir == "up"    then move(-1)
    elseif dir == "down"  then move(1)
    elseif dir == "left"  then next_tab(-1)
    elseif dir == "right" then next_tab(1) end
end

function S.key(k)
    if S.input then
        if k == "backspace" then
            S.input.buffer = S.input.buffer:sub(1, -2)
        elseif k == "return" then
            draft_set(S.input.target.key, S.input.buffer)
            S.input = nil
            update_raw_input()
            SFX.play("menu_select")
        elseif k == "escape" then
            S.input = nil
            update_raw_input()
        elseif #k == 1 and k:match("[%w_%-%s%./:]") then
            S.input.buffer = S.input.buffer .. k
        end
        return
    end

    if     k == "up"    then move(-1)
    elseif k == "down"  then move(1)
    elseif k == "left"  then next_tab(-1)
    elseif k == "right" then next_tab(1)
    elseif k == "return" or k == "space" then S.pad(IM.A)
    elseif k == "escape" then State.back() end
end

function S.update(dt) end

-- ── Rendering ───────────────────────────────────────────────
local function draw_tabs(th)
    local x = 20
    local y = 58
    for i, t in ipairs(TABS) do
        local font = A.font(th.font_body_bold, 11)
        local w = font:getWidth(t) + 24
        local active = (i == S.tab)
        love.graphics.setColor(
            active and th.focus[1]*0.3 or 0.08,
            active and th.focus[2]*0.3 or 0.09,
            active and th.focus[3]*0.3 or 0.12, 0.95)
        love.graphics.rectangle("fill", x, y, w, 24, 4, 4)
        love.graphics.setColor(active and {1,1,1} or th.text_dim)
        love.graphics.setFont(font)
        love.graphics.printf(t, x, y + 5, w, "center")
        if active then
            love.graphics.setColor(th.focus)
            D.rough_rect(x, y, w, 24,
                { jitter = 0.6, thickness = 1.5, seed = i*7 })
            D.corner_brackets(x, y, w, 24, th.focus, 5)
        end
        x = x + w + 6
    end

    if S.editing_id then
        love.graphics.setColor(0.96, 0.77, 0.26, 0.85)
        love.graphics.setFont(A.font(th.font_body_bold, 10))
        love.graphics.printf("EDIT MODE  ·  src: " .. S.editing_id,
            0, y + 6, W - 20, "right")
    end
end

-- Small procedural 5-point star. ★ (U+2605) has no glyph in
-- Oxanium.ttf or GameCube.ttf, so the previous printf("★") rendered
-- as a white square on device. Same polygon used by compatibility.lua.
local function draw_star(cx, cy, r, col, filled)
    local pts = {}
    for i = 0, 9 do
        local angle = -math.pi / 2 + i * math.pi / 5
        local rad = (i % 2 == 0) and r or (r * 0.42)
        pts[#pts + 1] = cx + math.cos(angle) * rad
        pts[#pts + 1] = cy + math.sin(angle) * rad
    end
    if filled then
        love.graphics.setColor(col[1], col[2], col[3], 0.25)
        love.graphics.polygon("fill", pts)
    end
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.setLineWidth(1.4)
    love.graphics.polygon("line", pts)
    love.graphics.setLineWidth(1)
end

local function draw_new(th)
    local y = 98
    local label_x = 24
    local value_x = 210
    local font = A.font(th.font_body, 11)

    love.graphics.setFont(font)
    for i, f in ipairs(FIELDS) do
        local focused = (i == S.field)
        local v = draft_get(f.key)

        if focused then
            love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.15)
            love.graphics.rectangle("fill", 16, y - 2, W - 32, 22, 3, 3)
            love.graphics.setColor(th.focus)
            love.graphics.rectangle("fill", 16, y - 2, 3, 22, 1, 1)
        end

        love.graphics.setColor(0.60, 0.60, 0.75)
        love.graphics.print(f.label, label_x, y + 2)

        if f.key == "_save" then
            love.graphics.setColor(focused and {0.30,0.90,0.45} or {0.30,0.70,0.40})
            love.graphics.setFont(A.font(th.font_body_bold, 11))
            love.graphics.print(f.label, label_x, y + 2)
            love.graphics.setFont(font)
        elseif f.type == "range" then
            if f.key == "rating" then
                local n = tonumber(v) or 0
                -- Procedural stars: filled = achieved, outlined = remaining.
                -- Replaces the old ★ glyph which has no font coverage.
                for s = 1, 5 do
                    local col = (s <= n)
                        and {0.96, 0.77, 0.26}
                        or  {0.45, 0.45, 0.50}
                    draw_star(value_x + (s - 1) * 14 + 6, y + 10, 5,
                              col, s <= n)
                end
            else
                love.graphics.setColor(focused and {1,1,1} or th.text)
                love.graphics.print(tostring(v or 0), value_x, y + 2)
            end
        elseif f.type == "enum" then
            love.graphics.setColor(focused and {1,1,1} or th.text)
            love.graphics.print(tostring(v or ""), value_x, y + 2)
        elseif f.type == "action" then
            -- no-op
        else
            local is_empty = (v == "")
            if is_empty and f.key ~= "considerations" then
                love.graphics.setColor(0.45, 0.45, 0.50)
                love.graphics.setFont(A.font("assets/fonts/Oxanium-Regular.ttf", 11))
                love.graphics.print("(empty)", value_x, y + 2)
                love.graphics.setFont(font)
            else
                love.graphics.setColor(focused and {1,1,1} or th.text)
                local disp = v
                if f.key == "considerations" and #disp > 55 then
                    disp = disp:sub(1, 52) .. "..."
                end
                love.graphics.print(disp, value_x, y + 2)
            end
        end

        y = y + 22
        if y > H - 60 then break end
    end
end

local function draw_saved(th)
    if #S.saved == 0 then
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 12))
        love.graphics.printf(
            "No saved reports yet.\n\nCreate one from the New Report tab.",
            0, 220, W, "center")
        return
    end
    local y = 96
    local t = State.t_ui or 0
    for i, rep in ipairs(S.saved) do
        local focused = (i == S.saved_sel)
        local g = rep.game_info or {}
        local tr = rep.test_review or {}
        local x, w, h = 20, W - 40, 44
        local c = {0.30, 0.80, 0.60}

        if focused then
            local pulse = 0.5 + 0.5 * math.sin(t * 4)
            D.glow(x + w/2, y + h/2, 50, c, 0.7 + pulse * 0.2)
        end
        love.graphics.setColor(
            focused and c[1]*0.32 or c[1]*0.12,
            focused and c[2]*0.32 or c[2]*0.12,
            focused and c[3]*0.32 or c[3]*0.12, 0.95)
        love.graphics.rectangle("fill", x, y, w, h, 3, 3)

        love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.55)
        love.graphics.rectangle("fill", x, y, 3, h)

        love.graphics.setColor(c)
        D.rough_rect(x, y, w, h,
            { jitter = focused and 1.2 or 0.7,
              thickness = focused and 2 or 1.2, seed = i * 11 })

        love.graphics.setColor(focused and {1,1,1} or th.text)
        love.graphics.setFont(A.font(th.font_body_bold, 12))
        love.graphics.print((g.game_id or "?") .. "  " .. (g.game or ""), x + 14, y + 6)

        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 9))
        love.graphics.print(
            string.format("%s  ·  FPS %d-%d  ·  %s  ·  %s",
                g.region or "?",
                tonumber(tr.fps_min) or 0,
                tonumber(tr.fps_max) or 0,
                tr.boot or "?",
                tr.playable or "?"),
            x + 14, y + 24)

        y = y + h + 6
        if y > H - 40 then break end
    end
end

local function draw_info(th)
    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_title, 15))
    love.graphics.print("Test Report", 24, 96)

    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.setColor(th.text_dim)
    local lines = {
        "The Test Report system lets you document a game session",
        "and generate a compatibility entry compatible with the",
        "community database used on the SPDW Factory Lab website.",
        "",
        "Fields mirror the games_data.json schema so reports",
        "can be shared or merged into the master database.",
        "",
        "Reports are saved in data/reports/ as individual JSON files.",
        "Use [A] on the New Report tab to fill in the form.",
        "Use [X] on a text field to type a custom value.",
        "Use [A] on a Saved Report to load it into the editor.",
        "Use [X] on a Saved Report to delete it.",
        "Use [Y] on the New Report tab to clear the draft.",
    }
    local y = 130
    for _, l in ipairs(lines) do
        love.graphics.print(l, 24, y)
        y = y + 14
    end
end

local function draw_input_overlay(th)
    local bw, bh = 460, 130
    local bx = (W - bw) / 2
    local by = (H - bh) / 2

    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setColor(0.06, 0.07, 0.10, 0.98)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
    love.graphics.setColor(th.focus)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print(S.input.label or "Value", bx + 20, by + 16)

    love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.12)
    love.graphics.rectangle("fill", bx + 16, by + 40, bw - 32, 34, 4, 4)
    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 14))
    local cursor = (math.floor((State.t_ui or 0) * 2) % 2 == 0) and "_" or " "
    love.graphics.print(S.input.buffer .. cursor, bx + 28, by + 48)

    BI.draw_hint_centered("[Enter] OK   [Esc] Cancel",
        W, by + bh + 8, A.font(th.font_body, 11), th)
end

function S.draw()
    local th = State.theme
    BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
    Header.draw("TEST REPORT", "save")
    draw_tabs(th)

    if     S.tab == 1 then draw_new(th)
    elseif S.tab == 2 then draw_saved(th)
    elseif S.tab == 3 then draw_info(th) end

    if S.input then draw_input_overlay(th) end

    if not S.input then
        local hints
        if S.tab == 1 then
            hints = "[L1/R1] Tab   [↑↓] Field   [A] Cycle   [X] Edit   [Y] Clear   [B] Back"
        elseif S.tab == 2 then
            hints = "[L1/R1] Tab   [↑↓] Select   [A] Load   [X] Delete   [B] Back"
        else
            hints = "[L1/R1] Tab   [B] Back"
        end
        BI.draw_hint_centered(hints, W, H - 22, A.font(th.font_body, 12), th)
    end

    Modal.draw()
end

return S