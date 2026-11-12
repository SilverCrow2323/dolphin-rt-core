-- ui/screens/mods.lua — MOD VAULT.
-- 4 tab colorati, uno per cartella di /opt/muos/share/emulator/dolphin/Load/:
--   Textures · Wii SD Sync · Riivolution · Dynamic Input
-- Per ogni tab elenca le voci applicabili al gioco (vedi core/mods.lua):
--   ID esatto · primi 3 char dell'ID (tutte le regioni) · nome del gioco ·
--   cartella "All" (tutti i giochi).
-- [A] on/off  [X] tutte on  [Y] tutte off  [L1/R1 o SX/DX] cambia tab  [B] indietro
-- Senza gioco (tile Home) mostra il catalogo installato, sola lettura.
local K    = require("ui.kit")
local SFX  = require("ui.sfx")
local U      = require("ui.util")
local Notify = require("ui.notify")
local Mods   = require("core.mods")

local S = {}
local LIST_Y = 124
S.list = K.List(K.MARGIN, LIST_Y, K.W - K.MARGIN * 2 - 14, K.BOT - LIST_Y, 40)
S.t, S.tab, S.tab_x = 0, 1, 0
S.rows, S.off, S.sel_by_tab = {}, {}, {}

local TAB_Y, TAB_H = 80, 34

local function tab_w() return (K.W - K.MARGIN * 2) / #Mods.CATS end

local function counts(i)
    local rows, off = S.rows[i] or {}, S.off[i] or {}
    local on = 0
    for _, r in ipairs(rows) do
        local enabled
        if S.game then enabled = not off[r.name] else enabled = not r.parked end
        if enabled then on = on + 1 end
    end
    return on, #rows
end

