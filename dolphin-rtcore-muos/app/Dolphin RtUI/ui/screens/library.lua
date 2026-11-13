-- ui/screens/library.lua — the home screen.
-- Left: filtered game list. Right: cover + what will happen on launch.
-- [A] play  [X] game options  [Y] favourite  [L1/R1] filter  [L2/R2] jump
-- by letter  [START] settings
local K        = require("ui.kit")
local SFX      = require("ui.sfx")
local U        = require("ui.util")
local Notify   = require("ui.notify")
local Modal    = require("ui.modal")
local Library  = require("core.library")
local Settings = require("core.settings")
local Launcher = require("core.launcher")
local Cheats   = require("core.rtcheats")
local ok_cv, Cover = pcall(require, "core.cover_loader")
local Mascot   = require("ui.mascot")
local ok_cp, Compat = pcall(require, "core.compatibility")

local S = {}

-- ── sprite sheet config (edit cols/rows if the 3d assets change) ──
local SPRITE_CFG = {
    gc  = { path = "assets/images/3d_assets/gc_spritesheet_192.png",                   cols = 32, rows = 1, fps = 12 },
    wii = { path = "assets/images/3d_assets/wii_spritesheet_256.png",                  cols = 32, rows = 1, fps = 12 },
    fav = { path = "assets/images/3d_assets/dolphin_swim_spin_spritesheet_320.png",    cols = 32, rows = 1, fps = 12 },
}
local _sprites = {}
local function sprite_for(id)
    if _sprites[id] ~= nil then return _sprites[id] or nil end
    local c = SPRITE_CFG[id]
    if not c then _sprites[id] = false; return nil end
    local s = K.load_sprite(c.path, c.cols, c.rows)
    _sprites[id] = s or false
    return s
end
local function draw_icon_3d(id, cx, cy, size, t)
    local s = sprite_for(id)
    if not s then return false end
    local c = SPRITE_CFG[id]
    K.draw_sprite(s, cx, cy, size, nil, c.fps, t)
    return true
end

local FILTERS = { "GC", "WII", "FAV" }
local LX, LY, LW = K.MARGIN, 96, 276
local LH = K.BOT - LY
S.list = K.List(LX, LY, LW, LH, 36)
S.filter = 1
S.t = 0
S.sel_t = 1

local function favs() return Settings.get("favorites") or {} end

