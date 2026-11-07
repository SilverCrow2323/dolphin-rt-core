-- ui/screens/cheats.lua — per-game Boost / FPS / Cheats (Rogue DB + yours).
-- params: { game_id, title }
-- [A] toggle  [Y] Boost: enable all, others: clear  [X] apply now
-- [L1/R1] tab  [B] back (edits are written to Dolphin on the way out)
local K      = require("ui.kit")
local SFX    = require("ui.sfx")
local Notify = require("ui.notify")
local Cheats = require("core.rtcheats")

local S = {}
local TABS = {
    { id = "perf",  label = "Boost",  acc = K.ACC.boost },
    { id = "fps",   label = "FPS",    acc = K.ACC.wii },
    { id = "cheat", label = "Cheats", acc = K.ACC.hot },
}
local TAB_Y = 90
S.list = K.List(K.MARGIN, TAB_Y + 46, K.W - K.MARGIN * 2 - 14, K.BOT - (TAB_Y + 46) - 84, 40)
S.t = 0

local function entries(id)
    local out = {}
    for _, e in ipairs(S.all) do if e.group == id then out[#out + 1] = e end end
    return out
end

local function rebuild(keep)
    local rows, last = {}, nil
    for _, e in ipairs(entries(TABS[S.tab].id)) do
        if TABS[S.tab].id == "perf" and e.pclass ~= last then
            last = e.pclass
            rows[#rows + 1] = { head = (Cheats.PCLASS_LABEL[e.pclass or ""] or "Other"):upper(), skip = true }
        end
        rows[#rows + 1] = { e = e }
    end
    S.list:set(rows, false)
    if keep then
        for i, r in ipairs(rows) do if r.e and r.e.slug == keep then S.list.sel = i; S.list:_aim(true) end end
    end
    if S.list:cur() and S.list:cur().skip then S.list:move(1) end
end

local function reload(keep) S.all = Cheats.load_for(S.game_id); rebuild(keep) end

local function start_download()
    S.dl, S.dl_t, S.dl_poll, S.dl_msg = false, 0, 0, nil
    local need = Cheats.missing(S.game_id)
    if #need > 0 and Cheats.sync(need) then S.dl = true end
end

function S.enter(p)
    p = p or {}
    S.game_id, S.title = p.game_id or "?", p.title or p.game_id or "?"
    S.tab, S.changed, S.t = 1, false, 0
    K.set_accent(TABS[1].acc)
    reload()
    start_download()
    if #entries(TABS[1].id) == 0 then
        for i, t in ipairs(TABS) do if #entries(t.id) > 0 then S.tab = i; rebuild(); break end end
    end
end

function S.update(dt)
    S.t = S.t + dt
    S.list:update(dt)
    K.set_accent(TABS[S.tab].acc)
    if S.dl then
        S.dl_t, S.dl_poll = S.dl_t + dt, S.dl_poll + dt
        if S.dl_poll > 0.4 then
            S.dl_poll = 0
            local st = Cheats.sync_status()
            local running = st.state == "running" or (st.state == "idle" and S.dl_t < 4)
            if not running or S.dl_t > 60 then
                S.dl = false
                S.dl_msg = (st.state == "fail") and ("Download failed: " .. (st.msg or "")) or nil
                Cheats.reload(); reload()
            end
        end
    end
end

local function apply_now(quiet)
    local ok, n = Cheats.apply(S.game_id)
    if ok then
        S.changed = false
        if not quiet then SFX.play("menu_select"); Notify.show("success", ("Written to Dolphin: %d code(s)"):format(n or 0)) end
    else Notify.show("warning", "Not applied: " .. tostring(n or "unknown error")) end
end

local function toggle()
    local r = S.list:cur(); if not r or not r.e then return end
    if Cheats.set_enabled(S.game_id, r.e.slug, not r.e.enabled) then
        S.changed = true; SFX.play("menu_toggleoption"); reload(r.e.slug)
    else Notify.show("error", "Could not write rtcheats_data.ini") end
end

local function bulk()
    local tid, list = TABS[S.tab].id, entries(TABS[S.tab].id)
    if #list == 0 then return end
    local any_off = false
    for _, e in ipairs(list) do if not e.enabled then any_off = true end end
    local on = any_off and tid == "perf"       -- bulk enable only for Boost
    local batch = {}
    for _, e in ipairs(list) do
        if on then if e.pclass ~= "diag" then batch[#batch + 1] = { slug = e.slug, on = true } end
        elseif e.enabled then batch[#batch + 1] = { slug = e.slug, on = false } end
    end
    if #batch == 0 then Notify.show("info", "Nothing to change on this tab"); return end
    if Cheats.set_many(S.game_id, batch) then
        S.changed = true; SFX.play("menu_toggleoption")
        local r = S.list:cur(); reload(r and r.e and r.e.slug)
        Notify.show("info", on and "Boost patches enabled" or "All switched off")
    end
end

local function tab(d) S.tab = (S.tab - 1 + d) % #TABS + 1; SFX.play("menu_pagescroll"); rebuild() end

function S.pad(b)
    if     b == "L1" or b == "LEFT"  then tab(-1)
    elseif b == "R1" or b == "RIGHT" then tab(1)
    elseif b == "UP"   then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "A" then toggle()
    elseif b == "Y" then bulk()
    elseif b == "X" then apply_now()
    elseif b == "B" then
        if S.changed then apply_now(true) end
        require("ui").back()
    end
end

local function draw_row(r, x, y, w, h, focused)
    if r.head then
        K.text("key", r.head, x + 4, y + h - 22, K.acc, 0.9)
        K.color(K.C.line, 0.6); love.graphics.rectangle("fill", x + 12 + K.width("key", r.head), y + h - 14, w - 24 - K.width("key", r.head), 1)
        return
    end
    local e = r.e
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    K.text("body", K.clip("body", e.name, w - 150), x + 14, y + 5, e.enabled and K.C.text or K.C.dim)
    K.text("mono", (e.type or "Gecko") .. " · " .. #e.codes .. " code" .. (#e.codes == 1 and "" or "s"), x + 14, y + 22, K.C.faint)
    local right = x + w - 14
    K.switch(right - 38, y + h / 2, e.enabled, focused)
    right = right - 50
    if e.from_user then K.pill(e.from_rogue and "EDIT" or "MINE", right, y + h / 2, K.ACC.hot, false) end
end

function S.draw()
    K.header("Cheats & Boost", S.title, nil)
    local counts, on = { perf = 0, fps = 0, cheat = 0 }, { perf = 0, fps = 0, cheat = 0 }
    for _, e in ipairs(S.all) do
        counts[e.group] = (counts[e.group] or 0) + 1
        if e.enabled then on[e.group] = (on[e.group] or 0) + 1 end
    end
    local tw = (K.W - K.MARGIN * 2 - 12) / 3
    for i, t in ipairs(TABS) do
        local x = K.MARGIN + (i - 1) * (tw + 6)
        local act = (i == S.tab)
        K.panel(x, TAB_Y, tw, 36, { focus = act, accent = t.acc, cut = 6 })
        K.text("h", t.label, x + 12, TAB_Y + 7, act and K.C.text or K.C.dim)
        K.text("mono", ("%d/%d"):format(on[t.id] or 0, counts[t.id] or 0), x, TAB_Y + 11, act and t.acc or K.C.faint, 1, tw - 12, "right")
    end
    if #S.list.items == 0 then
        local msg = S.dl and "Downloading cheats for this game…" or S.dl_msg
            or (Cheats.in_index(S.game_id) and "Nothing in this tab." or "No cheats in the database for this game.")
        K.text("body", msg, K.MARGIN, S.list.y + 60, K.C.dim, 1, K.W - K.MARGIN * 2, "center")
    else
        S.list:draw(draw_row)
    end
    -- details strip
    local r = S.list:cur()
    local dy = K.BOT - 76
    K.panel(K.MARGIN, dy, K.W - K.MARGIN * 2, 76, { cut = 8 })
    if r and r.e then
        K.text("h", K.clip("h", r.e.name, K.W - 80), K.MARGIN + 14, dy + 8, K.acc)
        local code = r.e.codes[1] or "—"
        K.text("mono", code .. (#r.e.codes > 1 and ("   +" .. (#r.e.codes - 1) .. " more") or ""), K.MARGIN + 14, dy + 34, K.C.dim)
        if r.e.notes[1] then K.text("small", K.clip("small", r.e.notes[1], K.W - 80), K.MARGIN + 14, dy + 52, K.C.warn) end
    else
        K.text("small", "Select an entry to inspect its codes.", K.MARGIN + 14, dy + 28, K.C.faint)
    end
    K.footer({ { key = "A", label = "Toggle" }, { key = "Y", label = "All" }, { key = "X", label = "Apply" },
               { key = "L1 R1", label = "Tab" }, { key = "B", label = "Back" } })
end

return S
