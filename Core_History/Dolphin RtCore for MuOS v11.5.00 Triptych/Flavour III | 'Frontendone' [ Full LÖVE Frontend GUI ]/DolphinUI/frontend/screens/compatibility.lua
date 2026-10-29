-- frontend/screens/compatibility.lua — Compatibility list from games_data.json
--
-- v0.9.0 — theme re-sync + smart sort
--   * S.update() now watches State.theme_name. When the theme flips
--     (SELECT) and the screen is not showing a filter_id, S.filter
--     is re-derived from the active theme and the list rebuilds.
--     Previously the user could flip to Wii and still see GC titles
--     because the screen was never notified.
--   * S.list sort: rating DESC, then fps_max DESC, then title ASC.
--     The entry chosen per game (see state.lua best_entry) also
--     breaks rating ties by fps_max. So the number shown on each
--     row is genuinely the best-reported result.
--   * All strings in English.

local A      = require("assets")
local SFX    = require("sfx")
local State  = require("state")
local IM     = require("input_map")
local D      = require("ui.draw")
local BG     = require("ui.bg")
local Header = require("ui.header")
local Icons  = require("ui.icons")
local BI     = require("ui.button_icons")
local GL     = require("ui.glyph")

local S = {}
local W, H = 640, 480

local TOP_Y      = Header.height() + 56
local BOTTOM_Y   = H - 44
local ROW_H      = 52
local POPUP_H    = 420
local PAGE_JUMP  = 10

S.filter     = "GC"
S.list       = {}
S.sel        = 1
S.scroll     = 0
S.detail     = nil
S.filter_id  = nil
S.search        = ""
S.search_active = false
S.jump_mode = "system"

S._stats   = { perfect=0, playable=0, issues=0, bad=0, dead=0 }
S._letters = {}

S.on_select = nil

local function refresh_raw_input()
    State.raw_input = (S.detail ~= nil) or (S.search_active == true)
end

local function set_detail(d)
    S.detail = d
    refresh_raw_input()
end

local function set_search(v)
    S.search_active = v
    refresh_raw_input()
end

local function sync_filter_to_theme()
    S.filter = (State.theme_name == "wii") and "Wii" or "GC"
end

-- ══════════════════════════════════════════════════════════════
--  Rating helpers
-- ══════════════════════════════════════════════════════════════
local function rating_color(r)
    r = tonumber(r) or 0
    if r >= 5 then return {0.25, 0.85, 0.40} end
    if r == 4 then return {0.60, 0.85, 0.30} end
    if r == 3 then return {0.96, 0.82, 0.22} end
    if r == 2 then return {0.98, 0.55, 0.22} end
    if r == 1 then return {0.95, 0.30, 0.20} end
    return {0.85, 0.12, 0.12}
end

local function rating_label(r)
    r = tonumber(r) or 0
    if r >= 5 then return "PERFECT" end
    if r == 4 then return "PLAYABLE" end
    if r == 3 then return "WITH ISSUES" end
    if r == 2 then return "UNPLAYABLE" end
    if r == 1 then return "BROKEN" end
    return "NO BOOT"
end

