-- frontend/screens/library.lua — Game library grid.
-- 5x2 grid per page, filter cycle AUTO / GC / WII / ALL.
--
-- v0.6.0 — visual-space navigation
--   * focus_lib.x is a VISUAL column index (0 = left edge of the
--     screen, COLS-1 = right edge). The D-pad moves the cursor in
--     VISUAL space regardless of the mirror flag, so pressing LEFT
--     always moves the cursor visually left, RIGHT always right.
--     The old code inverted dx when grid_mirror was true, which
--     made D-pad feel "swapped" on the Wii theme.
--   * On theme flip (auto filter changes GC <-> Wii), the cursor
--     resets to the first item of the new list: GC -> visual (0,0)
--     top-left; Wii -> visual (COLS-1, 0) top-right. The reset is
--     detected in update() via a cached resolved filter, so it also
--     works when the user flips theme while the screen is running.
--   * Empty slots at the end of a page are never focused: navigate()
--     rejects moves that would land on a slot >= the number of
--     remaining items on the current page.
--   * Cover resolution batched in update(), not draw().

local A        = require("assets")
local SFX      = require("sfx")
local State    = require("state")
local IM       = require("input_map")
local D        = require("ui.draw")
local BG       = require("ui.bg")
local Header   = require("ui.header")
local Icons    = require("ui.icons")
local Chips    = require("chips")
local Modal    = require("modal")
local Launcher = require("launcher")
local Covers   = require("covers")
local BI       = require("ui.button_icons")

local S = {}
local W, H = 640, 480

local COLS, ROWS = 5, 2
local CW, CH, PAD = 110, 118, 8
local GRID_X, GRID_Y = 20, 100
local CHIPS_Y = 56
local PAGE_Y  = 84

local STRIP_Y = H - 62
local STRIP_H = 22
local FOOTER_CENTER = H - 22

-- ── Compat memoization ──────────────────────────────────────
local function get_compat(rom)
    if rom == nil then return nil end
    if rom._compat_lookup_done then
        return rom._compat_result
    end
    rom._compat_lookup_done = true
    rom._compat_result = State.find_compat and State.find_compat(rom) or nil
    return rom._compat_result
end

-- ── Filter cycle ────────────────────────────────────────────
S.filter = nil
S.view_mode = "grid"   -- grid | list | compact
local FILTER_CYCLE = { nil, "GC", "Wii", "ALL" }

local function filter_label()
    if S.filter == nil then
        return "AUTO:" .. ((State.theme_name == "wii") and "WII" or "GC")
    end
    return S.filter
end

local function resolve_filter()
    if S.filter ~= nil then return S.filter end
    return (State.theme_name == "wii") and "Wii" or "GC"
end

