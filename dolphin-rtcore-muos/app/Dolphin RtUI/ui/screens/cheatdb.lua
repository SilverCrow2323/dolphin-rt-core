-- ui/screens/cheatdb.lua — every title in the cheat database, with its name,
-- whether it has Boost patches and whether you own it.
-- [A] open its cheats  [L1/R1] filter  [L2/R2] jump by letter  [B] back
local K      = require("ui.kit")
local SFX    = require("ui.sfx")
local U      = require("ui.util")
local Cheats = require("core.rtcheats")
local Library = require("core.library")

local S = {}
local FILTERS = {
    { id = "all", label = "ALL" },
    { id = "boost", label = "BOOST" },
    { id = "mine", label = "MINE" },
}
S.list = K.List(K.MARGIN, 92, K.W - K.MARGIN * 2 - 14, K.BOT - 92, 36)
S.filter, S.t = 1, 0

local function valid_game_id(id)
    return type(id) == "string" and #id >= 3 and #id <= 16 and id:match("^[%w_%-]+$") ~= nil
end

local function build_all()
    S.all = {}
    local mine = {}
    for _, g in ipairs(Library.games or {}) do
        if type(g.id) == "string" and g.id ~= "" then mine[#mine + 1] = g.id end
    end
    for id, v in pairs(Cheats.index()) do
        if valid_game_id(id) then
            local title, exact = U.title_for(id)
            local owned = false
            for _, gid in ipairs(mine) do if gid:sub(1, #id) == id then owned = true; break end end
            S.all[#S.all + 1] = { id = id, boost = v.boost == true, title = title or id, exact = exact, owned = owned }
        end
    end
    table.sort(S.all, function(a, b)
        local at, bt = tostring(a.title):lower(), tostring(b.title):lower()
        if at == bt then return a.id < b.id end
        return at < bt
    end)
    S.boosts = 0
    for _, e in ipairs(S.all) do if e.boost then S.boosts = S.boosts + 1 end end
end

local function rebuild(keep_id)
    local items, filter = {}, FILTERS[S.filter]
    for _, e in ipairs(S.all) do
        if filter.id == "all" or (filter.id == "boost" and e.boost)
            or (filter.id == "mine" and e.owned) then
            items[#items + 1] = e
        end
    end
    S.list:set(items, false)
    if keep_id then
        for i, entry in ipairs(items) do
            if entry.id == keep_id then
                S.list.sel = i
                if S.list._aim then S.list:_aim(true) end
                break
            end
        end
    end
end

function S.enter()
    S.t = 0; K.set_accent("boost")
    if not S.all then build_all() end
    rebuild()
end
function S.update(dt) S.t = S.t + dt; S.list:update(dt) end

local function jump(d)
    local items, i = S.list.items, S.list.sel
    if #items == 0 then return end
    local cl = items[i].title:sub(1, 1):upper()
    local j = i
    while true do
        j = j + d
        if j < 1 or j > #items then return end
        local l = items[j].title:sub(1, 1):upper()
        if l ~= cl then
            if d < 0 then while j > 1 and items[j - 1].title:sub(1, 1):upper() == l do j = j - 1 end end
            S.list.sel = j; S.list:_aim(); SFX.play("menu_pagescroll"); return
        end
    end
end

-- NEXUS exposes the global cheat index without mixing it with the
-- per-game toggle/apply actions owned by the Cheats screen.
function S.register_actions(ui)
    if not ui or type(ui.register_action) ~= "function" then
        return false, "UI action registrar unavailable"
    end
    local function selected() return S.list and S.list:cur() or nil end
    local specs = {
        {
            id = "cheatdb.refresh", title = "Refresh cheat database", order = 10,
            run = function()
                local row = selected()
                local keep_id = row and row.id or nil
                local ok, result = pcall(Cheats.refresh_index)
                if not ok then return false, tostring(result) end
                local built, err = pcall(build_all)
                if not built then return false, tostring(err) end
                rebuild(keep_id)
                return true, #S.all
            end,
        },
        {
            id = "cheatdb.set_filter", title = "Set cheat database filter", order = 20,
            run = function(filter_id)
                local indexes = { all = 1, boost = 2, mine = 3 }
                if type(filter_id) ~= "string" or not indexes[filter_id] then
                    return false, "filter must be all, boost or mine"
                end
                local row = selected()
                S.filter = indexes[filter_id]
                rebuild(row and row.id or nil)
                SFX.play("menu_pagescroll")
                return true
            end,
        },
        {
            id = "cheatdb.jump_letter", title = "Jump to next or previous title initial", order = 30,
            run = function(direction)
                if direction ~= -1 and direction ~= 1 then return false, "direction must be -1 or 1" end
                if #S.list.items == 0 then return false, "no cheat titles match the current filter" end
                jump(direction)
                return true
            end,
        },
        {
            id = "cheatdb.open_selected", title = "Open selected cheat entry", order = 40,
            run = function()
                local entry = selected()
                if not entry then return false, "no cheat entry selected" end
                if not valid_game_id(entry.id) then return false, "selected game ID is invalid" end
                local ok, result, detail = pcall(ui.go, "cheats", { game_id = entry.id, title = entry.title })
                if not ok then return false, tostring(result) end
                if result == false then return false, tostring(detail or "could not open cheats") end
                return true
            end,
        },
        {
            id = "cheatdb.state", title = "Get cheat database state", order = 50,
            run = function()
                local entry = selected()
                local filter = FILTERS[S.filter]
                return {
                    filter = filter and filter.id or nil,
                    selected_id = entry and entry.id or nil,
                    selected_title = entry and entry.title or nil,
                    selected_owned = entry and entry.owned or false,
                    selected_boost = entry and entry.boost or false,
                    result_count = #S.list.items,
                    database_count = #(S.all or {}),
                    boost_count = S.boosts or 0,
                    owned_count = (function()
                        local count = 0
                        for _, item in ipairs(S.all or {}) do if item.owned then count = count + 1 end end
                        return count
                    end)(),
                }
            end,
        },
    }
    for _, spec in ipairs(specs) do
        local ok, err = ui.register_action(spec.id, spec.run, {
            title = spec.title, group = "cheats", order = spec.order, screen = "cheatdb",
        })
        if not ok then return false, err or ("could not register " .. spec.id) end
    end
    return true
end

function S.pad(b)
    local e = S.list:cur()
    if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "LEFT" then S.list:page(-1)
    elseif b == "RIGHT" then S.list:page(1)
    elseif b == "L1" then S.filter = (S.filter - 2) % #FILTERS + 1; rebuild(); SFX.play("menu_pagescroll")
    elseif b == "R1" then S.filter = S.filter % #FILTERS + 1; rebuild(); SFX.play("menu_pagescroll")
    elseif b == "L2" then jump(-1)
    elseif b == "R2" then jump(1)
    elseif b == "A" and e then SFX.play("menu_select"); require("ui").go("cheats", { game_id = e.id, title = e.title })
    elseif b == "B" then require("ui").back() end
end

local function draw_row(e, x, y, w, h, focused)
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    local right = x + w - 12
    if e.owned then right = right - K.pill("MINE", right, y + h / 2, K.ACC.lime, true) end
    if e.boost then K.bolt(right - 8, y + h / 2, 16, K.ACC.boost, 1); right = right - 24 end
    K.text("mono", e.id, right - K.width("mono", e.id), y + h / 2 - 7, K.C.faint)
    right = right - K.width("mono", e.id) - 12
    K.text("body", K.clip("body", U.clean_title(e.title) .. (e.exact and "" or "  (all regions)"), right - x - 24), x + 12, y + h / 2 - 9,
           focused and K.C.text or K.C.dim)
end

function S.draw()
    K.header("Cheat database", ("%d titles  ·  %d with Boost"):format(#(S.all or {}), S.boosts or 0), nil, nil, { icon = "cheats", accent = K.ACC.boost })
    local fx = K.W - K.MARGIN
    for i = #FILTERS, 1, -1 do
        local name, on = FILTERS[i].label, (i == S.filter)
        local fw = K.width("key", name) + 18
        fx = fx - fw
        K.color(on and K.acc or K.C.surf, on and 0.25 or 0.8); love.graphics.rectangle("fill", fx, 22, fw, 24, 6, 6)
        K.color(on and K.acc or K.C.line, on and 1 or 0.7); love.graphics.rectangle("line", fx, 22, fw, 24, 6, 6)
        K.text("key", name, fx + 9, 28, on and K.C.text or K.C.dim)
        fx = fx - 6
    end
    if #S.list.items == 0 then K.text("body", "Nothing matches this filter.", 0, 200, K.C.dim, 1, K.W, "center")
    else S.list:draw(draw_row) end
    K.footer({ { key = "A", label = "Cheats" }, { key = "L1 R1", label = "Filter" }, { key = "L2 R2", label = "Letter" }, { key = "B", label = "Back" } })
end

return S