local function star_pts(cx, cy, r)
    local pts = {}
    for i = 0, 9 do
        local angle = -math.pi / 2 + i * math.pi / 5
        local rad = (i % 2 == 0) and r or (r * 0.42)
        pts[#pts + 1] = cx + math.cos(angle) * rad
        pts[#pts + 1] = cy + math.sin(angle) * rad
    end
    return pts
end

local function draw_star(cx, cy, r, col, fill)
    local pts = star_pts(cx, cy, r)
    if fill then
        love.graphics.setColor(col[1], col[2], col[3], 0.22)
        love.graphics.polygon("fill", pts)
    end
    love.graphics.setColor(col[1], col[2], col[3], 1)
    love.graphics.setLineWidth(1.6)
    love.graphics.polygon("line", pts)
    love.graphics.setLineWidth(1)
end

local function chamfer(mode, x, y, w, h, cut)
    cut = cut or 4
    love.graphics.polygon(mode,
        x + cut,     y,
        x + w - cut, y,
        x + w,       y + cut,
        x + w,       y + h - cut,
        x + w - cut, y + h,
        x + cut,     y + h,
        x,           y + h - cut,
        x,           y + cut)
end

local function draw_rating_badge(x, y, w, h, rating, focused, th)
    local r = tonumber(rating) or 0
    local c = rating_color(r)

    local cx = x + w / 2
    local cy = y + h / 2
    draw_star(cx, cy, math.min(w, h) * 0.46, c, true)

    local font = A.font(th.font_body_bold, 20)
    local text = tostring(r)
    local ty   = cy - font:getHeight() / 2
    GL.outlined_printf(
        text,
        x, ty, w,
        font,
        c,
        {0, 0, 0},
        1.8,
        "center",
        100 + r * 7)

    if focused then
        love.graphics.setColor(c[1], c[2], c[3], 0.55)
        love.graphics.setLineWidth(1.6)
        chamfer("line", x - 2, y - 2, w + 4, h + 4, 8)
        love.graphics.setLineWidth(1)
    end
end

-- ══════════════════════════════════════════════════════════════
--  Derived data
-- ══════════════════════════════════════════════════════════════
local function compute_stats()
    local b = { perfect = 0, playable = 0, issues = 0, bad = 0, dead = 0 }
    for _, g in ipairs(S.list) do
        local r = g.rating or 0
        if     r >= 5 then b.perfect  = b.perfect  + 1
        elseif r == 4 then b.playable = b.playable + 1
        elseif r == 3 then b.issues   = b.issues   + 1
        elseif r >= 1 then b.bad      = b.bad      + 1
        else               b.dead     = b.dead     + 1 end
    end
    S._stats = b
end

local function compute_letters()
    local seen, letters = {}, {}
    for _, g in ipairs(S.list) do
        local c = (g.game or "?"):sub(1, 1):upper()
        if c:match("[A-Z]") and not seen[c] then
            seen[c] = true
            letters[#letters + 1] = c
        end
    end
    table.sort(letters)
    S._letters = letters
end

-- ══════════════════════════════════════════════════════════════
--  List management
-- ══════════════════════════════════════════════════════════════
local function passes_search(g)
    if S.search == "" then return true end
    local q = S.search:lower()
    return (g.game or ""):lower():find(q, 1, true) ~= nil
        or (g.game_id or ""):lower():find(q, 1, true) ~= nil
        or (g.region or ""):lower():find(q, 1, true) ~= nil
end

local function rebuild_list()
    S.list = {}
    for _, g in pairs(State.games_data or {}) do
        local include = true
        if S.filter_id then
            include = (g.game_id == S.filter_id)
        else
            include = (g.system == S.filter)
        end
        if include and passes_search(g) then
            table.insert(S.list, g)
        end
    end
    -- Sort: rating DESC, then fps_max DESC, then title ASC.
    table.sort(S.list, function(a, b)
        local ra = tonumber(a.rating)  or 0
        local rb = tonumber(b.rating)  or 0
        if ra ~= rb then return ra > rb end
        local fa = tonumber(a.fps_max) or 0
        local fb = tonumber(b.fps_max) or 0
        if fa ~= fb then return fa > fb end
        return (a.game or ""):lower() < (b.game or ""):lower()
    end)
    S.sel = math.max(1, math.min(#S.list, S.sel or 1))
    S.scroll = 0
    compute_stats()
    compute_letters()
end

local function available_letters()
    return S._letters
end

function S.enter(params)
    set_detail(nil)
    S.search = ""
    set_search(false)
    S.jump_mode = "system"
    S.filter_id = params and params.filter_id or nil

    sync_filter_to_theme()
    if S.filter_id then
        local target = State.games_data[S.filter_id]
        if target then
            if target.system == "GC" or target.system == "Wii" then
                S.filter = target.system
            end
        end
    end
    rebuild_list()
    refresh_raw_input()
end

function S.leave()
    State.raw_input = false
end

function S.re_enter()
    if not S.filter_id then
        sync_filter_to_theme()
        rebuild_list()
    end
    refresh_raw_input()
end

local function scroll_to_sel()
    local vis_h = BOTTOM_Y - TOP_Y
    local top = (S.sel - 1) * ROW_H
    if top < S.scroll then S.scroll = top
    elseif top + ROW_H > S.scroll + vis_h then
        S.scroll = top + ROW_H - vis_h
    end
end

local function move(delta)
    local n = #S.list
    if n == 0 then return end
    local ni = math.max(1, math.min(n, S.sel + delta))
    if ni ~= S.sel then
        S.sel = ni
        SFX.play("menu_move")
        scroll_to_sel()
    end
end

local function page_jump(delta)
    local n = #S.list
    if n == 0 then return end
    local ni = math.max(1, math.min(n, S.sel + delta * PAGE_JUMP))
    if ni ~= S.sel then
        S.sel = ni
        SFX.play("menu_pagescroll")
        scroll_to_sel()
    end
end

local function letter_jump(delta)
    local letters = available_letters()
    if #letters == 0 then return end
    local cur_letter = "A"
    local cur_game = S.list[S.sel]
    if cur_game then cur_letter = (cur_game.game or "?"):sub(1, 1):upper() end
    local cur_idx = 1
    for i, l in ipairs(letters) do if l == cur_letter then cur_idx = i break end end
    if letters[cur_idx] ~= cur_letter then
        for i, l in ipairs(letters) do
            if l >= cur_letter then cur_idx = i break end
            cur_idx = i
        end
    end
    local target_idx = math.max(1, math.min(#letters, cur_idx + delta))
    if target_idx == cur_idx then return end
    local target_letter = letters[target_idx]
    for i, g in ipairs(S.list) do
        if (g.game or "?"):sub(1, 1):upper() == target_letter then
            S.sel = i
            SFX.play("menu_pagescroll")
            scroll_to_sel()
            return
        end
    end
end

local function jump_l1r1(delta)
    if S.filter_id then return end
    if S.jump_mode == "letter" then
        letter_jump(delta)
    end
end

local function open_detail()
    local g = S.list[S.sel]
    if not g then return end
    SFX.play("menu_select")
    set_detail({ game = g, t = 0, scroll = 0 })
end

local function close_detail()
    set_detail(nil)
    SFX.play("menu_back")
end

local function clear_filter_id()
    S.filter_id = nil
    sync_filter_to_theme()
    rebuild_list()
    SFX.play("menu_back")
end

local function open_search()
    S.search = ""
    S.jump_mode = "system"
    rebuild_list()
    set_search(true)
    SFX.play("menu_select")
end

local function close_search()
    S.search = ""
    rebuild_list()
    set_search(false)
    SFX.play("menu_back")
end

local function toggle_jump_mode()
    if S.filter_id then return end
    S.jump_mode = (S.jump_mode == "system") and "letter" or "system"
    SFX.play("menu_toggleoption")
end

-- ══════════════════════════════════════════════════════════════
--  Input
-- ══════════════════════════════════════════════════════════════
function S.pad(b)
    if S.search_active then
        if b == IM.A or b == IM.B then close_search() end
        return
    end
    if S.detail then
        if b == IM.B then close_detail() end
        return
    end
    if     b == IM.A     then open_detail()
    elseif b == IM.X     then open_search()
    elseif b == IM.L1    then jump_l1r1(-1)
    elseif b == IM.R1    then jump_l1r1(1)
    elseif b == IM.START then toggle_jump_mode()
    elseif b == IM.Y and S.filter_id then clear_filter_id() end
end

function S.hat(dir)
    if S.search_active then return end
    if S.detail then
        if dir == "up"   then
            S.detail.scroll = math.max(0, S.detail.scroll - 20)
        end
        if dir == "down" then S.detail.scroll = S.detail.scroll + 20 end
        return
    end
    if     dir == "up"    then move(-1)
    elseif dir == "down"  then move(1)
    elseif dir == "left"  then page_jump(-1)
    elseif dir == "right" then page_jump(1) end
end

function S.key(k)
    if S.search_active then
        if k == "backspace" then
            S.search = S.search:sub(1, -2)
            rebuild_list()
        elseif k == "return" or k == "escape" then
            close_search()
        elseif #k == 1 and k:match("[%w_%-%s%.]") then
            S.search = S.search .. k
            rebuild_list()
        end
        return
    end
    if S.detail then
        if     k == "up"   then S.detail.scroll = math.max(0, S.detail.scroll - 20)
        elseif k == "down" then S.detail.scroll = S.detail.scroll + 20
        elseif k == "escape" then close_detail() end
        return
    end
    if     k == "up"    then move(-1)
    elseif k == "down"  then move(1)
    elseif k == "left"  then page_jump(-1)
    elseif k == "right" then page_jump(1)
    elseif k == "x" or k == "f" then open_search()
    elseif k == "tab" then toggle_jump_mode()
    elseif k == "y" and S.filter_id then clear_filter_id()
    elseif k == "return" or k == "space" then open_detail() end
end

function S.update(dt)
    if S.detail then S.detail.t = S.detail.t + dt end

    -- Theme re-sync: if the user flips theme on this screen and we
    -- are not showing an explicit filter_id, rebuild the list from
    -- the active theme. Detects the change on every frame, cheap.
    if not S.filter_id then
        local want = (State.theme_name == "wii") and "Wii" or "GC"
        if S.filter ~= want then
            S.filter = want
            rebuild_list()
        end
    end

    refresh_raw_input()
end

-- ══════════════════════════════════════════════════════════════
--  Rendering: system indicator
-- ══════════════════════════════════════════════════════════════
local function draw_system_indicator(th)
    local y = Header.height() + 6
    local x = 20

    local sys = S.filter
    local col = (sys == "GC") and {0.55, 0.35, 0.95}
              or {0.20, 0.72, 0.98}
    local label = (sys == "GC") and "GAMECUBE" or "WII"

    local font = A.font(th.font_body_bold, 13)
    love.graphics.setFont(font)
    local w = font:getWidth(label) + 32

    love.graphics.setColor(col[1] * 0.45, col[2] * 0.45, col[3] * 0.45, 0.95)
    chamfer("fill", x, y, w, 28, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(label, x, y + 7, w, "center")
    love.graphics.setColor(col)
    chamfer("line", x, y, w, 28, 5)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.printf("[SELECT] flip system",
        0, y + 10, W - 20, "right")

    if S.filter_id then
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 10))
        love.graphics.printf(("[Y] clear filter: %s"):format(S.filter_id),
            0, y + 28, W - 20, "right")
    end
end

-- ══════════════════════════════════════════════════════════════
--  Rendering: stats bar
-- ══════════════════════════════════════════════════════════════
local function draw_stats_bar(th)
    local y = Header.height() + 42
    local h = 26
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, y, W, h)
    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
    love.graphics.rectangle("fill", 0, y, W, 1)

    local b = S._stats or { perfect=0, playable=0, issues=0, bad=0, dead=0 }

    local items = {
        { "5",   b.perfect,  {0.25, 0.85, 0.40} },
        { "4",   b.playable, {0.60, 0.85, 0.30} },
        { "3",   b.issues,   {0.96, 0.82, 0.22} },
        { "1-2", b.bad,      {0.95, 0.30, 0.20} },
        { "0",   b.dead,     {0.85, 0.12, 0.12} },
    }

    local x = 16
    local font = A.font(th.font_body_bold, 12)
    love.graphics.setFont(font)
    local star_r = 5
    for _, it in ipairs(items) do
        love.graphics.setColor(it[3])
        love.graphics.rectangle("fill", x, y + 7, 4, 12)

        draw_star(x + 10 + star_r, y + 13, star_r, it[3], false)

        local numfont = A.font(th.font_body_bold, 12)
        GL.outlined_print(
            tostring(it[1]),
            x + 10 + star_r * 2 + 4, y + 7,
            numfont,
            it[3], {0, 0, 0}, 1.4,
            50 + math.floor(it[2] * 13))

        x = x + 50

        love.graphics.setColor(0.85, 0.88, 0.95)
        love.graphics.setFont(font)
        love.graphics.print(tostring(it[2]), x, y + 7)
        x = x + 36
        love.graphics.setColor(0.35, 0.38, 0.45)
        love.graphics.rectangle("fill", x - 10, y + 7, 1, 12)
    end

    if S.jump_mode == "letter" and not S.filter_id and not S.search_active then
        local letters = S._letters
        if #letters > 0 then
            local cur = S.list[S.sel]
                and (S.list[S.sel].game or "?"):sub(1,1):upper() or "?"
            local pos = 0
            for i, l in ipairs(letters) do if l == cur then pos = i break end end
            love.graphics.setColor(th.accent)
            love.graphics.setFont(A.font(th.font_body_bold, 13))
            love.graphics.printf(
                string.format("LETTER %s  .  %d/%d", cur, pos, #letters),
                0, y + 5, W - 20, "right")
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  Rendering: list row
-- ══════════════════════════════════════════════════════════════
local function draw_row(g, x, y, w, focused, th)
    local c = rating_color(g.rating)
    local h = ROW_H - 4

    if focused then
        love.graphics.setColor(c[1], c[2], c[3], 0.14)
        chamfer("fill", x, y, w, h, 6)
        love.graphics.setColor(c[1], c[2], c[3], 0.95)
        love.graphics.rectangle("fill", x, y, 4, h, 1, 1)
    end

    local rb_w = 44
    local rb_h = h - 6
    draw_rating_badge(x + 8, y + 3, rb_w, rb_h, g.rating or 0, focused, th)

    local tx = x + 64
    love.graphics.setColor(focused and {1, 1, 1} or th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 14))
    local name = g.game or "?"
    if #name > 28 then name = name:sub(1, 26) .. "…" end
    love.graphics.print(name, tx, y + 6)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 11))
    local n_tests = g.report_count or (#(g.entries or {})) or 0
    local meta = string.format("%s . %s . %s",
        g.system or "?", g.region or "?", g.game_id or "?")
    love.graphics.print(meta, tx, y + 26)

    if n_tests > 0 then
        local font = A.font(th.font_body_bold, 9)
        love.graphics.setFont(font)
        local txt = (n_tests == 1) and "1 test" or (n_tests .. " tests")
        local tw = font:getWidth(txt) + 14
        local bx = tx + 180
        love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.28)
        chamfer("fill", bx, y + 25, tw, 16, 3)
        love.graphics.setColor(th.accent)
        chamfer("line", bx, y + 25, tw, 16, 3)
        love.graphics.printf(txt, bx, y + 28, tw, "center")
    end

    local fps = "N/A FPS"
    if g.fps_min and g.fps_min > 0 then
        fps = ("%d-%d FPS"):format(g.fps_min, g.fps_max)
    end
    local fps_col = (g.fps_min and g.fps_min > 0)
        and {0.20, 0.72, 0.98} or {0.55, 0.55, 0.62}
    local fps_font = A.font("assets/fonts/JetBrainsMono-Regular.ttf", 12)
    love.graphics.setFont(fps_font)
    local fps_w = fps_font:getWidth(fps) + 20
    local fps_x = x + w - fps_w - 10
    love.graphics.setColor(fps_col[1]*0.20, fps_col[2]*0.20, fps_col[3]*0.20, 1)
    chamfer("fill", fps_x, y + 6, fps_w, 20, 4)
    love.graphics.setColor(fps_col)
    chamfer("line", fps_x, y + 6, fps_w, 20, 4)
    love.graphics.printf(fps, fps_x, y + 10, fps_w, "center")

    local play_txt = g.playable or "?"
    if play_txt == "YES WITH ISSUES" then play_txt = "WITH ISSUES" end
    local play_col = (g.playable == "YES")
        and {0.30, 0.80, 0.40}
        or ((g.playable == "NO") and {0.90, 0.30, 0.30} or {0.96, 0.77, 0.26})
    local play_font = A.font(th.font_body_bold, 11)
    love.graphics.setFont(play_font)
    local play_w = play_font:getWidth(play_txt) + 20
    local play_x = x + w - play_w - 10
    love.graphics.setColor(play_col[1]*0.20, play_col[2]*0.20, play_col[3]*0.20, 1)
    chamfer("fill", play_x, y + 30, play_w, 18, 4)
    love.graphics.setColor(play_col)
    chamfer("line", play_x, y + 30, play_w, 18, 4)
    love.graphics.printf(play_txt, play_x, y + 33, play_w, "center")
end

-- ══════════════════════════════════════════════════════════════
--  Rendering: detail popup
-- ══════════════════════════════════════════════════════════════
local function draw_detail(th)
    local d = S.detail
    if not d then return end
    local g = d.game
    local c = rating_color(g.rating)
    local ease = math.min(1, d.t / 0.18)
    ease = 1 - (1 - ease) ^ 3
    love.graphics.setColor(0, 0, 0, 0.78 * ease)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local bw, bh = 600, POPUP_H
    local bx = (W - bw) / 2
    local by = (H - bh) / 2 + (1 - ease) * 30

    love.graphics.setColor(0.05, 0.06, 0.10, 0.98 * ease)
    love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
    love.graphics.setColor(c[1], c[2], c[3], 0.9 * ease)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)
    love.graphics.setLineWidth(1)
    D.corner_brackets(bx, by, bw, bh, c, 16)

    love.graphics.setColor(c[1], c[2], c[3], 0.20 * ease)
    love.graphics.rectangle("fill", bx, by, bw, 52, 8, 8)

    local sys = g.system or "?"
    local scol = (sys == "GC") and {0.55, 0.35, 0.95} or {0.20, 0.72, 0.98}
    love.graphics.setFont(A.font(th.font_body_bold, 12))
    local sysw = love.graphics.getFont():getWidth(sys) + 18
    love.graphics.setColor(scol[1], scol[2], scol[3], 0.9 * ease)
    chamfer("fill", bx + 14, by + 14, sysw, 24, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(sys, bx + 14, by + 18, sysw, "center")

    love.graphics.setFont(A.font(th.font_body, 11))
    local reg = g.region or "?"
    local regw = love.graphics.getFont():getWidth(reg) + 14
    love.graphics.setColor(0.20, 0.20, 0.25, 0.9 * ease)
    chamfer("fill", bx + 14 + sysw + 6, by + 16, regw, 20, 3)
    love.graphics.setColor(0.85, 0.85, 0.90)
    love.graphics.printf(reg, bx + 14 + sysw + 6, by + 20, regw, "center")

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(
        A.font("assets/fonts/JetBrainsMono-Regular.ttf", 11))
    love.graphics.print(g.game_id or "?", bx + 14 + sysw + 6 + regw + 10,
        by + 20)

    local badge_w = 44
    local badge_h = 40
    local badge_x = bx + bw - badge_w - 14
    local badge_y = by + 6
    draw_rating_badge(badge_x, badge_y, badge_w, badge_h, g.rating or 0,
        true, th)

    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_title, 18))
    love.graphics.printf(g.game or "?", bx + 20, by + 62, bw - 40, "center")

    love.graphics.setColor(c[1], c[2], c[3], 0.4 * ease)
    love.graphics.line(bx + 24, by + 92, bx + bw - 24, by + 92)

    local top = by + 100
    local bottom = by + bh - 44
    local clip_h = bottom - top
    love.graphics.setScissor(bx + 12, top, bw - 24, clip_h)
    local y = top - d.scroll

    love.graphics.setFont(A.font(th.font_body_bold, 15))
    love.graphics.setColor(c)
    love.graphics.print(rating_label(g.rating), bx + 24, y)
    y = y + 26

    local function data_row(label, value, value_col)
        love.graphics.setFont(A.font(th.font_body_bold, 11))
        love.graphics.setColor(th.text_dim)
        love.graphics.print(label, bx + 24, y)
        love.graphics.setFont(A.font(th.font_body, 13))
        love.graphics.setColor(value_col or {0.88, 0.90, 0.95})
        love.graphics.print(value, bx + 170, y)
        y = y + 20
    end

    local fps_txt = (g.fps_min and g.fps_min > 0)
        and ("%d - %d FPS"):format(g.fps_min, g.fps_max) or "N/A"
    data_row("FRAMERATE", fps_txt)
    data_row("BOOT", g.boot or "?",
        (g.boot == "YES") and {0.30, 0.80, 0.40} or {0.90, 0.30, 0.30})
    data_row("PLAYABLE", g.playable or "?",
        (g.playable == "YES") and {0.30, 0.80, 0.40}
          or ((g.playable == "NO") and {0.90, 0.30, 0.30}
            or {0.96, 0.77, 0.26}))

    y = y + 6

    if g.core_profile and g.core_profile ~= "" then
        data_row("PROFILE", g.core_profile)
    end
    if g.rtcore_version and g.rtcore_version ~= "" then
        data_row("RT:CORE", g.rtcore_version)
    end
    if g.tester and g.tester ~= "" then
        data_row("TESTED BY", g.tester)
    end
    if g.device and g.device ~= "" then
        data_row("DEVICE", g.device)
    end
    if g.muos_version and g.muos_version ~= "" then
        data_row("MUOS", g.muos_version)
    end

    y = y + 8

    if g.considerations and g.considerations ~= "" then
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body_bold, 11))
        love.graphics.print("NOTES", bx + 24, y); y = y + 18
        love.graphics.setColor(0.88, 0.90, 0.95)
        love.graphics.setFont(A.font(th.font_body, 12))
        love.graphics.printf(g.considerations, bx + 24, y, bw - 48, "left")
        local _, wrapped = love.graphics.getFont():getWrap(
            g.considerations, bw - 48)
        y = y + #wrapped * 16 + 14
    end

    local n_entries = #(g.entries or {})
    if n_entries > 1 then
        love.graphics.setColor(c[1], c[2], c[3], 0.9)
        love.graphics.setFont(A.font(th.font_body_bold, 11))
        love.graphics.print(("%d reports available"):format(n_entries),
            bx + 24, y)
        y = y + 16
    end

    love.graphics.setScissor()

    local total_h = (y - (top - d.scroll))
    if total_h > clip_h then
        local rail_x = bx + bw - 8
        love.graphics.setColor(0.30, 0.30, 0.35, 0.6)
        love.graphics.rectangle("fill", rail_x, top, 3, clip_h, 1, 1)
        local ratio = clip_h / total_h
        local bar_h = math.max(20, clip_h * ratio)
        local span = total_h - clip_h
        local bar_y = top + (span > 0 and (d.scroll / span) * (clip_h - bar_h)
          or 0)
        love.graphics.setColor(c)
        love.graphics.rectangle("fill", rail_x, bar_y, 3, bar_h, 1, 1)
    end

    local footer_y = by + bh - 34
    love.graphics.setColor(0, 0, 0, 0.4 * ease)
    love.graphics.rectangle("fill", bx, footer_y, bw, 34, 8, 8)
    BI.draw_hint_centered("[Up/Down] Scroll   [B] Close",
        W, footer_y + 6, A.font(th.font_body, 12), th)