local function load_tab(i, keep_sel)
    S.sel_by_tab[S.tab] = S.list.sel
    S.tab = i
    S.list:set(S.rows[i] or {}, false)
    local want = S.sel_by_tab[i] or 1
    S.list.sel = math.max(1, math.min(want, math.max(1, #S.list.items)))
    S.list:_aim(true)
end

function S.enter(p)
    p = p or {}
    S.t, S.game = 0, p.game
    S.rows, S.off, S.sel_by_tab = {}, {}, {}
    local titles = S.game and U.vault_titles(S.game) or nil
    for i, cat in ipairs(Mods.CATS) do
        S.rows[i] = Mods.for_game(cat, S.game, titles)
        S.off[i] = S.game and U.vault_off(S.game, cat.id) or {}
    end
    -- apri sul primo tab che ha qualcosa per questo gioco
    local first = 1
    for i = 1, #Mods.CATS do if #S.rows[i] > 0 then first = i; break end end
    S.tab = first
    S.tab_x = (first - 1) * tab_w()
    S.list:set(S.rows[first] or {}, false)
    K.set_accent(Mods.CATS[first].acc)
end

function S.update(dt)
    S.t = S.t + dt
    S.list:update(dt)
    local want = (S.tab - 1) * tab_w()
    S.tab_x = S.tab_x + (want - S.tab_x) * (1 - math.exp(-dt * 18))
    if math.abs(want - S.tab_x) < 0.4 then S.tab_x = want end
    K.set_accent(Mods.CATS[S.tab].acc)
end

local function save()
    if S.game then U.vault_set_off(S.game, Mods.CATS[S.tab].id, S.off[S.tab]) end
end

local function refresh_current_tab()
    local selected = S.list:cur()
    local selected_name = selected and selected.name or nil
    local cat = Mods.CATS[S.tab]
    local titles = S.game and U.vault_titles(S.game) or nil
    S.rows[S.tab] = Mods.for_game(cat, S.game, titles)
    S.off[S.tab] = S.game and U.vault_off(S.game, cat.id) or {}
    S.list:set(S.rows[S.tab], false)
    if selected_name then
        for i, item in ipairs(S.list.items) do
            if item.name == selected_name then S.list.sel = i; S.list:_aim(true); break end
        end
    end
end

local function toggle_all(enabled)
    if S.game then
        local off = S.off[S.tab]
        if enabled then
            for k in pairs(off) do off[k] = nil end
        else
            for _, row in ipairs(S.list.items) do off[row.name] = true end
        end
        save()
    else
        local changed, errors = Mods.set_all_enabled(Mods.CATS[S.tab], enabled)
        refresh_current_tab()
        local label = enabled and "enabled" or "disabled"
        if #errors > 0 then
            Notify.show("warning", changed .. " mod(s) " .. label .. " · " .. #errors .. " failed")
        else
            Notify.show("success", changed .. " mod(s) " .. label)
        end
    end
    SFX.play(enabled and "menu_toggleoption" or "menu_back")
end

local function set_tab(d)
    local n = #Mods.CATS
    local i = (S.tab - 1 + d) % n + 1
    if i ~= S.tab then load_tab(i); SFX.play("menu_pagescroll") end
end

function S.pad(b)
    local r = S.list:cur()
    local off = S.off[S.tab]
    if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "L1" or b == "LEFT" then set_tab(-1)
    elseif b == "R1" or b == "RIGHT" then set_tab(1)
    elseif b == "A" and r then
        if S.game then
            off[r.name] = (not off[r.name]) or nil
            save()
            SFX.play("menu_toggleoption")
        else
            local enabling = r.parked == true
            local ok, err = Mods.set_enabled(Mods.CATS[S.tab], r, enabling)
            if ok then
                refresh_current_tab()
                Notify.show("success", (enabling and "Enabled " or "Disabled ") .. r.name, 1.8)
                SFX.play("menu_toggleoption")
            else
                Notify.show("error", tostring(err))
            end
        end
    elseif b == "X" then
        toggle_all(true)
        if S.game then refresh_current_tab() end
    elseif b == "Y" then
        toggle_all(false)
        if S.game then refresh_current_tab() end
    elseif b == "B" then require("ui").back() end
end

local function draw_tabs()
    local w = tab_w()
    -- barra di selezione che scorre fra i tab
    local acc = K.ACC[Mods.CATS[S.tab].acc]
    for i, cat in ipairs(Mods.CATS) do
        local x = K.MARGIN + (i - 1) * w
        local c = K.ACC[cat.acc]
        local on = (i == S.tab)
        K.color(c, on and 0.20 or 0.07)
        love.graphics.rectangle("fill", x + 2, TAB_Y, w - 4, TAB_H, 6, 6)
        K.color(c, on and 0.95 or 0.30)
        love.graphics.rectangle("line", x + 2, TAB_Y, w - 4, TAB_H, 6, 6)
        K.draw_tool_icon(cat.icon, x + 17, TAB_Y + TAB_H / 2, 14, c, on and 1 or 0.6)
        K.text("key", K.clip("key", cat.short or cat.label, w - 36), x + 31, TAB_Y + 2, on and K.C.text or K.C.dim)
        local n_on, n = counts(i)
        local badge = S.game and (n_on .. "/" .. n) or tostring(n)
        K.text("key", badge, x + 31, TAB_Y + 17, n == 0 and K.C.faint or c, on and 1 or 0.7)
    end
    K.color(acc, 1)
    love.graphics.rectangle("fill", K.MARGIN + S.tab_x + 2, TAB_Y + TAB_H + 3, w - 4, 3, 1.5, 1.5)
end

local KIND_COLOR = { id = "ok", prefix = "blue", name = "warn", all = "faint" }
local function kind_color(k)
    local c = KIND_COLOR[k]
    return K.C[c] or K.ACC[c] or K.C.dim
end

local function draw_row(r, x, y, w, h, focused)
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    local on
    if S.game then on = not S.off[S.tab][r.name] else on = not r.parked end
    local right = x + w - 14
    if S.game then right = x + w - 60; K.switch(x + w - 46, y + h / 2, on, focused) end
    local lab = Mods.KIND_LABEL[r.kind] or ""
    if S.game and lab ~= "" then
        local pw = K.pill(lab, right, y + h / 2, kind_color(r.kind), true)   -- x = bordo destro
        right = right - pw - 4
    end
    K.text("body", K.clip("body", r.name, right - x - 24), x + 14, y + h / 2 - 9,
           on and K.C.text or K.C.faint, on and 1 or 0.7)
end

function S.draw()
    local cat = Mods.CATS[S.tab]
    local on, total = 0, 0
    for i = 1, #Mods.CATS do local a, b = counts(i); on, total = on + a, total + b end
    K.header("Mod Vault", S.game and (S.game.title or "") or "GLOBAL · enable or park installed mods",
             on .. " / " .. total .. " active",
             nil, { icon = "mods", accent = K.ACC[cat.acc] })
    draw_tabs()
    if #S.list.items == 0 then
        local msg = S.game and
            ("Nothing for this game in Load/" .. cat.id .. ".\nMatch by Game ID, its first 3 characters, title, or All.")
            or ("Load/" .. cat.id .. " is empty. Install a mod folder to manage it here.")
        K.text("body", msg, 0, LIST_Y + 40, K.C.dim, 1, K.W, "center")
    else
        S.list:draw(draw_row)
    end
    if S.game then
        K.footer({ { key = "A", label = "Toggle" }, { key = "L1 R1", label = "Tab" },
                   { key = "X", label = "All on" }, { key = "Y", label = "All off" }, { key = "B", label = "Back" } })
    else
        K.footer({ { key = "A", label = "Enable / Disable" }, { key = "L1 R1", label = "Tab" },
                   { key = "X", label = "Enable all" }, { key = "Y", label = "Disable all" },
                   { key = "B", label = "Back" } })
    end
end

-- "tornando indietro" ripristina anche il tab
function S.save_state() return { sel = S.list.sel, tab = S.tab } end
function S.restore_state(st)
    if not st then return end
    if st.tab and Mods.CATS[st.tab] then
        S.tab = st.tab; S.tab_x = (st.tab - 1) * tab_w()
        S.list:set(S.rows[st.tab] or {}, false)
    end
    if st.sel then
        S.list.sel = math.max(1, math.min(st.sel, math.max(1, #S.list.items)))
        S.list:_aim(true)
    end
end

return S
