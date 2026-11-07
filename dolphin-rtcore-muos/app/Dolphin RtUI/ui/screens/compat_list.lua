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
    { label = "ALL",          test = function(g) return true end,                   color = "sys" },
    { label = "PLAYABLE",     test = function(g) return g.playable_rank == 3 end,   color = "lime" },
    { label = "ISSUES",       test = function(g) return g.playable_rank == 2 end,   color = "boost" },
    { label = "NOT PLAYABLE", test = function(g) return g.playable_rank <= 1 end,   color = "hot" },
}

local owned = {}          -- id -> gioco in libreria

local function rebuild(keep)
    local items = {}
    local f = FILTERS[S.filter]
    for _, g in ipairs(Compat.games) do
        if f.test(g) and (not S.mine_only or owned[g.id]) then items[#items + 1] = g end
    end
    table.sort(items, function(a, b) return a.title:lower() < b.title:lower() end)
    S.list:set(items, false)
    if keep then
        for i, g in ipairs(items) do if g == keep then S.list.sel = i; S.list:_aim(true); break end end
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

local function draw_item(g, x, y, w, h, focused)
    local mine = owned[g.id]
    local sm = Compat.summary(g)
    local cx = x + 12
    if mine then K.color(K.C.ok, 1); love.graphics.circle("fill", cx, y + h / 2, 3.5) end
    local right = x + w - 8
    local fw = K.width("small", sm.has_fps and sm.fps or "n/a")
    K.text("small", sm.has_fps and sm.fps or "n/a", right - fw, y + h / 2 - 9,
           kind_col(sm.play_kind), focused and 1 or 0.8)
    K.text("body", K.clip("body", g.title, right - fw - x - 36), x + 24, y + h / 2 - 10,
           focused and K.C.text or K.C.dim)
end

local function draw_stars(x, y, rating)
    for i = 1, 5 do
        local on = rating >= i - 0.25
        K.star(x + (i - 1) * 18, y, 7, on and K.C.warn or K.C.line, on and 1 or 0.6)
    end
end

local function draw_detail(g)
    local px, py, pw, ph = 332, LY, K.W - 332 - K.MARGIN, K.BOT - LY
    K.panel(px, py, pw, ph, { cut = 12 })
    if not g then
        K.text("body", "Nothing matches this filter", px, py + ph / 2 - 10, K.C.faint, 1, pw, "center")
        return
    end
    local sm = Compat.summary(g)
    local mine = owned[g.id]
    K.text("h", K.clip("h", g.title, pw - 28), px + 14, py + 12, K.C.text)
    K.pill(g.system ~= "" and g.system or "GC", px + 14 + 52, py + 52, (g.system == "Wii") and K.ACC.wii or K.ACC.gc, true)
    if g.region ~= "" then K.pill(g.region, px + 14 + 52 + 70, py + 52, K.C.dim, false) end
    K.text("small", g.id, px + pw - 14 - K.width("small", g.id), py + 44, K.C.faint)

    K.text("body", sm.play_label, px + 14, py + 74, kind_col(sm.play_kind))
    K.text("small", sm.boot_label .. (sm.has_fps and ("  \194\183  " .. sm.fps .. " FPS") or ""),
           px + 14, py + 98, K.C.dim)
    draw_stars(px + 21, py + 132, sm.stars)
    K.text("small", sm.rating_text .. "  \194\183  " .. sm.n .. (sm.n == 1 and " test" or " tests"),
           px + 14 + 100, py + 123, K.C.faint)
    local y = py + 150
    if sm.profiles ~= "" then
        K.text("small", "Profile", px + 14, y, K.C.faint)
        K.text("small", K.clip("small", sm.profiles, pw - 100), px + 80, y, K.C.text); y = y + 20
    end
    if sm.devices ~= "" then
        K.text("small", "Device", px + 14, y, K.C.faint)
        K.text("small", K.clip("small", sm.devices, pw - 100), px + 80, y, K.C.text); y = y + 20
    end
    -- nota della prova migliore
    local best
    for _, e in ipairs(g.entries) do
        if e.norm.note ~= "" and (not best or e.norm.rating > best.norm.rating) then best = e end
    end
    if best then
        local note = best.norm.note:gsub("%s+", " ")
        if #note > 170 then note = note:sub(1, 167):gsub("[\192-\255][\128-\191]*$", "") .. "..." end
        K.color(K.C.line, 0.6); love.graphics.rectangle("fill", px + 14, y + 4, pw - 28, 1)
        K.para("small", note, px + 14, y + 12, pw - 28, K.C.dim, 1)
    end
    K.text("small", mine and "In your library" or "Not in your library", px + 14, py + ph - 24,
           mine and K.C.ok or K.C.faint)
end

function S.draw()
    local f = FILTERS[S.filter]
    local acc = K.ACC[f.color]
    K.header("Compatibility", f.label .. (S.mine_only and "  \194\183  my library" or ""),
             #S.list.items .. " / " .. Compat.count, nil, { icon = "chart", accent = acc })
    if Compat.error then
        K.text("body", Compat.error, 0, 220, K.C.bad, 1, K.W, "center")
    else
        S.list:draw(draw_item)
        draw_detail(S.list:cur())
    end
    K.footer({ { key = "A", label = "Open" }, { key = "L1 R1", label = "Filter" },
               { key = "X", label = S.mine_only and "Show all" or "Mine only" },
               { key = "L2 R2", label = "Letter" }, { key = "B", label = "Back" } })
end

return S
