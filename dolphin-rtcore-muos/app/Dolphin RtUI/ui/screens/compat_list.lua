-- ui/screens/compat_list.lua — Compatibility list (da data/games_data.json)
-- Sfoglia tutto il database, anche i giochi che non hai.
-- [L1/R1] filtro: ALL · PLAYABLE · ISSUES · NOT PLAYABLE   [X] solo la mia libreria
-- [L2/R2] salta lettera   [A] apri il gioco (se ce l'hai)   [B] indietro
local K       = require("ui.kit")
local SFX     = require("ui.sfx")
local U       = require("ui.util")
local Compat  = require("core.compatibility")
local Library = require("core.library")

local S = {}
local LY = 100
S.list = K.List(K.MARGIN, LY, 296, K.BOT - LY, 36)
S.t, S.filter, S.mine_only = 0, 1, false

local FILTERS = {
    { id = "all",          label = "ALL",          test = function(g) return true end,                 color = "sys" },
    { id = "playable",     label = "PLAYABLE",     test = function(g) return g.playable_rank == 3 end, color = "lime" },
    { id = "issues",       label = "ISSUES",       test = function(g) return g.playable_rank == 2 end, color = "boost" },
    { id = "not_playable", label = "NOT PLAYABLE", test = function(g) return g.playable_rank <= 1 end, color = "hot" },
}

local owned = {}          -- id -> gioco in libreria

local function rebuild(keep)
    local items = {}
    local keep_id = type(keep) == "table" and keep.id or nil
    local keep_title = type(keep) == "table" and keep.title or nil
    local f = FILTERS[S.filter]
    for _, g in ipairs(Compat.games or {}) do
        if f.test(g) and (not S.mine_only or owned[g.id]) then items[#items + 1] = g end
    end
    table.sort(items, function(a, b) return a.title:lower() < b.title:lower() end)
    S.list:set(items, false)
    if keep then
        for i, g in ipairs(items) do
            if g == keep or (keep_id and g.id == keep_id and g.title == keep_title) then
                S.list.sel = i
                S.list:_aim(true)
                break
            end
        end
    end
    K.set_accent(f.color)
end

function S.enter()
    S.t = 0
    pcall(Compat.load)
    owned = {}
    for _, g in ipairs(Library.games or {}) do if g.id and not owned[g.id] then owned[g.id] = g end end
    rebuild()
end

function S.update(dt) S.t = S.t + dt; S.list:update(dt) end

local function jump_letter(d)
    local items, i = S.list.items, S.list.sel
    if #items == 0 then return end
    local cur = items[i].title:sub(1, 1):upper()
    local j = i
    while true do
        j = j + d
        if j < 1 or j > #items then return end
        local l = items[j].title:sub(1, 1):upper()
        if l ~= cur then
            if d < 0 then while j > 1 and items[j - 1].title:sub(1, 1):upper() == l do j = j - 1 end end
            S.list.sel = j; S.list:_aim(); SFX.play("menu_pagescroll"); return
        end
    end
end

-- NEXUS exposes compatibility filtering and navigation while preserving
-- the local-library ownership check before opening a game's launch screen.
function S.register_actions(ui)
    if not ui or type(ui.register_action) ~= "function" then
        return false, "UI action registrar unavailable"
    end
    local function selected() return S.list and S.list:cur() or nil end
    local function refresh_owned()
        owned = {}
        for _, game in ipairs(Library.games or {}) do
            if type(game.id) == "string" and game.id ~= "" and not owned[game.id] then
                owned[game.id] = game
            end
        end
    end
    local specs = {
        {
            id = "compat.refresh", title = "Refresh compatibility database", order = 10,
            run = function()
                local keep = selected()
                local ok, err = pcall(Compat.load, true)
                if not ok then return false, tostring(err) end
                if Compat.error then return false, tostring(Compat.error) end
                refresh_owned()
                rebuild(keep)
                return true, #S.list.items
            end,
        },
        {
            id = "compat.set_filter", title = "Set compatibility filter", order = 20,
            run = function(filter_id)
                if type(filter_id) ~= "string" then return false, "filter ID is required" end
                local keep = selected()
                for i, filter in ipairs(FILTERS) do
                    if filter.id == filter_id then
                        S.filter = i
                        rebuild(keep)
                        SFX.play("menu_pagescroll")
                        return true
                    end
                end
                return false, "unknown compatibility filter: " .. filter_id
            end,
        },
        {
            id = "compat.set_mine_only", title = "Filter to owned games", order = 30,
            run = function(enabled)
                if enabled == nil then enabled = not S.mine_only end
                if type(enabled) ~= "boolean" then return false, "enabled must be a boolean" end
                local keep = selected()
                S.mine_only = enabled
                rebuild(keep)
                SFX.play("menu_toggleoption")
                return true
            end,
        },
        {
            id = "compat.jump_letter", title = "Jump to next or previous title initial", order = 40,
            run = function(direction)
                if direction ~= -1 and direction ~= 1 then return false, "direction must be -1 or 1" end
                if #S.list.items == 0 then return false, "no games match the current filter" end
                jump_letter(direction)
                return true
            end,
        },
        {
            id = "compat.open_selected", title = "Open selected owned game", order = 50,
            run = function()
                local game = selected()
                if not game then return false, "no game selected" end
                if type(game.id) ~= "string" or game.id == "" then
                    return false, "selected compatibility entry has no valid game ID"
                end
                local mine = owned[game.id]
                if not mine then return false, "game is not in the local library" end
                local ok, result, detail = pcall(ui.go, "game", { game = mine })
                if not ok then return false, tostring(result) end
                if result == false then return false, tostring(detail or "could not open game") end
                return true
            end,
        },
        {
            id = "compat.state", title = "Get compatibility browser state", order = 60,
            run = function()
                local game = selected()
                local summary = game and Compat.summary(game) or nil
                return {
                    filter = FILTERS[S.filter] and FILTERS[S.filter].id or nil,
                    mine_only = S.mine_only,
                    selected_id = game and game.id or nil,
                    selected_title = game and game.title or nil,
                    selected_owned = game and owned[game.id] ~= nil or false,
                    result_count = #S.list.items,
                    database_count = Compat.count or 0,
                    playable_label = summary and summary.play_label or nil,
                }
            end,
        },
    }
    for _, spec in ipairs(specs) do
        local ok, err = ui.register_action(spec.id, spec.run, {
            title = spec.title, group = "compatibility", order = spec.order, screen = "compat_list",
        })
        if not ok then return false, err or ("could not register " .. spec.id) end
    end
    return true
end

function S.pad(b)
    local g = S.list:cur()
    if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "LEFT" then S.list:page(-1)
    elseif b == "RIGHT" then S.list:page(1)
    elseif b == "L1" then S.filter = (S.filter - 2) % #FILTERS + 1; rebuild(); SFX.play("menu_pagescroll")
    elseif b == "R1" then S.filter = S.filter % #FILTERS + 1; rebuild(); SFX.play("menu_pagescroll")
    elseif b == "L2" then jump_letter(-1)
    elseif b == "R2" then jump_letter(1)
    elseif b == "X" then S.mine_only = not S.mine_only; rebuild(g); SFX.play("menu_toggleoption")
    elseif b == "A" and g then
        local mine = owned[g.id]
        if mine then SFX.play("menu_select"); require("ui").go("game", { game = mine })
        else SFX.play("error") end
    elseif b == "B" then require("ui").back() end
end

local function kind_col(k) return K.C[k] or K.C.dim end

-- Keep long test notes inside the space left by dynamic profile/device rows and
-- the fixed ownership footer. K.para itself wraps but does not impose a height.
local function fit_paragraph(kind, value, width, max_height)
    local text = tostring(value or "")
    local font = K.font(kind)
    local _, lines = font:getWrap(text, width)
    if type(lines) ~= "table" or #lines == 0 then return text end
    local line_height = math.max(1, font:getHeight())
    local max_lines = math.max(1, math.floor((max_height or line_height) / line_height))
    if #lines <= max_lines then return text end
    local visible = {}
    for i = 1, max_lines do visible[i] = lines[i] end
    visible[max_lines] = K.clip(kind, (visible[max_lines] or "") .. "…", width)
    return table.concat(visible, "\n")
end

local function draw_item(g, x, y, w, h, focused)
    local mine = owned[g.id]
    local sm = Compat.summary(g)
    local cx = x + 12
    if mine then K.color(K.C.ok, 1); love.graphics.circle("fill", cx, y + h / 2, 3.5) end
    local right = x + w - 8
    local fps = K.clip("small", sm.has_fps and tostring(sm.fps or "n/a") or "n/a",
                       math.min(68, math.max(40, w * 0.24)))
    local fw = K.width("small", fps)
    K.text("small", fps, right - fw, y + h / 2 - 9,
           kind_col(sm.play_kind), focused and 1 or 0.8)
    local title = K.clip("body", g.title or g.id or "Unknown title",
                         math.max(40, right - fw - x - 36))
    K.text("body", title, x + 24, y + h / 2 - 10,
           focused and K.C.text or K.C.dim)
end

local function draw_stars(x, y, rating)
    for i = 1, 5 do
        local on = rating >= i - 0.25
        K.star(x + (i - 1) * 18, y, 7, on and K.C.warn or K.C.line, on and 1 or 0.6)
    end
end

local function draw_detail(g)
    local px, py = 332, LY
    local pw, ph = K.W - 332 - K.MARGIN, K.BOT - LY
    K.panel(px, py, pw, ph, { cut = 12 })
    if not g then
        K.text("body", "Nothing matches this filter", px, py + ph / 2 - 10,
               K.C.faint, 1, pw, "center")
        return
    end

    local sm = Compat.summary(g)
    if not sm then
        K.text("small", "Compatibility summary unavailable", px + 14, py + 48,
               K.C.faint, 1, pw - 28)
        return
    end
    local mine = owned[g.id]
    K.text("h", K.clip("h", g.title or g.id or "Unknown title", pw - 28),
           px + 14, py + 12, K.C.text)

    -- System, region and Game ID share one measured row instead of relying on
    -- fixed badge offsets that can collide when labels are longer.
    local pill_y, pill_cursor = py + 58, px + 14
    local system = K.clip("key", (g.system ~= "" and g.system) or "GC", 76)
    local system_w = K.width("key", system) + 14
    K.pill(system, pill_cursor + system_w, pill_y,
            (g.system == "Wii") and K.ACC.wii or K.ACC.gc, true)
    pill_cursor = pill_cursor + system_w + 8

    local region = tostring(g.region or "")
    if region ~= "" then
        region = K.clip("key", region, 76)
        local region_w = K.width("key", region) + 14
        K.pill(region, pill_cursor + region_w, pill_y, K.C.dim, false)
        pill_cursor = pill_cursor + region_w + 8
    end

    local id = tostring(g.id or "—")
    local id_limit = math.max(28, px + pw - 14 - pill_cursor - 8)
    id = K.clip("small", id, id_limit)
    K.text("small", id, px + pw - 14 - K.width("small", id), py + 51, K.C.faint)

    K.text("body", sm.play_label or "Unknown", px + 14, py + 78,
           kind_col(sm.play_kind))
    local boot_text = tostring(sm.boot_label or "Unknown")
        .. (sm.has_fps and ("  ·  " .. tostring(sm.fps or "N/A") .. " FPS") or "")
    K.text("small", K.clip("small", boot_text, pw - 28),
           px + 14, py + 102, K.C.dim)

    draw_stars(px + 21, py + 136, tonumber(sm.stars) or 0)
    local test_count = tonumber(sm.n) or 0
    local rating_text = tostring(sm.rating_text or "not rated")
        .. "  ·  " .. test_count .. (test_count == 1 and " test" or " tests")
    K.text("small", K.clip("small", rating_text, pw - 128),
           px + 14 + 100, py + 127, K.C.faint)

    local y = py + 158
    if sm.profiles ~= "" then
        K.text("small", "Profile", px + 14, y, K.C.faint)
        K.text("small", K.clip("small", sm.profiles, pw - 100),
               px + 80, y, K.C.text)
        y = y + 20
    end
    if sm.devices ~= "" then
        K.text("small", "Device", px + 14, y, K.C.faint)
        K.text("small", K.clip("small", sm.devices, pw - 100),
               px + 80, y, K.C.text)
        y = y + 20
    end

    local best
    for _, entry in ipairs(g.entries or {}) do
        if entry.norm and entry.norm.note ~= ""
           and (not best or (tonumber(entry.norm.rating) or 0) > (tonumber(best.norm.rating) or 0)) then
            best = entry
        end
    end
    if best then
        local note = tostring(best.norm.note or ""):gsub("%s+", " ")
        local note_y = y + 12
        local note_bottom = py + ph - 50 -- reserve a separate ownership footer
        local note_height = math.max(K.font("small"):getHeight(), note_bottom - note_y)
        note = fit_paragraph("small", note, pw - 28, note_height)
        K.color(K.C.line, 0.6)
        love.graphics.rectangle("fill", px + 14, y + 4, pw - 28, 1)
        K.para("small", note, px + 14, note_y, pw - 28, K.C.dim, 1)
    end

    K.text("small", mine and "In your library" or "Not in your library",
           px + 14, py + ph - 24, mine and K.C.ok or K.C.faint)
end

function S.draw()
    local f = FILTERS[S.filter]
    local acc = K.ACC[f.color]
    local total = tonumber(Compat.count) or #(Compat.games or {})
    K.header("Compatibility", f.label .. (S.mine_only and "  ·  my library" or ""),
             #S.list.items .. " / " .. total, nil, { icon = "chart", accent = acc })

    if Compat.error then
        K.panel(K.MARGIN, LY, K.W - K.MARGIN * 2, K.BOT - LY, { cut = 12 })
        local width = K.W - K.MARGIN * 2 - 36
        local message = fit_paragraph("body", Compat.error, width, K.BOT - LY - 72)
        K.para("body", message, K.MARGIN + 18, LY + 24, width, K.C.bad, 1)
        K.text("small", "Try refreshing the compatibility database from the app tools.",
               K.MARGIN + 18, K.BOT - 34, K.C.dim)
    else
        if #S.list.items > 0 then
            S.list:draw(draw_item)
        else
            K.panel(K.MARGIN, LY, 296, K.BOT - LY, { cut = 12 })
            local message = S.mine_only and "No owned games match this filter."
                or "No games match this filter."
            K.text("body", message, K.MARGIN + 12, LY + 138,
                   K.C.faint, 1, 272, "center")
        end
        draw_detail(S.list:cur())
    end

    K.footer({ { key = "A", label = "Open" }, { key = "L1 R1", label = "Filter" },
               { key = "X", label = S.mine_only and "Show all" or "Mine only" },
               { key = "L2 R2", label = "Letter" }, { key = "B", label = "Back" } })
end

return S
