-- ui/screens/settings.lua — Settings con icone tool + Env Triage.
local K        = require("ui.kit")
local SFX      = require("ui.sfx")
local U        = require("ui.util")
local Notify   = require("ui.notify")
local Settings = require("core.settings")
local Library  = require("core.library")
local Cheats   = require("core.rtcheats")
local _okT, _Triage = pcall(require, "core.rtcore_triage")
if not _okT then print("[settings] core.rtcore_triage FAILED: " .. tostring(_Triage)) end
local Triage = _okT and _Triage or {
    scan = function() return { flavours = {}, stats = { roms = 0, disk_kb = 0 } } end
}
local _okU, _Updater = pcall(require, "core.updater")
if not _okU then print("[settings] core.updater FAILED: " .. tostring(_Updater)) end
local Updater = _okU and _Updater or {
    latest = function() return nil end,
    poll = function() end,
    check_async = function(cb) if cb then cb({ tag = "?" }) end end
}


-- ui/screens/settings.lua — v2.
-- 5 sezioni, ognuna con colore e icona propri; si cambia sezione con L1/R1
-- (niente piu' pannello START: era vuoto, S.cats non esisteva).
local S = {}
S.list = K.List(K.MARGIN, 94, K.W - K.MARGIN * 2 - 14, K.BOT - 94, 46)
S.t, S._sel_t, S._last_sel = 0, 0, 0
S.sec, S.sec_t, S.sec_dir = 1, 1, 1

local CATS = {
    { id = "LIBRARY", label = "Library",         color = "blue",  icon = "folder" },
    { id = "EDITORS", label = "Editors",         color = "boost", icon = "profile" },
    { id = "DISPLAY", label = "Display & Sound", color = "teal",  icon = "screen" },
    { id = "SYSTEM",  label = "System",          color = "lime",  icon = "gear" },
    { id = "ABOUT",   label = "About & Tools",   color = "hot",   icon = "info" },
}
S.cats = CATS

-- ── cache: sub/badge vengono chiamati a ogni frame (prima: ls/popen per frame) ──
local function memo(fn, ttl)
    local val, at
    return function()
        local now = love.timer.getTime()
        if at == nil or now - at > (ttl or 1.5) then val, at = fn(), now end
        return val
    end
end

local function cyc(label, key, values, default, after)
    return { kind = "choice", label = label, values = values,
        get = function() return Settings.get(key) or default end,
        set = function(v) Settings.set(key, v); if after then after(v) end end }
end
local function tog(label, key, default, after)
    return { kind = "toggle", label = label,
        get = function() local v = Settings.get(key); if v == nil then return default end return v end,
        set = function(v) Settings.set(key, v); if after then after(v) end end }
end

local function rescan()
    Notify.show("scan", "Scanning ROM folders…")
    local ok = pcall(Library.scan)
    U.card_reset()
    Notify.show(ok and "success" or "error",
        ok and (#Library.games .. " games found") or "Scan failed")
end

local function sync_all_gamesettings()
    local GL = require("core.gameset_loader")
    local GM = require("core.gameset_manager")
    local n = 0
    for _, g in ipairs(Library.games) do
        local bundled = GL.for_game(g.id)
        if bundled and #GM.list_for(g.id) == 0 then
            GL.deploy(bundled, g.id)
            n = n + 1
        end
    end
    if n == 0 then Notify.show("info", "GameSettings already up to date")
    else Notify.show("success", n .. " game(s) updated with bundled GameSettings") end
end


local function missing_booster()
    local missing = 0
    for _, g in ipairs(Library.games) do
        if Cheats.has_boost(g.id) and #Cheats.missing(g.id) > 0 then missing = missing + 1 end
    end
    return missing
end
local function missing_gamesettings()
    local missing = 0
    local GL = require("core.gameset_loader")
    local GM = require("core.gameset_manager")
    for _, g in ipairs(Library.games) do
        local bundled = GL.for_game(g.id)
        if bundled and #GM.list_for(g.id) == 0 then missing = missing + 1 end
    end
    return missing
end

local function missing_badge(fn)
    local m = memo(fn, 2.0)
    return function()
        local n = m()
        if n == 0 then return { text = "OK", color = K.C.ok } end
        return { text = n .. " missing", color = K.C.warn, compact = true }
    end
end

local function sections()
    local vault_sub = memo(function()
        local n = 0
        for _, c in ipairs(require("core.mods").CATS) do
            n = n + #require("core.mods").entries(c)
        end
        return n .. " installed"
    end, 5)
    local compat_sub = memo(function()

        local ok, C = pcall(require, "core.compatibility")

        if not ok then return "?" end

        pcall(C.load)

        return C.count .. " games"

    end, 5.0)
    return {
        LIBRARY = {
            { kind = "action", label = "ROM folders", icon = "folder",
              sub = function() return #(Settings.get("rom_paths") or {}) .. " set" end,
              run = function() require("ui").go("folders") end },
            { kind = "action", label = "Rescan library", icon = "rescan",
              sub = function() return #Library.games .. " games" end, run = rescan },
            { kind = "action", label = "Compatibility list", icon = "chart", editor_label = "Browse",
              sub = compat_sub,
              run = function() require("ui").go("compat_list") end },
            { kind = "action", label = "Download Booster Pack", icon = "cheats",
              badge = missing_badge(missing_booster),
              run = function()
                  local need, seen = {}, {}
                  for _, g in ipairs(Cheats.library({ boost_only = true })) do
                      for _, id in ipairs(Cheats.missing(g.id)) do
                          if not seen[id] then seen[id] = true; need[#need + 1] = id end
                      end
                  end
                  if #need == 0 then Notify.show("info", "Cheats already up to date")
                  else
                      Cheats.sync(need)
                      Notify.show("download", #need .. " cheat file(s) downloading in the background")
                  end
              end },
            { kind = "action", label = "Download GameSettings", icon = "file",
              badge = missing_badge(missing_gamesettings),
              run = sync_all_gamesettings },
        },
        EDITORS = {
            { kind = "action", label = "Profile Editor", icon = "profile", editor_label = "Editor",
              run = function() require("ui").go("rt_profiles") end },
            { kind = "action", label = "Controller Key Map", icon = "gamepad", editor_label = "Editor",
              run = function() require("ui").go("controller_profiles") end },
            { kind = "action", label = "GameSettings Editor", icon = "file", editor_label = "Editor",
              run = function() require("ui").go("gameset_browser") end },
            { kind = "action", label = "Hotkeys", icon = "hotkeys", sub = "design combos",
              run = function() require("ui").go("hotkeys", {}) end },
            { kind = "action", label = "Rt:Stream", icon = "play", sub = "play from your PC",
              run = function() require("ui").go("stream_library") end },
            { kind = "action", label = "Mod Vault", icon = "mods", sub = vault_sub,
              run = function() require("ui").go("mods", {}) end },
        },
        DISPLAY = {
            cyc("Orientation", "orient", { "upright", "sideways" }, "upright"),
            cyc("Boot intro", "boot_anim", { "full", "quick", "off" }, "full"),
            cyc("Effects", "fx", { "off", "lite", "full" }, "lite", function(v) K.fx = v end),
            cyc("Palette", "palette", { "gc", "wii", "aurora" }, "gc", function(v) if K.set_palette then K.set_palette(v) end end),
            cyc("Frame cap", "fps_cap", { 30, 45, 60 }, 60, function(v) love.fps_cap = v end),
            tog("Idle power saver", "idle_fps", true),
            tog("Sound effects", "sfx_on", true, function(v) require("ui.sfx").set_enabled(v) end),
        },
        SYSTEM = {
            tog("Confirm before quitting", "confirm_quit", true),
            -- stessa chiave che legge boot_initializer (prima: enable_update_check, mai letta)
            tog("Update check on boot", "auto_update_check", true),
            tog("Compatibility data", "enable_compat_data", true,
                function() pcall(function() require("core.compatibility").load(true) end) end),
            { kind = "action", label = "Latest release", icon = "rescan",
              sub = function() local l = Updater.latest(); return l and l.tag or "check" end,
              run = function()
                  Updater.check_async(function(d) Notify.show("info", "Latest: " .. d.tag) end)
                  Notify.show("info", "Checking\226\128\166")
              end },
        },
        ABOUT = {
            { kind = "action", label = "Diagnostics", icon = "list", editor_label = "Viewer",
              run = function() require("ui").go("diagnostics") end },
            { kind = "action", label = "Rt:Core Env Triage", icon = "info", sub = "I · II · III health check",
              run = function() SFX.play("menu_select"); require("ui").go("triage") end },
            { kind = "action", label = "About", icon = "play", sub = "credits & version",
              run = function() require("ui").go("about") end },
        },
    }
end

local function build(keep_sel)
    S.rows = sections()[CATS[S.sec].id] or {}
    S.list:set(S.rows, false)
    if keep_sel then S.list.sel = math.max(1, math.min(keep_sel, #S.rows)); S.list:_aim(true) end
    K.set_accent(CATS[S.sec].color)
end

local function go_section(i, dir)
    local n = #CATS
    S.sec = (i - 1) % n + 1
    S.sec_dir = dir or 1
    S.sec_t = 0
    build()
    SFX.play("menu_pagescroll")
end

function S.enter() S.t = 0; build() end

function S.update(dt)
    S.t = S.t + dt
    S.sec_t = math.min(1, S.sec_t + dt * 5)
    S.list:update(dt)
    Updater.poll()
    if S.list.sel ~= S._last_sel then S._last_sel = S.list.sel; S._sel_t = 0 end
    S._sel_t = S._sel_t + dt
end

-- ── input ──────────────────────────────────────────────────
local function cycle(row, d)
    local vals = row.values or ((type(row.list) == "function") and row.list() or row.list) or {}
    if #vals == 0 then return end
    local cur, idx = row.get(), 1
    for i, v in ipairs(vals) do if v == cur then idx = i end end
    row.set(vals[(idx - 1 + d) % #vals + 1])
    SFX.play("menu_move")
end

function S.pad(b)
    local row = S.list:cur()
    if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "L1" then go_section(S.sec - 1, -1)
    elseif b == "R1" then go_section(S.sec + 1, 1)
    elseif (b == "LEFT" or b == "RIGHT") and row then
        local d = (b == "LEFT") and -1 or 1
        if row.kind == "choice" then cycle(row, d)
        elseif row.kind == "toggle" then row.set(b == "RIGHT"); SFX.play("menu_toggleoption") end
    elseif b == "A" and row then
        if row.kind == "action" then row.run()
        elseif row.kind == "choice" then cycle(row, 1)
        elseif row.kind == "toggle" then row.set(not row.get()); SFX.play("menu_toggleoption") end
    elseif b == "B" then require("ui").back() end
end

function S.save_state() return { sel = S.list.sel, sec = S.sec } end
function S.restore_state(st)
    if not st then return end
    if st.sec and CATS[st.sec] then S.sec = st.sec end
    build(st.sel)
end

-- ── draw ───────────────────────────────────────────────────
local function draw_row(row, x, y, w, h, focused)
    if not row then return end
    if row.kind == "head" then
        K.text("key", row.label, x + 4, y + h - 22, K.acc, 0.9)
        K.color(K.C.line, 0.6)
        love.graphics.rectangle("fill",
            x + 12 + K.width("key", row.label), y + h - 14,
            w - 24 - K.width("key", row.label), 1)
        return
    end
    K.panel(x, y + 2, w, h - 4, { focus = focused, cut = 6 })
    local tx = x + 14
    if row.icon and K.draw_tool_icon then
        local acc = focused and K.acc or K.C.dim
        K.draw_tool_icon(row.icon, x + 26, y + h / 2, 20, acc, focused and 1 or 0.75)
        tx = x + 46
    end
    K.text("body", row.label, tx, y + h / 2 - 11, focused and K.C.text or K.C.dim)
    local name_end = tx + K.width("body", row.label)
    if row.tag then
        local tc = K.ACC[row.tag.color] or K.C.warn
        local tf = "key"
        local tw = K.width(tf, row.tag.text) + 10
        local tpx = name_end + 10
        K.color(tc, 0.20)
        love.graphics.rectangle("fill", tpx, y + h / 2 - 10, tw, 20, 5, 5)
        K.color(tc, 1)
        love.graphics.rectangle("line", tpx, y + h / 2 - 10, tw, 20, 5, 5)
        K.text(tf, row.tag.text, tpx + 5, y + h / 2 - 7, tc)
        name_end = tpx + tw
    end
    if row.editor_label and focused then
        local a = math.min(1, (S._sel_t or 0) * 5)
        local slide = (1 - a) * 4
        local lx = name_end + 12
        local cy = y + h / 2 + slide
        K.color(K.acc, 0.20 * a)
        love.graphics.circle("fill", lx + 9, cy, 10)
        K.color(K.acc, 1.0 * a)
        love.graphics.setLineWidth(1.4)
        love.graphics.circle("line", lx + 9, cy, 10)
        love.graphics.setLineWidth(1)
        K.text("key", "A", lx + 5, cy - 7, K.acc, a)
        K.text("small", row.editor_label:upper(), lx + 24, cy - 8, K.acc, a)
    end
    local right = x + w - 14
    if row.kind == "toggle" then
        K.switch(right - 38, y + h / 2, row.get(), focused)
        return
    end
    if row.badge and type(row.badge) == "function" then
        local b = row.badge()
        if b and b.text then
            local compact = b.compact
            local f  = compact and "small" or "h"
            local ph = compact and 8 or 11
            local pv = compact and 8 or 13
            local tw = K.width(f, b.text)
            local bw = tw + ph * 2
            K.color(b.color, compact and 0.18 or 0.22)
            love.graphics.rectangle("fill", right - bw, y + h / 2 - pv, bw, pv * 2, 5, 5)
            K.color(b.color, 1)
            love.graphics.rectangle("line", right - bw, y + h / 2 - pv, bw, pv * 2, 5, 5)
            K.text(f, b.text, right - bw + ph, y + h / 2 - (compact and 7 or 10), b.color)
        end
        return
    end
    if row.kind == "choice" then
        local v = tostring(row.get() or ""):upper()
        local lw = K.width("value", v)
        K.text("value", v, right - lw, y + h / 2 - 10, focused and K.acc or K.C.text)
        if focused then
            K.text("body", "<", right - lw - 14, y + h / 2 - 11, K.C.faint)
            K.text("body", ">", right + 2, y + h / 2 - 11, K.C.faint)
        end
        return
    end
    if row.kind == "action" then
        local sub = type(row.sub) == "function" and row.sub() or row.sub
        if sub then
            K.text("small", sub, right - K.width("small", sub) - 16,
                   y + h / 2 - 9, row.danger and K.C.warn or K.C.faint)
        end
        K.text("body", ">", right - 8, y + h / 2 - 11, focused and K.acc or K.C.faint)
    end
end


-- titolo grande + icona dedicata nel colore della sezione + chip delle 5 sezioni
local function draw_header()
    local c = CATS[S.sec]
    local acc = K.ACC[c.color] or K.ACC.gc
    local m = K.MARGIN
    local cx, cy, r = m + 26, 42, 26
    K.color(acc, 0.16); love.graphics.circle("fill", cx, cy, r)
    K.color(acc, 1); love.graphics.setLineWidth(2); love.graphics.circle("line", cx, cy, r)
    love.graphics.setLineWidth(1)
    K.draw_tool_icon(c.icon, cx, cy, 30, acc, 1)

    local tx = m + 64
    local slide = (1 - (1 - (1 - S.sec_t) ^ 3)) * 0       -- (titolo fermo, scorre solo la lista)
    K.text("xl", K.clip("xl", c.label, 270), tx + slide, 6, K.C.text)
    K.text("small", ("Settings  \194\183  %d / %d"):format(S.sec, #CATS), tx, 50, K.C.dim)

    -- chip sezioni (L1 R1)
    local chip, gap = 34, 6
    local total = #CATS * chip + (#CATS - 1) * gap
    local x0 = K.W - m - total
    K.text("key", "L1", x0 - 26, 30, K.C.faint)
    K.text("key", "R1", x0 + total + 4, 30, K.C.faint)
    for i, cat in ipairs(CATS) do
        local ca = K.ACC[cat.color] or K.ACC.gc
        local on = (i == S.sec)
        local x = x0 + (i - 1) * (chip + gap)
        K.color(ca, on and 0.30 or 0.08); love.graphics.rectangle("fill", x, 24, chip, 30, 6, 6)
        K.color(ca, on and 1 or 0.35);    love.graphics.rectangle("line", x, 24, chip, 30, 6, 6)
        K.draw_tool_icon(cat.icon, x + chip / 2, 39, 15, ca, on and 1 or 0.55)
    end

    K.color(acc, 1); love.graphics.rectangle("fill", m, 78, 72, 3)
    K.color(K.C.line, 0.5); love.graphics.rectangle("fill", m + 72, 79, K.W - m * 2 - 72, 1)
end

function S.draw()
    K.bg_workshop(S.t)
    draw_header()
    local e = 1 - (1 - S.sec_t) ^ 3
    love.graphics.push()
    love.graphics.translate(S.sec_dir * (1 - e) * 36, 0)       -- la lista scivola dentro
    S.list:draw(draw_row)
    love.graphics.pop()
    K.footer({
        { key = "A", label = "Change" },
        { key = "< >", label = "Value" },
        { key = "L1 R1", label = "Section" },
        { key = "B", label = "Back" },
    })
end

return S