local function filtered()
    local f = resolve_filter()
    local out = {}
    if f == "ALL" then
        for _, g in ipairs(State.roms) do out[#out + 1] = g end
        return out
    end
    for _, g in ipairs(State.roms) do
        if g.sys == f then out[#out + 1] = g end
    end
    return out
end

local _frame_list   = nil
local _frame_tested = nil

local function list_for_frame()
    return _frame_list or filtered()
end

local function total_pages_for(list)
    return math.max(1, math.ceil(#list / State.PAGE_LIB))
end

local function page_offset()
    return (State.page_lib - 1) * State.PAGE_LIB
end

-- ══════════════════════════════════════════════════════════════
--  Focus helpers — VISUAL coordinate system
-- ══════════════════════════════════════════════════════════════
local function mirrored()
    return State.theme and State.theme.grid_mirror == true
end

-- Convert a visual column to a data column index.
local function visual_to_data_col(vcol)
    if mirrored() then return COLS - 1 - vcol end
    return vcol
end

local function focus_slot_index(fx, fy)
    local data_col = visual_to_data_col(fx)
    return fy * COLS + data_col
end

local function focus_is_valid(fx, fy)
    local list = list_for_frame()
    local total = #list - page_offset()
    if total <= 0 then return false end
    local slot = focus_slot_index(fx, fy)
    return slot < total
end

-- Reset focus to the first data slot, positioned correctly for the
-- current theme. GC -> visual top-left; Wii -> visual top-right.
local function reset_focus_first_item()
    State.focus_lib.x = mirrored() and (COLS - 1) or 0
    State.focus_lib.y = 0
end

local function clamp_focus()
    local list = list_for_frame()
    local total = #list - page_offset()
    if total <= 0 then
        State.focus_lib.x, State.focus_lib.y = 0, 0
        return
    end
    if not focus_is_valid(State.focus_lib.x, State.focus_lib.y) then
        reset_focus_first_item()
    end
end

-- ══════════════════════════════════════════════════════════════
--  Navigation (visual space)
-- ══════════════════════════════════════════════════════════════
local function navigate(dx, dy)
    local fx, fy = State.focus_lib.x, State.focus_lib.y
    local nx = math.max(0, math.min(COLS - 1, fx + dx))
    local ny = math.max(0, math.min(ROWS - 1, fy + dy))

    if nx == fx and ny == fy then return end
    if not focus_is_valid(nx, ny) then return end

    State.focus_lib.x, State.focus_lib.y = nx, ny
    SFX.play("menu_move")
end

local function change_page(d)
    local np = math.max(1, math.min(
        total_pages_for(list_for_frame()),
        State.page_lib + d))
    if np ~= State.page_lib then
        State.page_lib = np
        reset_focus_first_item()
        SFX.play("menu_pagescroll")
    end
end

local function cycle_filter()
    local cur = 1
    for i, v in ipairs(FILTER_CYCLE) do
        if v == S.filter then cur = i break end
    end
    cur = (cur % #FILTER_CYCLE) + 1
    S.filter = FILTER_CYCLE[cur]
    State.page_lib = 1
    _frame_list   = filtered()
    _frame_tested = nil
    reset_focus_first_item()
    SFX.play("menu_pagescroll")
end

local function focused_game()
    local list = list_for_frame()
    local slot = focus_slot_index(State.focus_lib.x, State.focus_lib.y)
    return list[page_offset() + slot + 1]
end

local function open_detail()
    local g = focused_game()
    if g then
        SFX.play("menu_select")
        State.go("game_detail", g)
    end
end

local function quick_launch()
    local g = focused_game()
    if g then Launcher.launch(g) end
end

-- ══════════════════════════════════════════════════════════════
--  Cover resolution
-- ══════════════════════════════════════════════════════════════
local function resolve_covers_batch()
    if not State.roms then return end
    local budget = 20
    local n = 0
    for _, g in ipairs(State.roms) do
        if not g._cover_resolved then
            g._cover_path = Covers.resolve(g)
            g._cover_resolved = true
            n = n + 1
            if n >= budget then return end
        end
    end
end

local function invalidate_cover_cache()
    for _, g in ipairs(State.roms or {}) do
        g._cover_resolved = nil
        g._cover_path     = nil
    end
end

-- ══════════════════════════════════════════════════════════════
--  Lifecycle
-- ══════════════════════════════════════════════════════════════
S._last_resolved = nil


local VIEWS = { "grid", "list", "compact" }
local function cycle_view_mode()
    local idx = 1
    for i, v in ipairs(VIEWS) do if v == S.view_mode then idx = i break end end
    idx = (idx % #VIEWS) + 1
    S.view_mode = VIEWS[idx]
    reset_focus_first_item()
    SFX.play("menu_pagescroll")
end

function S.enter()
    S.filter = S.filter or nil
    _frame_list   = filtered()
    _frame_tested = nil
    S._last_resolved = resolve_filter()
    State.page_lib = math.max(1, math.min(
        total_pages_for(_frame_list), State.page_lib or 1))
    reset_focus_first_item()
    invalidate_cover_cache()
end

function S.re_enter()
    _frame_list   = filtered()
    _frame_tested = nil
    S._last_resolved = resolve_filter()
    clamp_focus()
end

function S.pad(b)
    if     b == IM.L1 then change_page(-1)
    elseif b == IM.R1 then change_page( 1)
    elseif b == IM.A  then open_detail()
    elseif b == IM.Y  then cycle_filter()
    elseif b == IM.SELECT then cycle_view_mode()
    elseif b == IM.X  then cycle_view_mode()
    elseif b == IM.START then quick_launch() end
end

function S.hat(dir)
    if     dir == "left"  then navigate(-1, 0)
    elseif dir == "right" then navigate( 1, 0)
    elseif dir == "up"    then navigate(0, -1)
    elseif dir == "down"  then navigate(0,  1) end
end

function S.key(k)
    if     k == "left"  then navigate(-1, 0)
    elseif k == "right" then navigate( 1, 0)
    elseif k == "up"    then navigate(0, -1)
    elseif k == "down"  then navigate(0,  1)
    elseif k == "y"     then cycle_filter()
    elseif k == "tab"   then cycle_view_mode()
    elseif k == "return" or k == "space" then open_detail() end
end

function S.update(dt)
    -- Detect filter change (theme flip changes the resolved filter
    -- when the user's filter is AUTO, i.e. S.filter == nil).
    local cur = resolve_filter()
    if S._last_resolved ~= cur then
        S._last_resolved = cur
        State.page_lib = 1
        _frame_list   = filtered()
        _frame_tested = nil
        reset_focus_first_item()
    end

    resolve_covers_batch()
end

-- ── Rating helpers ──────────────────────────────────────────
local function rating_color(r)
    r = tonumber(r) or 0
    if r >= 5 then return {0.30, 0.85, 0.40} end
    if r == 4 then return {0.55, 0.80, 0.30} end
    if r == 3 then return {0.96, 0.77, 0.26} end
    if r == 2 then return {0.96, 0.50, 0.26} end
    if r == 1 then return {0.90, 0.30, 0.30} end
    return {0.45, 0.45, 0.52}
end

-- ── Tile rendering ──────────────────────────────────────────
local function draw_tile(g, x, y, focused, slot, t)
    local th = State.theme
    local pulse = 0.5 + 0.5 * math.sin(t * 4 + slot * 0.3)

    local accent = (g.sys == "Wii") and {0.20, 0.72, 0.98} or {0.55, 0.35, 0.95}
    if g.virtual then accent = {0.96, 0.77, 0.26} end

    if focused then
        D.glow(x + CW/2, y + CH/2, 75 + pulse * 20, accent, 1.0)
    end

    love.graphics.setColor(
        focused and accent[1]*0.28 or 0.07,
        focused and accent[2]*0.28 or 0.08,
        focused and accent[3]*0.28 or 0.11,
        focused and 0.98 or 0.85)
    love.graphics.rectangle("fill", x, y, CW, CH, 4, 4)

    local cov = g._cover_path
    if cov then
        local img = A.image(cov)
        if img then
            local cover_w, cover_h = CW - 8, CH - 30
            local iw, ih = img:getWidth(), img:getHeight()
            local sc = math.min(cover_w / iw, cover_h / ih)
            local dw, dh = iw * sc, ih * sc
            local dx = x + 4 + (cover_w - dw) / 2
            local dy = y + 4 + (cover_h - dh) / 2
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, dx, dy, 0, sc, sc)
        end
    else
        A.drawImage(th.empty_disc, x + 18, y + 6, CW - 36, 68)
        if not g.virtual then
            local blink = (math.floor(t * 2) % 2 == 0) and 0.9 or 0.3
            love.graphics.setColor(0.20, 0.72, 0.98, blink)
            love.graphics.setFont(A.font(th.font_body_bold, 8))
            love.graphics.printf("…", x, y + 68, CW, "center")
        end
    end

    love.graphics.setColor(focused and {1,1,1} or {0.75, 0.75, 0.82})
    love.graphics.setFont(A.font(th.font_body, 10))
    local title = g.title or "?"
    if #title > 14 then title = title:sub(1, 13) .. "…" end
    love.graphics.printf(title, x + 4, y + CH - 22, CW - 8, "center")

    local compat = get_compat(g)
    if compat and (compat.rating or 0) > 0 then
        local rb = tostring(compat.rating)
        local font = A.font(th.font_body_bold, 9)
        love.graphics.setFont(font)
        local rbw = font:getWidth(rb) + 12
        local rbx = x + CW - rbw - 4
        local rby = y + 4
        local rc = rating_color(compat.rating)
        love.graphics.setColor(rc[1], rc[2], rc[3], 0.92)
        love.graphics.rectangle("fill", rbx, rby, rbw, 13, 3, 3)
        love.graphics.setColor(0, 0, 0, 0.95)
        love.graphics.printf(rb, rbx, rby + 2, rbw, "center")
    end

    if g.virtual then
        local tag = (g.virtual == "gc") and "GC" or "WII"
        local font = A.font(th.font_body_bold, 8)
        love.graphics.setFont(font)
        local tw = font:getWidth(tag) + 8
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.85)
        love.graphics.rectangle("fill", x + 4, y + 4, tw, 12, 3, 3)
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.printf(tag, x + 4, y + 5, tw, "center")
    end

    local has_compat = compat ~= nil
    local dot_col = rating_color(has_compat and (compat.rating or 0) or -1)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.circle("fill", x + 10, y + CH - 12, 4.5)
    love.graphics.setColor(dot_col)
    love.graphics.circle("fill", x + 10, y + CH - 12, 3.2)
    if has_compat then
        love.graphics.setColor(dot_col[1], dot_col[2], dot_col[3], 0.35)
        love.graphics.circle("line", x + 10, y + CH - 12, 5.2)
    end

    if focused then
        love.graphics.setColor(1, 1, 1, 0.5 + pulse * 0.5)
        D.rough_rect(x - 1, y - 1, CW + 2, CH + 2,
            { jitter = 1.4, thickness = 2, seed = slot * 11 })
        love.graphics.setColor(accent)
        D.rough_rect(x, y, CW, CH,
            { jitter = 1.0, thickness = 2.5, seed = slot * 13, cut = 12 })
        D.corner_brackets(x, y, CW, CH, accent, 12)
    else
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.45)
        D.rough_rect(x, y, CW, CH,
            { jitter = 0.7, thickness = 1.2, seed = slot * 13, cut = 12 })
    end

    if focused then
        for j = 1, 8 do
            local ang = (j / 8) * math.pi * 2 + t * 1.4
            local pr = 6 + 3 * math.sin(t * 5 + j)
            local px = x + CW/2 + math.cos(ang) * (CW/2 + pr)
            local py = y + CH/2 + math.sin(ang) * (CH/2 + pr)
            love.graphics.setColor(accent[1], accent[2], accent[3], 0.65)
            love.graphics.circle("fill", px, py, 1.3 + math.sin(t * 8 + j))
        end
    end
end

-- ── Pagination ──────────────────────────────────────────────
local function draw_pagination(th, total)
    if total <= 1 then return end
    local dots_w = total * 12
    local bx = W/2 - dots_w/2
    local by = PAGE_Y
    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.20)
    love.graphics.rectangle("fill", bx - 6, by - 3, dots_w + 4, 9, 4, 4)
    for i = 1, total do
        local active = (i == State.page_lib)
        love.graphics.setColor(active and th.focus or {0.35, 0.35, 0.42})
        love.graphics.rectangle("fill", bx + (i-1) * 12, by, 8, 3)
    end
end

-- ── Info strip ──────────────────────────────────────────────
local function count_tested(list)
    local tested = 0
    for _, g in ipairs(list) do
        if get_compat(g) then tested = tested + 1 end
    end
    return tested
end

local function count_tested_cached(list)
    if _frame_tested == nil then
        _frame_tested = count_tested(list)
    end
    return _frame_tested
end

local function draw_info_strip(th, list, total)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, STRIP_Y, W, STRIP_H)
    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
    love.graphics.rectangle("fill", 0, STRIP_Y, W, 1)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, STRIP_Y + STRIP_H - 1, W, 1)

    local font = A.font(th.font_body_bold, 10)
    love.graphics.setFont(font)

    local cx = 14
    local function pill(label, value, col)
        love.graphics.setColor(0.55, 0.60, 0.72)
        love.graphics.print(label, cx, STRIP_Y + 7)
        cx = cx + font:getWidth(label) + 5
        love.graphics.setColor(col)
        love.graphics.print(value, cx, STRIP_Y + 7)
        cx = cx + font:getWidth(value) + 12
        love.graphics.setColor(0.35, 0.38, 0.45)
        love.graphics.rectangle("fill", cx - 6, STRIP_Y + 6, 1, 10)
    end

    local slot_idx = focus_slot_index(State.focus_lib.x, State.focus_lib.y) + 1
    pill("PAGE:", string.format("%02d/%02d", State.page_lib, total),
        {0.86, 0.89, 0.95})
    pill("SLOT:", string.format("%02d/%02d", slot_idx, State.PAGE_LIB),
        {0.86, 0.89, 0.95})
    pill("FILTER:", filter_label(),
        (S.filter == nil) and {0.55, 0.55, 0.65} or th.focus)

    local rx = W - 14
    local tested = count_tested_cached(list)
    local ttxt = string.format("TESTED %d / %d", tested, #list)
    love.graphics.setFont(font)
    local tw = font:getWidth(ttxt)
    love.graphics.setColor(tested > 0 and {0.30, 0.80, 0.40} or {0.55, 0.60, 0.72})
    love.graphics.print(ttxt, rx - tw, STRIP_Y + 7)
    rx = rx - tw - 14

    local sys = (S.filter == nil and ((State.theme_name == "wii") and "WII" or "GC"))
        or (S.filter == "ALL" and "ALL" or S.filter:upper())
    local sys_col = (State.theme_name == "wii") and {0.20, 0.72, 0.98}
        or (State.theme_name == "gc" and {0.55, 0.35, 0.95} or {0.55, 0.55, 0.65})
    local sysw = font:getWidth(sys)
    love.graphics.setColor(sys_col)
    love.graphics.print(sys, rx - sysw, STRIP_Y + 7)
    rx = rx - sysw - 6

    love.graphics.setColor(sys_col[1], sys_col[2], sys_col[3], 0.9)
    love.graphics.circle("fill", rx, STRIP_Y + 12, 3)
end

-- ── Empty-state hint ────────────────────────────────────────
local function draw_empty_state(th)
    local total = #(State.roms or {})
    local scanning = not State.scan_done and total == 0

    love.graphics.setFont(A.font(th.font_body_bold, 14))
    love.graphics.setColor(th.text)
    if scanning then
        local t = State.t_ui or 0
        local n = math.floor(t * 2) % 4
        local dots = string.rep(".", n)
        love.graphics.printf("Scanning library" .. dots,
            0, H/2 - 40, W, "center")

        love.graphics.setFont(A.font(th.font_body, 11))
        love.graphics.setColor(th.text_dim)
        love.graphics.printf(
            "This can take a few seconds on a large library.",
            0, H/2 - 12, W, "center")
    else
        love.graphics.printf("No ROMs found",
            0, H/2 - 40, W, "center")

        love.graphics.setFont(A.font(th.font_body, 11))
        love.graphics.setColor(th.text_dim)
        love.graphics.printf(
            "Set your GameCube and Wii folders from\n" ..
            "Settings  >  ROM Paths, then rescan.",
            0, H/2 - 12, W, "center")

        love.graphics.setFont(A.font(th.font_body_bold, 10))
        love.graphics.setColor(th.focus)
        love.graphics.printf("[B] Back  .  [Y] Filter",
            0, H/2 + 30, W, "center")
    end
end

-- ── Draw ────────────────────────────────────────────────────
function S.draw()
    local th = State.theme
    local t = State.t_ui

    _frame_list   = filtered()
    _frame_tested = nil

    local list  = _frame_list
    local total = total_pages_for(list)

    if State.page_lib > total then State.page_lib = total end
    clamp_focus()

    BG.draw_cockpit(W, H, love.timer.getDelta(), th.accent)
    Header.draw("GAME LIBRARY", "library", "library")

    Chips.draw(16, CHIPS_Y, A.font(th.font_body, 10))

    if #list == 0 then
        draw_empty_state(th)
        BI.draw_footer(th, {
            { key = "y", label = "Filter" },
            { key = "b", label = "Back"   },
        }, W, FOOTER_CENTER, A.font(th.font_body, 12))
        return
    end

    draw_pagination(th, total)

    local start = page_offset() + 1
    for slot = 0, State.PAGE_LIB - 1 do
        local i = start + slot
        local g = list[i]
        if not g then break end
        local cx = slot % COLS
        local cy = math.floor(slot / COLS)
        local col = mirrored() and (COLS - 1 - cx) or cx
        local x = GRID_X + col * (CW + PAD)
        local y = GRID_Y + cy * (CH + PAD)
        local focused = (col == State.focus_lib.x and cy == State.focus_lib.y)
        draw_tile(g, x, y, focused, slot, t)
    end

    draw_info_strip(th, list, total)

    BI.draw_footer(th, {
        { key = "dpad",  label = "Nav"     },
        { key = "a",     label = "Details" },
        { key = "y",     label = "Filter"  },
        { key = "start", label = "Quick"   },
        { key = "l1",    label = "Pg-"     },
        { key = "r1",    label = "Pg+"     },
        { key = "b",     label = "Back"    },
    }, W, FOOTER_CENTER, A.font(th.font_body, 12))

    Modal.draw()
end

return S