local function rebuild(keep_id)
    local fav, items = favs(), {}
    local f = FILTERS[S.filter]
    for _, g in ipairs(Library.games or {}) do
        local keep = (f == "GC" and g.system == "GC")
                     or (f == "WII" and U.is_wii(g))
                     or (f == "FAV" and fav[g.id])
        if keep then items[#items + 1] = g end
    end
    table.sort(items, function(a, b) return (a.title or ""):lower() < (b.title or ""):lower() end)
    S.list:set(items, false)
    if keep_id then
        for i, g in ipairs(items) do if g.id == keep_id then S.list.sel = i; S.list:_aim(true); break end end
    end
end

function S.enter()
    S.t = 0
    S.compat_memo = {}
    if ok_cp and Compat then pcall(Compat.load) end      -- ricarica solo se il file e' cambiato
    S.need_scan = (#(Library.games or {}) == 0)
    rebuild(S.keep_id or Settings.get("last_game"))
    S.keep_id = nil
end

function S.update(dt)
    S.t = S.t + dt
    S.list:update(dt)
    -- Scan incrementale: ~10 ms per frame, la UI resta fluida e la lista si
    -- riempie man mano (prima: Library.scan() bloccava tutto per secondi).
    if S.need_scan and S.t > 0.2 then
        S.need_scan = false
        if pcall(Library.scan_begin) then S.scanning = true; S.scan_t = 0; S.scan_seen = 0 end
    end
    if S.scanning then
        S.scan_t = S.scan_t + dt
        local ok, fin = pcall(Library.scan_step, 0.010)
        local count = #(Library.games or {})
        if (not ok) or fin then
            S.scanning = false
            local c = S.list:cur()
            rebuild(c and c.id or nil)
        elseif count ~= S.scan_seen and S.scan_t > 0.3 then
            S.scan_seen, S.scan_t = count, 0
            local c = S.list:cur()
            rebuild(c and c.id or nil)
        end
    end
    local g = S.list:cur()
    K.set_accent(g and U.is_wii(g) and "wii" or "gc")
end

local function cur() return S.list:cur() end

local launch = U.launch

local function toggle_fav(g)
    if not g then return end
    local f = favs()
    f[g.id] = (not f[g.id]) or nil
    Settings.set("favorites", f)
    SFX.play("menu_toggleoption")
    if FILTERS[S.filter] == "FAV" then rebuild() end
end

local function jump_letter(d)
    local items, i = S.list.items, S.list.sel
    if #items == 0 then return end
    local cur_l = (items[i].title or "?"):sub(1, 1):upper()
    local j = i
    while true do
        j = j + d
        if j < 1 or j > #items then return end
        local l = (items[j].title or "?"):sub(1, 1):upper()
        if l ~= cur_l then
            if d < 0 then   -- land on the first entry of that letter
                while j > 1 and (items[j - 1].title or "?"):sub(1, 1):upper() == l do j = j - 1 end
            end
            S.list.sel = j; S.list:_aim(); SFX.play("menu_pagescroll"); return
        end
    end
end

-- NEXUS action adapters. The UI layer owns navigation; this screen owns
-- library semantics. Call once after screen registration in ui/init.lua.
function S.register_actions(ui)
    if not ui or type(ui.register_action) ~= "function" then
        return false, "UI action registrar unavailable"
    end

    local function selected()
        return cur()
    end
    local specs = {
        {
            id = "library.rescan", title = "Rescan ROM library", order = 10,
            run = function()
                if S.scanning then return false, "scan already in progress" end
                S.need_scan = false
                local ok, err = pcall(Library.scan_begin)
                if not ok then return false, tostring(err) end
                S.scanning, S.scan_t, S.scan_seen = true, 0, 0
                return true
            end,
        },
        {
            id = "library.launch_selected", title = "Launch selected game", order = 20,
            run = function()
                local g = selected()
                if not g then return false, "no game selected" end
                local ok, err = launch(g)
                if ok == false then return false, err or "launch request was rejected" end
                return true
            end,
        },
        {
            id = "library.open_selected_options", title = "Open selected game options", order = 30,
            run = function()
                local g = selected()
                if not g then return false, "no game selected" end
                S.keep_id = g.id
                return ui.go("game", { game = g })
            end,
        },
        {
            id = "library.toggle_selected_favorite", title = "Toggle selected favorite", order = 40,
            run = function()
                local g = selected()
                if not g or not g.id then return false, "selected game has no valid ID" end
                toggle_fav(g)
                return true
            end,
        },
        {
            id = "library.set_filter", title = "Set library filter", order = 50,
            run = function(filter)
                local index = type(filter) == "number" and filter or nil
                if not index and type(filter) == "string" then
                    local wanted = filter:upper()
                    for i, name in ipairs(FILTERS) do
                        if name == wanted then index = i; break end
                    end
                end
                if not index or index % 1 ~= 0 or index < 1 or index > #FILTERS then
                    return false, "filter must be GC, WII, FAV, or index 1-3"
                end
                local g = selected()
                S.filter = index
                rebuild(g and g.id or nil)
                return true
            end,
        },
    }

    local failures = {}
    for _, spec in ipairs(specs) do
        local ok, err = ui.register_action(spec.id, spec.run, {
            title = spec.title, group = "library", screen = "library", order = spec.order,
        })
        if not ok then
            -- Duplicate registration is reported by NEXUS; keep initialization
            -- resilient while making the failure visible in the UI log.
            failures[#failures + 1] = spec.id .. ": " .. tostring(err)
        end
    end
    if #failures > 0 then
        return false, table.concat(failures, "; ")
    end
    return true
end

function S.leave() Mascot.release() end

function S.pad(b)
    local g = cur()
    if     b == "UP"    then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN"  then if S.list:move(1)  then SFX.play("menu_move") end
    elseif b == "LEFT"  then S.list:page(-1)
    elseif b == "RIGHT" then S.list:page(1)
    elseif b == "L1" then S.filter = (S.filter - 2) % #FILTERS + 1; rebuild(); SFX.play("menu_pagescroll")
    elseif b == "R1" then S.filter = S.filter % #FILTERS + 1; rebuild(); SFX.play("menu_pagescroll")
    elseif b == "L2" then jump_letter(-1)
    elseif b == "R2" then jump_letter(1)
    elseif b == "A" then
        if g then launch(g) elseif #(Library.games or {}) == 0 then require("ui").go("folders") end
    elseif b == "X" then
        if g then S.keep_id = g.id; SFX.play("menu_select"); require("ui").go("game", { game = g }) end
    elseif b == "Y" then toggle_fav(g)
    elseif b == "START" then require("ui").go("settings")
    elseif b == "SELECT" then SFX.play("menu_select"); require("ui").go("stream_library")
    elseif b == "B" then
        local ui = require("ui")
        if ui.is_root and ui.is_root() then
            if Settings.get("confirm_quit") ~= false then
                Modal.show("Quit", "Close Dolphin Rt:UI?", {
                    accept_label = "Quit", cancel_label = "Stay", color = K.C.bad,
                    on_accept = function() love.event.quit() end })
            else
                love.event.quit()
            end
        else
            ui.back()
        end
    end
end

-- ── drawing ─────────────────────────────────────────────────
local function draw_item(g, x, y, w, h, focused)
    local fav = favs()[g.id]
    local right = x + w - 8
    local sl = U.sys_label(g)
    K.text("key", sl, right - K.width("key", sl), y + h / 2 - 8, U.is_wii(g) and K.ACC.wii or K.ACC.gc, focused and 1 or 0.75)
    right = right - K.width("key", sl) - 12
    if fav then K.star(right - 6, y + h / 2, 6, K.C.warn, 1); right = right - 18 end
    if Cheats.has_boost(g.id) then K.bolt(right - 5, y + h / 2, 14, K.ACC.boost, focused and 1 or 0.7); right = right - 16 end
    K.text("body", K.clip("body", U.clean_title(g.title or g.id), right - x - 14), x + 8, y + h / 2 - 9,
           focused and K.C.text or K.C.dim)
end

local function draw_cover(g, x, y, w, h)
    local cov = ok_cv and Cover.get and Cover.get(g)
    K.color({ 0, 0, 0 }, 0.35); love.graphics.rectangle("fill", x + 3, y + 5, w, h, 6, 6)
    K.color(K.C.surf, 1); love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    if cov then
        local img = cov
        local iw, ih = img:getDimensions()
        local sc = math.min(w / iw, h / ih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, x + (w - iw * sc) / 2, y + (h - ih * sc) / 2, 0, sc, sc)
    else
        K.color(K.acc, 0.12); love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        local ini = (g.title or "?"):gsub("[^%w]", ""):sub(1, 2):upper()
        K.text("title", ini, x, y + h / 2 - 16, K.acc, 0.8, w, "center")
    end
    K.color(K.C.line, 0.8); love.graphics.rectangle("line", x, y, w, h, 6, 6)
end

local function info_row(label, value, x, y, w, c)
    K.text("small", label, x, y, K.C.faint)
    K.text("small", K.clip("small", value, w - 84), x + 84, y, c or K.C.text)
end

-- compat per gioco, memoizzato (lookup + summary non vanno rifatti a ogni frame)
local function compat_for(g)
    if not (ok_cp and Compat) or not g then return nil end
    if not g.id then return nil end
    -- chiave = id + titolo: due ROM con lo stesso id (GEDP01 = Eternal Darkness
    -- e Geist nel DB) non devono condividere il risultato
    local k = g.id .. "|" .. tostring(g.title or "")
    S.compat_memo = S.compat_memo or {}
    local m = S.compat_memo[k]
    if m == nil then
        local ok, grp, approx = pcall(Compat.lookup, g)
        if ok and grp then m = { grp = grp, sum = Compat.summary(grp), approx = approx }
        else m = false end
        S.compat_memo[k] = m
    end
    return m or nil
end

local function draw_stars(x, y, rating)
    for i = 1, 5 do
        local on = rating >= i - 0.25
        K.star(x + (i - 1) * 16, y, 6.5, on and K.C.warn or K.C.line, on and 1 or 0.6)
    end
end

local function draw_detail(g)
    local px, py, pw, ph = 316, LY, K.W - 316 - K.MARGIN, LH
    K.panel(px, py, pw, ph, { cut = 12 })
    if not g then
        K.text("body", "No game selected", px, py + ph / 2 - 10, K.C.faint, 1, pw, "center")
        return
    end
    draw_cover(g, px + 14, py + 14, 130, 182)
    local cx = px + 158
    K.pill(U.sys_label(g), cx + 56, py + 26, U.is_wii(g) and K.ACC.wii or K.ACC.gc, true)
    if g.region and g.region ~= "" then K.pill(g.region, cx + 56 + 62, py + 26, K.C.dim, false) end
    local ext = (g.file or ""):match("%.(%w+)$")
    local sz = U.human_size(g.size) .. (ext and ("  \194\183  " .. ext:upper()) or "")
    K.text("small", sz, cx, py + 48, K.C.dim)
    local cm = compat_for(g)
    if cm then
        local sm = cm.sum
        local pc = K.C[sm.play_kind] or K.C.dim
        K.text("small", (cm.approx and "~ " or "") .. sm.play_label, cx, py + 74, pc)
        local l2 = sm.has_fps and (sm.fps .. " FPS") or sm.boot_label
        K.text("small", l2, cx, py + 94, (not sm.has_fps and K.C[sm.boot_kind]) or K.C.dim)
        draw_stars(cx + 7, py + 122, sm.stars)
        K.text("small", sm.stars > 0 and ("%.1f"):format(sm.rating) or "n/a", cx + 88, py + 114, K.C.faint)
    else
        K.text("small", "No compatibility data", cx, py + 74, K.C.faint)
    end
    if Cheats.has_boost(g.id) then
        K.bolt(cx + 6, py + 150, 14, K.ACC.boost, 1)
        K.text("small", "Boost patches", cx + 18, py + 142, K.ACC.boost)
    end
    K.text("h", K.clip("h", U.clean_title(g.title or g.id), pw - 28), px + 14, py + 208, K.C.text)
    local y = py + 238
    local prof = U.card_get(g, "LAUNCH", "RtProfile") or "Default"
    local var  = (U.card_get(g, "LAUNCH", "RtProfileVariant") or "std"):upper()
    local ptxt = prof
    if U.is_family and U.is_family(prof) then
        ptxt = prof .. "  ·  " .. var
    end
    info_row("Profile", ptxt, px + 14, y, pw - 28); y = y + 22
    info_row("Controller", U.card_get(g, "LAUNCH", "Controller") or "Default", px + 14, y, pw - 28); y = y + 22
    local ch = U.cheats_active(g)
    info_row("Cheats", ch and "on" or "off", px + 14, y, pw - 28, ch and K.C.ok or K.C.dim)
    -- quick fade-in whenever the selection changes
    local p = math.min(1, S.sel_t / 0.16)
    if p < 1 then
        K.color(K.C.surf, 0.96 * (1 - p))
        love.graphics.rectangle("fill", px + 2, py + 2, pw - 4, ph - 4)
    end
end

-- ── brand header ─────────────────────────────────────────
local _icon_cache = {}
local function get_icon(path)
    if _icon_cache[path] == nil then
        local ok, img = pcall(love.graphics.newImage, path)
        _icon_cache[path] = (ok and img) or false
    end
    return _icon_cache[path] or nil
end

local function library_totals()
    local total, gc, wii = 0, 0, 0
    for _, game in ipairs(Library.games or {}) do
        total = total + 1
        if U.is_wii(game) then wii = wii + 1 else gc = gc + 1 end
    end
    local ok, installed = pcall(U.mods_installed)
    return total, gc, wii, (ok and type(installed) == "table") and #installed or nil
end

local function draw_brand_header(n_games)
    local t = love.timer.getTime()
    local acc = K.ACC.gc
    if     S.filter == 2 then acc = K.ACC.wii
    elseif S.filter == 3 then acc = K.ACC.boost end
    K.set_accent(acc)

    -- animated 3D icon
    local cx, cy = 56, 48
    local drew = false
    if S.filter == 1 then
        drew = draw_icon_3d("gc", cx, cy, 76, t)
    elseif S.filter == 2 then
        drew = draw_icon_3d("wii", cx, cy, 76, t)
    else
        drew = draw_icon_3d("fav", cx, cy, 76, t)
    end
    if not drew then
        local pulse = 0.85 + 0.15 * math.sin(t * 4)
        K.star(cx, cy, 26 * pulse, acc, 1)
    end

    -- title
    K.text("title", "DOLPHIN RT:CORE UI", 104, 14, K.C.text)

    -- line under title
    K.color(acc, 0.9)
    love.graphics.rectangle("fill", 104, 42, K.W - K.MARGIN - 104 - 200, 2)

    -- Live inventory: valid native metadata entries from Sys/Load + user Load.
    local total, gc, wii, gfx = library_totals()
    local gfx_label = gfx and tostring(gfx) or "—"
    local summary
    if S.scanning or Library.scanning then
        local p = Library.progress or { done = 0, total = 0 }
        summary = ("SCAN %d/%d  ·  %d found  ·  GFX %s"):format(
            p.done or 0, p.total or 0, total, gfx_label)
    elseif S.filter == 3 then
        summary = ("%d ROMs  ·  %d fav  ·  GFX %s"):format(total, n_games, gfx_label)
    else
        summary = ("%d ROMs  ·  GC %d  ·  Wii %d  ·  GFX %s"):format(
            total, gc, wii, gfx_label)
    end
    K.text("key", K.clip("key", summary, K.W - K.MARGIN - 104 - 200),
           104, 50, K.C.dim, 0.95)

    -- separator
    K.color(K.C.line, 0.5)
    love.graphics.rectangle("fill", K.MARGIN, 72, K.W - K.MARGIN * 2, 1)

    -- tabs on the right
    local fx = K.W - K.MARGIN
    for i = #FILTERS, 1, -1 do
        local name = FILTERS[i]
        local on = (i == S.filter)
        local col
        if     i == 1 then col = K.ACC.gc
        elseif i == 2 then col = K.ACC.wii
        elseif i == 3 then col = K.ACC.boost end
        local w = (i == 3) and 32 or (K.width("key", name) + 20)
        fx = fx - w
        if on then
            K.color(col, 0.28); love.graphics.rectangle("fill", fx, 26, w, 28, 6, 6)
            K.color(col, 1);    love.graphics.rectangle("line", fx, 26, w, 28, 6, 6)
        else
            K.color(K.C.surf, 0.85); love.graphics.rectangle("fill", fx, 26, w, 28, 6, 6)
            K.color(K.C.line, 0.55); love.graphics.rectangle("line", fx, 26, w, 28, 6, 6)
        end
        if i == 3 then
            K.star(fx + w / 2, 40, 9, on and col or K.C.dim, 1)
        else
            K.text("key", name, fx + 10, 34, on and K.C.text or K.C.dim)
        end
        fx = fx - 6
    end
end


function S.draw()
    -- doc panel viene disegnato alla fine
    local g = cur()
    local n = #S.list.items
    draw_brand_header(n)
    local scanning = S.scanning or Library.scanning
    if scanning then
        local p = Library.progress or { done = 0, total = 0 }
        local frac = (p.total > 0) and (p.done / p.total) or 0
        -- Header separator is y=72; keep the bar in the clear gap below it.
        K.bar(K.MARGIN, 78, K.W - K.MARGIN * 2, 2, frac, K.acc)
    end
    if n == 0 then
        K.panel(LX, LY, K.W - K.MARGIN * 2, LH, { cut = 12 })
        local msg = scanning and "Scanning ROMs\226\128\166"
            or (#(Library.games or {}) == 0)
            and "No games found.\nPress A to add a ROM folder."
            or "Nothing matches this filter."
        if Mascot.load() then
            Mascot.draw(Mascot.frame_at(S.t, 0.8), K.W / 2, LY + 14, 0.95, 0.9)
            K.text("body", msg, LX, LY + 196, K.C.dim, 1, K.W - K.MARGIN * 2, "center")
        else
            K.text("body", msg, LX, LY + LH / 2 - 24, K.C.dim, 1, K.W - K.MARGIN * 2, "center")
        end
    else
        S.list:draw(draw_item)
        draw_detail(g)
    end
    K.footer({ { key = "A", label = "Play" }, { key = "X", label = "Options" }, { key = "Y", label = "Favourite" }, { key = "SELECT", label = "Stream" },
               { key = "L1 R1", label = "Filter" }, { key = "START", label = "Settings" } })
end

return S