end

-- ══════════════════════════════════════════════════════════════
--  Rendering: search overlay
-- ══════════════════════════════════════════════════════════════
local function draw_search_overlay(th)
    if not S.search_active then return end
    local bw, bh = 460, 100
    local bx = (W - bw) / 2
    local by = 60

    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setColor(0.06, 0.07, 0.10, 0.98)
    love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
    love.graphics.setColor(th.focus)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body_bold, 13))
    love.graphics.print("SEARCH", bx + 20, by + 12)

    love.graphics.setColor(th.focus[1], th.focus[2], th.focus[3], 0.12)
    love.graphics.rectangle("fill", bx + 16, by + 36, bw - 32, 36, 4, 4)
    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 16))
    local cursor = (math.floor((State.t_ui or 0) * 2) % 2 == 0) and "_" or " "
    love.graphics.print(S.search .. cursor, bx + 28, by + 45)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.printf(("%d match(es)"):format(#S.list),
        bx, by + bh - 20, bw, "center")

    BI.draw_hint_centered("[Enter] Close   [Esc] Close   [Backspace] Delete",
        W, by + bh + 12, A.font(th.font_body, 11), th)
end

-- ══════════════════════════════════════════════════════════════
--  Main draw
-- ══════════════════════════════════════════════════════════════
function S.draw()
    local th = State.theme
    BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
    Header.draw("COMPATIBILITY", "info")

    draw_system_indicator(th)
    draw_stats_bar(th)

    if #S.list == 0 then
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 13))
        local total = State.games_data_count or 0
        local msg
        if total == 0 then
            msg = "No compatibility data loaded.\n\n" ..
                  "games_data.json is missing or empty.\n" ..
                  "It is downloaded automatically on boot -\n" ..
                  "check data/logs/dolphinui.log for details."
        elseif S.search ~= "" then
            msg = ("No match for \"%s\""):format(S.search)
        else
            msg = ("No " .. S.filter .. " titles in the database.")
        end
        love.graphics.printf(msg, 0, H/2 - 30, W, "center")
        BI.draw_hint_centered("[X] Search   [SELECT] Flip system",
            W, H/2 + 50, A.font(th.font_body, 12), th)
    else
        love.graphics.setFont(A.font(th.font_body_bold, 11))
        love.graphics.setColor(0.55, 0.58, 0.68)
        love.graphics.print("RATING", 24, TOP_Y - 16)
        love.graphics.print("GAME", 84, TOP_Y - 16)
        love.graphics.printf("FPS  /  STATUS", 0, TOP_Y - 16, W - 20, "right")

        love.graphics.setScissor(0, TOP_Y, W, BOTTOM_Y - TOP_Y)
        local y = TOP_Y - S.scroll
        for i, g in ipairs(S.list) do
            if y + ROW_H >= TOP_Y and y <= BOTTOM_Y then
                draw_row(g, 20, y, W - 40, i == S.sel, th)
            end
            y = y + ROW_H
        end
        love.graphics.setScissor()

        local total_h = #S.list * ROW_H
        local vis_h = BOTTOM_Y - TOP_Y
        if total_h > vis_h then
            local rail_x = W - 6
            love.graphics.setColor(0.30, 0.30, 0.35, 0.55)
            love.graphics.rectangle("fill", rail_x, TOP_Y, 3, vis_h, 1, 1)
            local ratio = vis_h / total_h
            local bar_h = math.max(20, vis_h * ratio)
            local span = total_h - vis_h
            local bar_y = TOP_Y + (span > 0 and (S.scroll / span) * (vis_h - bar_h)
              or 0)
            love.graphics.setColor(th.accent)
            love.graphics.rectangle("fill", rail_x, bar_y, 3, bar_h, 1, 1)
        end
    end

    if S.detail then draw_detail(th) end
    draw_search_overlay(th)

    if not S.detail and not S.search_active then
        local items
        if S.filter_id then
            items = {
                { key = "dpad",  label = "Nav / Page" },
                { key = "x",     label = "Search"     },
                { key = "a",     label = "Details"    },
                { key = "y",     label = "Clear"      },
                { key = "b",     label = "Back"       },
            }
        elseif S.jump_mode == "letter" then
            items = {
                { key = "dpad",  label = "Nav / Page" },
                { key = "l1",    label = "Prev letter" },
                { key = "r1",    label = "Next letter" },
                { key = "start", label = "Mode"       },
                { key = "x",     label = "Search"     },
                { key = "a",     label = "Details"    },
                { key = "b",     label = "Back"       },
            }
        else
            items = {
                { key = "dpad",   label = "Nav / Page" },
                { key = "select", label = "Flip system" },
                { key = "start",  label = "Mode"       },
                { key = "x",      label = "Search"     },
                { key = "a",      label = "Details"    },
                { key = "b",      label = "Back"       },
            }
        end
        BI.draw_footer(th, items, W, H - 22, A.font(th.font_body, 12))
    end
end

return S
