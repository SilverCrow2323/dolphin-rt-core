-- ui/screens/game.lua — per-game options + doc panel (SELECT/M), rewrite v20.
local K      = require("ui.kit")
local SFX    = require("ui.sfx")
local U      = require("ui.util")
local Notify = require("ui.notify")
local Modal  = require("ui.modal")
local Cheats = require("core.rtcheats")

local S = {}
S.list = K.List(K.MARGIN, 96, K.W - K.MARGIN * 2 - 14, K.BOT - 96, 46)
S.t = 0
S.gauge = { pos = 0, vel = 0, target = 0 }
S._last_sel = 0
S.hero_focus = 0
S._sel_t = 0
S.doc = { open = false, slide = 0, scroll = 0, blocks = {}, total = 0 }

-- ── tier meta ─────────────────────────────────────────────
local TIER_META = {
    lite = { color = { 0.20, 0.85, 1.00 }, frac = 0.30, label = "LITE" },
    std  = { color = { 0.35, 0.90, 0.55 }, frac = 0.65, label = "STANDARD" },
    max  = { color = { 0.95, 0.32, 0.32 }, frac = 1.00, label = "MAX" },
}

-- ── profile colour ────────────────────────────────────────
local _pcache = {}
local function profile_color(name)
    if _pcache[name] then return _pcache[name] end
    local path = "workshop/rtcoreprofile/" .. tostring(name or "Default") .. "/rtprofile_data.ini"
    local f = io.open(path, "r")
    if not f then _pcache[name] = { 0.55, 0.47, 1.0 }; return _pcache[name] end
    local color = { 0.55, 0.47, 1.0 }
    for line in f:lines() do
        if line:match("^%s*Color%s*=") then
            local r, g, b = line:match("#(%x%x)(%x%x)(%x%x)")
            if r then color = { tonumber(r,16)/255, tonumber(g,16)/255, tonumber(b,16)/255 } end
            break
        end
    end
    f:close()
    _pcache[name] = color
    return color
end

-- ── defaults ──────────────────────────────────────────────
local DEFAULTS = {
    RtProfile = "Default", RtProfileVariant = "std", Controller = "Default",
    Hotkeys = "Default", Cheats = "no", Mods = "no",
    OverlayFPS = "no", OverlayVPS = "no", OverlaySpeed = "no", OverlayOSD = "no",
    SafeExit = "yes", GameSettings = "Disabled",
}

local function launch_key(k) return U.card_get(S.game, "LAUNCH", k) or DEFAULTS[k] end
local function put(k, v) U.card_set(S.game, "LAUNCH", k, v) end

local function choices_of(dir, extra)
    local out = U.ls(dir, true)
    if extra then for _, e in ipairs(extra) do out[#out + 1] = e end end
    if #out == 0 then out = { "Default" } end
    return out
end

local function cheat_counts()
    if not S.game or not S.game.id then return 0, 0 end
    local r = U.memo("cheat_counts:" .. S.game.id, 1.5, function()
        local on, total = 0, 0
        for _, e in ipairs(Cheats.load_for(S.game.id)) do
            total = total + 1
            if e.enabled then on = on + 1 end
        end
        return { on, total }
    end)
    return r[1], r[2]
end

local function gamesettings_choices()
    local out = { "Disabled" }
    local seen = {}
    local ok2, GM = pcall(require, "core.gameset_manager")
    if ok2 and GM then
        for _, cfg in ipairs(GM.list_for(S.game.id) or {}) do
            if not seen[cfg.file] then seen[cfg.file] = true; out[#out + 1] = cfg.file end
        end
    end
    local ok, GL = pcall(require, "core.gameset_loader")
    if ok and GL and GL.for_game then
        local bundled = GL.for_game(S.game.id)
        if bundled and bundled.configs then
            for _, cfg in ipairs(bundled.configs) do
                if cfg.filename and not seen[cfg.filename] then
                    seen[cfg.filename] = true; out[#out + 1] = cfg.filename
                end
            end
        end
    end
    return out
end

local function reset_all()
    for k, v in pairs(DEFAULTS) do put(k, v) end
    U.mods_save(S.game, {})
    pcall(function() for _, c in ipairs(require("core.mods").CATS) do if not c.legacy then U.vault_set_off(S.game, c.id, {}) end end end)
    SFX.play("menu_back")
    Notify.show("info", "Options reset")
end

-- ══════════════════════════════════════════════════════════
-- DOC PANEL — build_doc, draw_doc, open_doc
-- (definiti PRIMA di build() perché build() li referenzia)
-- ══════════════════════════════════════════════════════════
local _fallback_disc = {}
local function get_fallback_disc(system)
    if _fallback_disc[system] ~= nil then return _fallback_disc[system] or nil end
    local path = (system == "Wii") and "assets/images/wii_disc.png" or "assets/images/gc_disc.png"
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then img:setFilter("linear","linear"); _fallback_disc[system] = img; return img end
    _fallback_disc[system] = false
    return nil
end

local function get_disc_texture(g)
    local ok, Disc = pcall(require, "core.disc_loader")
    if ok and Disc and Disc.get then
        local r = pcall(function() return Disc.get(g) end)
        if r and type(r) == "userdata" then return r end
        if r and type(r) == "table" and r.getDimensions then return r end
    end
    return get_fallback_disc(g.system)
end

local function build_doc(g)
    local blocks = {}
    local add = function(t) blocks[#blocks+1] = t end

    add({ kind = "header", g = g })
    add({ kind = "divider" })

    -- LAUNCH
    add({ kind = "h", text = "LAUNCH CONFIG" })
    local prof = U.card_get(g, "LAUNCH", "RtProfile") or "Default"
    local tier = U.card_get(g, "LAUNCH", "RtProfileVariant")
    local ptxt = prof
    if U.is_family and U.is_family(prof) and tier then ptxt = prof .. "  ·  " .. tier:upper() end
    add({ kind = "row", label = "Profile", value = ptxt })
    add({ kind = "row", label = "Controller", value = U.card_get(g, "LAUNCH", "Controller") or "Default" })
    add({ kind = "row", label = "Hotkeys", value = U.card_get(g, "LAUNCH", "Hotkeys") or "Default" })
    add({ kind = "row", label = "Safe Exit", value = U.yes(U.card_get(g, "LAUNCH", "SafeExit") or "yes") and "ON" or "OFF" })
    add({ kind = "row", label = "Cheats", value = U.cheats_active(g) and "ON" or "OFF" })
    local on, tot = 0, 0
    for _, e in ipairs(Cheats.load_for(g.id)) do tot = tot + 1; if e.enabled then on = on + 1 end end
    add({ kind = "row", label = "Cheat files", value = on .. " / " .. tot })
    local nmods = U.vault_counts(g)
    add({ kind = "row", label = "Mod Vault", value = nmods .. " active" })
    add({ kind = "row", label = "GameSettings", value = U.card_get(g, "LAUNCH", "GameSettings") or "Disabled" })
    add({ kind = "divider" })

    -- COMPAT
    add({ kind = "h", text = "COMPATIBILITY DATABASE" })
    local ok, C = pcall(require, "core.compatibility")
    if ok and C and C.load then pcall(C.load) end        -- ricarica solo se il file e' cambiato
    local compat, approx
    if ok and C and C.lookup then
        local ok2, a, b = pcall(C.lookup, g)
        if ok2 then compat, approx = a, b end
    end
    if compat then
        local sm = C.summary(compat)
        add({ kind = "row", label = "Playable", value = (approx and "~ " or "") .. sm.play_label })
        add({ kind = "row", label = "Boot", value = sm.boot_label })
        add({ kind = "row", label = "Rating", value = sm.rating_text })
        add({ kind = "row", label = "FPS", value = sm.has_fps and sm.fps or "N/A" })
        add({ kind = "row", label = "Test entries", value = tostring(sm.n) })
        if sm.profiles ~= "" then add({ kind = "row", label = "Profiles", value = sm.profiles }) end
        if sm.devices ~= "" then add({ kind = "row", label = "Devices", value = sm.devices }) end
        if approx then
            add({ kind = "text", text = "Matched by game code (other publisher/revision of the same game)." })
        end
        -- note: prima quelle delle entry migliori (rating piu' alto), max 3, max 220 char
        local sorted = {}
        for _, e in ipairs(compat.entries or {}) do sorted[#sorted + 1] = e end
        table.sort(sorted, function(x, y)
            return ((x.norm and x.norm.rating) or 0) > ((y.norm and y.norm.rating) or 0)
        end)
        local shown = 0
        for _, e in ipairs(sorted) do
            local nt = e.norm and e.norm.note or ""
            if nt ~= "" then
                if #nt > 220 then nt = nt:sub(1, 217):gsub("[\192-\255][\128-\191]*$", "") .. "..." end
                add({ kind = "text", text = "\226\128\162 " .. nt })
                shown = shown + 1
                if shown >= 3 then break end
            end
        end
    else
        add({ kind = "text", text = "No compatibility data for this game." })
    end
    add({ kind = "divider" })
    add({ kind = "text", text = "silvercrow2323.github.io/Dolphin-Core-for-MuOS" })

    -- altezza
    local fh = K.font("small"):getHeight()
    local total = 0
    for _, b in ipairs(blocks) do
        if b.kind == "header" then total = total + 94
        elseif b.kind == "h" then total = total + 30
        elseif b.kind == "row" then total = total + 24
        elseif b.kind == "divider" then total = total + 14
        elseif b.kind == "text" then
            local _, lines = K.font("small"):getWrap(b.text, 340)
            total = total + #lines * fh + 6
        end
    end
    return blocks, total
end

local function draw_doc(g, blocks)
    local pw = 390
    local px = -pw * (1 - S.doc.slide)
    local ph = K.H
    local acc = K.acc or K.ACC.gc

    K.color({0,0,0}, 0.60 * S.doc.slide)
    love.graphics.rectangle("fill", 0, 0, K.W, K.H)

    K.color({0.11,0.12,0.15}, 1)
    love.graphics.rectangle("fill", px, 0, pw, ph)
    for i = 0, ph, 4 do
        K.color({1,1,1}, 0.01); love.graphics.rectangle("fill", px, i, pw, 1)
    end
    K.color(acc, 0.9); love.graphics.rectangle("fill", px + pw - 3, 0, 3, ph)

    K.text("title", "Documentation", px + 20, 18, K.C.text)
    K.color(acc, 0.5); love.graphics.rectangle("fill", px + 20, 52, pw - 40, 1)

    love.graphics.setScissor(px, 64, pw, ph - 96)
    local y = 76 - S.doc.scroll
    local text_w = pw - 40

    for _, b in ipairs(blocks) do
        if b.kind == "header" then
            local cov = nil
            local okc, Cover = pcall(require, "core.cover_loader")
            if okc and Cover and Cover.get then cov = Cover.get(b.g) end
            if cov then
                local iw, ih = cov:getDimensions()
                local sc = math.min(96/iw, 128/ih)
                love.graphics.setColor(1,1,1,1)
                love.graphics.draw(cov, px + 20, y, 0, sc, sc)
            else
                K.color(K.C.surf, 1); love.graphics.rectangle("fill", px + 20, y, 96, 128, 6, 6)
            end
            local tx = px + 128
            K.text("h", K.clip("h", U.clean_title(b.g.title or b.g.id or "?"), pw - 150), tx, y, K.C.text)
            K.region_flag(b.g.region or "?", tx, y + 28, 44, 20)
            K.id_plate(b.g.id or "??????", tx + 50, y + 28, 96, 20)
            y = y + 94
        elseif b.kind == "h" then
            K.text("key", b.text, px + 20, y, acc); y = y + 30
        elseif b.kind == "row" then
            K.text("small", b.label, px + 20, y, K.C.faint)
            local vw = K.width("small", tostring(b.value))
            K.text("small", tostring(b.value), px + pw - 20 - vw, y, K.C.text)
            y = y + 24
        elseif b.kind == "divider" then
            K.color(acc, 0.4); love.graphics.rectangle("fill", px + 20, y, pw - 40, 1); y = y + 14
        elseif b.kind == "text" then
            local f = K.font("small")
            local _, lines = f:getWrap(b.text, text_w)
            local th = #lines * f:getHeight()
            K.para("small", b.text, px + 20, y, text_w, K.C.dim)
            y = y + th + 6
        end
    end
    love.graphics.setScissor()

    -- footer hint
    K.color(acc, 0.6); love.graphics.rectangle("fill", px + 20, ph - 32, pw - 40, 1)
    K.text("small", "UP/DOWN scroll  ·  B close", px + 20, ph - 24, K.C.faint)
end

local function open_doc(g)
    if not g then return end
    S.doc.blocks, S.doc.total = build_doc(g)
    S.doc.open = true
    S.doc.scroll = 0
    SFX.play("menu_flip")
end

-- ══════════════════════════════════════════════════════════
-- BUILD menu
-- ══════════════════════════════════════════════════════════
local function build()
    local g = S.game
    local sysdir = U.is_wii(g) and "Wii" or "GameCube"

    S.rows = {
        { kind = "action", label = "PLAY", play = true, _h = 96,
          overlays = {
              { key = "OverlayFPS",   label = "FPS" },
              { key = "OverlayVPS",   label = "VPS" },
              { key = "OverlaySpeed", label = "Speed" },
              { key = "OverlayOSD",   label = "OSD" },
          },
          run = function() U.launch(g) end },

        { kind = "section", label = "PERFORMANCE", icon = "gear", color = "gc", skip = true },
        { kind = "choice", label = "Profile", icon = "profile", profile_label = true,
          editor_label = "Editor",
          editor_target = "rt_profiles",
          editor_params = function() return { focus = launch_key("RtProfile") } end,
          list = function() return choices_of("workshop/rtcoreprofile") end,
          get  = function() return launch_key("RtProfile") end,
          set  = function(v)
              put("RtProfile", v)
              local sel = S.list.sel
              build()
              S.list.sel = math.min(sel, #S.list.items)
          end },
        { kind = "choice", label = "Tier", icon = "tier", tier_gauge = true,
          list = function() return { "lite", "std", "max" } end,
          get  = function() return launch_key("RtProfileVariant") end,
          set  = function(v) put("RtProfileVariant", v) end },
        { kind = "choice", label = "GameSettings", icon = "file", editor_label = "Editor",
          choice_label = true,
          editor_target = "gameset_explorer",
          editor_params = function() return { game_id = g.id, game_title = g.title } end,
          list = gamesettings_choices,
          get  = function() return launch_key("GameSettings") end,
          set  = function(v) put("GameSettings", v) end },

        { kind = "section", label = "INPUT", icon = "gamepad", color = "teal", skip = true },
        { kind = "choice", label = U.is_wii(g) and "Wii Mote" or "GameCube Pad",
          icon = "gamepad",
          keymap_target = true,
          editor_label = "Key Map",
          list = function() return choices_of("workshop/controller/" .. sysdir) end,
          get  = function() return launch_key("Controller") end,
          set  = function(v) put("Controller", v) end },
        { kind = "choice", label = "Hotkeys", icon = "hotkeys",
          editor_label = "Editor", tag = { text = "BETA", color = "warn" },
          editor_target = "hotkeys",
          editor_params = function()
              local h = launch_key("Hotkeys")
              if h == "Disabled" then return {} end
              return { profile = h }
          end,
          list = function() return choices_of("workshop/hotkeys", { "Disabled" }) end,
          get  = function() return launch_key("Hotkeys") end,
          set  = function(v) put("Hotkeys", v) end },
        { kind = "toggle", label = "Safe Exit", icon = "hotkeys",
          tag = { text = "START+SELECT", color = "ok" },
          get = function() return U.yes(launch_key("SafeExit")) end,
          set = function(v)
              if not v then
                  Modal.show("Safe Exit off",
                      "With Safe Exit disabled, START+SELECT no longer quits Dolphin. You may need to reboot the console.\n\nContinue?",
                      { accept_label = "Disable", cancel_label = "Keep on", color = K.C.bad,
                        on_cancel = function() U.card_set(S.game, "LAUNCH", "SafeExit", "yes") end })
              end
              put("SafeExit", v and "yes" or "no")
          end },

        { kind = "section", label = "CUSTOMIZATION", icon = "cheats", color = "boost", skip = true },
        { kind = "action", label = "Cheats & Boost", icon = "cheats", editor_label = "Database",
          badge = function()
              local on, tot = cheat_counts()
              if tot == 0 then return { text = "NONE", color = { 0.95, 0.40, 0.40 }, compact = true } end
              local c = (on == 0) and K.C.faint or (on == tot and K.C.ok or K.acc)
              return { text = on .. " / " .. tot, color = c }
          end,
          run = function() require("ui").go("cheats", { game_id = g.id, title = g.title }) end },
        { kind = "action", label = "Mod Vault", icon = "mods", editor_label = "Browse",
          badge = function()
              local n, total = U.vault_counts(g)
              if total == 0 then return { text = "NONE", color = { 0.95, 0.40, 0.40 }, compact = true } end
              local c = (n == 0) and K.C.faint or (n == total and K.C.ok or K.acc)
              return { text = n .. " / " .. total, color = c }
          end,
          run = function() require("ui").go("mods", { game = g }) end },

        { kind = "section", label = "ADVANCED", icon = "wrench", color = "mods", skip = true },
        { kind = "action", label = "Reset options", icon = "trash", sub = "back to defaults",
          danger = true,
          run = function()
              Modal.show("Reset options", "Restore the default launch options for this game?",
                  { accept_label = "Reset", cancel_label = "Cancel", color = K.C.warn, on_accept = reset_all })
          end },
    }

    -- Tier solo se family
    if not U.is_family(launch_key("RtProfile")) then
        for i, r in ipairs(S.rows) do
            if r.label == "Tier" then table.remove(S.rows, i); break end
        end
    end

    S.list:set(S.rows, false)
    S.list.sel = 1
end

-- ══════════════════════════════════════════════════════════
-- LIFECYCLE
-- ══════════════════════════════════════════════════════════
function S.enter(params)
    S.t = 0
    S._last_sel = 0
    S._sel_t = 0
    S.overlay_sel = 1
    S.doc.open = false
    S.doc.slide = 0
    S.doc.scroll = 0
    S.game = params and params.game or S.game
    if not S.game then require("ui").go_instant("library"); return end
    K.set_accent(U.is_wii(S.game) and "wii" or "gc")
    build()
    S.gauge.pos = 0; S.gauge.vel = 0
    S.gauge.target = (TIER_META[launch_key("RtProfileVariant")] or TIER_META.std).frac
end

function S.update(dt)
    S.t = S.t + dt
    S.list:update(dt)

    -- animazione slide doc
    local target = S.doc.open and 1 or 0
    S.doc.slide = S.doc.slide + (target - S.doc.slide) * math.min(1, dt * 14)
    if math.abs(target - S.doc.slide) < 0.01 then S.doc.slide = target end

    -- spring gauge
    local v = launch_key("RtProfileVariant")
    S.gauge.target = (TIER_META[v] or TIER_META.std).frac
    local diff = S.gauge.target - S.gauge.pos
    S.gauge.vel = S.gauge.vel + (diff * 70 - S.gauge.vel * 12) * dt
    S.gauge.pos = S.gauge.pos + S.gauge.vel * dt
    if math.abs(diff) < 0.005 and math.abs(S.gauge.vel) < 0.02 then
        S.gauge.pos = S.gauge.target; S.gauge.vel = 0
    end

    if S.list.sel ~= S._last_sel then S._last_sel = S.list.sel; S._sel_t = 0 end
    S._sel_t = S._sel_t + dt
end

-- ══════════════════════════════════════════════════════════
-- INPUT
-- ══════════════════════════════════════════════════════════
local function cycle(row, d)
    local list = (type(row.list) == "function") and row.list() or (row.list or {})
    if #list == 0 then return end
    local cur = row.get()
    local idx = 1
    for i, val in ipairs(list) do if val == cur then idx = i end end
    row.set(list[((idx - 1 + d) % #list) + 1])
    SFX.play("menu_move")
end

function S.raw_pad(b)
    if b == "back" or b == "guide" then
        if not S.doc.open then open_doc(S.game) end
        return true
    end
    return false
end

function S.pad(b)
    -- doc aperto: intercetta tutto
    if S.doc.open or S.doc.slide > 0.5 then
        if b == "UP" then S.doc.scroll = math.max(0, S.doc.scroll - 24)
        elseif b == "DOWN" then S.doc.scroll = S.doc.scroll + 24
        elseif b == "L2" or b == "LEFT" then S.doc.scroll = math.max(0, S.doc.scroll - 120)
        elseif b == "R2" or b == "RIGHT" then S.doc.scroll = S.doc.scroll + 120
        elseif b == "B" or b == "START" then
            S.doc.open = false; SFX.play("menu_back")
        end
        return
    end
    local row = S.list:cur()
    if b == "UP" then if S.list:move(-1) then SFX.play("menu_move") end
    elseif b == "DOWN" then if S.list:move(1) then SFX.play("menu_move") end
    elseif b == "LEFT" and row then
        if row.kind == "choice" then cycle(row, -1)
        elseif row.kind == "toggle" then row.set(false); SFX.play("menu_toggleoption")
        elseif row.play then
            S.hero_focus = math.max(0, S.hero_focus - 1)
            SFX.play("menu_move")
        end
    elseif b == "RIGHT" and row then
        if row.kind == "choice" then cycle(row, 1)
        elseif row.kind == "toggle" then row.set(true); SFX.play("menu_toggleoption")
        elseif row.play then
            S.hero_focus = math.min(#row.overlays, S.hero_focus + 1)
            SFX.play("menu_move")
        end
    elseif b == "A" and row then
        -- PLAY hero row: gestisci hero_focus PRIMA di tutto
        if row.play then
            if S.hero_focus == 0 then
                U.launch(S.game)
            else
                local it = row.overlays[S.hero_focus]
                if it then
                    local cur = U.yes(launch_key(it.key))
                    put(it.key, cur and "no" or "yes")
                    SFX.play("menu_toggleoption")
                end
            end
        elseif row.keymap_target then
            local sys = U.is_wii(S.game) and "Wii" or "GameCube"
            local prof = launch_key("Controller")
            local dir = "workshop/controller/" .. sys .. "/" .. prof
            require("ui").go("controller_map", { dir = dir, name = prof, system = sys })
        elseif row.kind == "action" then row.run()
        elseif row.kind == "choice" then
            if row.editor_target then
                require("ui").go(row.editor_target, row.editor_params and row.editor_params() or {})
            else
                cycle(row, 1)
            end
        elseif row.kind == "toggle" then row.set(not row.get()); SFX.play("menu_toggleoption")
        end
    elseif b == "SELECT" or b == "MENU" then
        open_doc(S.game)
    elseif b == "START" then U.launch(S.game)
    elseif b == "B" then require("ui").back() end
end

-- ══════════════════════════════════════════════════════════
-- TIER LABEL + DRAW
-- ══════════════════════════════════════════════════════════
local function draw_tier_label(m, xr, cy, focused, t)
    local lg = love.graphics
    if m.label == "LITE" then
        local f = "small"
        local w = K.width(f, "lite")
        K.text(f, "lite", xr - w, cy - 6, { 0.55, 0.85, 1.0 }, focused and 1 or 0.7)
    elseif m.label == "STANDARD" then
        local bob = math.sin(t * 1.8) * 2
        local f = "h"
        local w = K.width(f, "STANDARD")
        K.text(f, "STANDARD", xr - w, cy - 11 + bob, m.color, focused and 1 or 0.85)
    elseif m.label == "MAX" then
        local jx = math.sin(t * 22) * 1.2 + math.sin(t * 17.3) * 0.6
        local jy = math.cos(t * 19) * 1.0 + math.sin(t * 11.7) * 0.4
        local rot = 0.08 + math.sin(t * 15) * 0.05
        local f = "h"
        local txt = "MAX!!"
        local w = K.width(f, txt)
        lg.push()
        lg.translate(xr - w + jx, cy - 6 + jy)
        lg.rotate(rot)
        K.text(f, txt, 0, -6, { 1, 0.25, 0.25 }, focused and 1 or 0.85)
        lg.pop()
    end
end

local function draw_row(row, x, y, w, h, focused)
    if not row then return end
    local lg = love.graphics

    if row.kind == "section" then
        local sc = K.ACC[row.color] or K.ACC.gc
        local pad_top, pad_bot = 18, 2
        local ih = h - pad_top - pad_bot
        local cy = y + pad_top + ih / 2
        K.color(sc, 0.16)
        lg.rectangle("fill", x + 4, y + pad_top, w - 8, ih, 6, 6)
        K.color(sc, 1)
        lg.rectangle("fill", x + 4, y + pad_top, 4, ih)
        if row.icon then K.draw_tool_icon(row.icon, x + 26, cy, 18, sc, 1) end
        K.text("h", row.label, x + 46, cy - 11, sc)
        return
    end

    if row.play then
        -- PLAY a sinistra (40%), OVERLAY a destra (resto)
        local gap = 8
        local play_w = math.floor((w - gap) * 0.60)
        local ovl_w = w - gap - play_w
        local play_x = x
        local ovl_x = x + play_w + gap

        -- ── PLAY button ───────────────────
        local green = K.C.ok
        local p_focus = focused and (S.hero_focus == 0)
        K.panel(play_x, y + 2, play_w, h - 4,
            { focus = p_focus, accent = green, fill = green, alpha = 0.24, cut = 8 })
        K.text("h", "PLAY", play_x, y + h / 2 - 11, K.C.text, 1, play_w, "center")
        K.color(K.C.text, 1)
        local cx = play_x + play_w / 2 - 38
        lg.polygon("fill", cx, y + h / 2 - 8, cx, y + h / 2 + 8, cx + 14, y + h / 2)

        -- ── OVERLAY panel ─────────────────
        K.panel(ovl_x, y + 2, ovl_w, h - 4, { cut = 8 })
        -- intestazione OVERLAY
        local hdr_y = y + 10
        K.text("key", "OVERLAY", ovl_x + 14, hdr_y, K.acc)
        K.color(K.acc, 0.4)
        lg.rectangle("fill", ovl_x + 14, hdr_y + 16, ovl_w - 28, 1)

        -- 4 checkbox orizzontali
        local items = row.overlays or {}
        local n = #items
        if n > 0 then
            local bw = 20
            local cell_w = 44
            local total_w = n * cell_w
            local start_x = ovl_x + (ovl_w - total_w) / 2 + cell_w / 2
            local cy = y + h / 2 + 14
            for i, item in ipairs(items) do
                local cell_cx = start_x + (i - 1) * cell_w
                local cbx = cell_cx - bw / 2
                local cby = cy - bw / 2
                local on = U.yes(launch_key(item.key))
                local is_cur = focused and (S.hero_focus == i)
                -- casella
                if on then
                    K.color(K.C.ok, 0.22)
                    lg.rectangle("fill", cbx, cby, bw, bw, 4, 4)
                    K.color(K.C.ok, 1)
                    lg.rectangle("line", cbx, cby, bw, bw, 4, 4)
                    lg.setLineWidth(2)
                    lg.line(cbx + 4, cby + bw/2, cbx + 8, cby + bw - 4, cbx + bw - 4, cby + 4)
                    lg.setLineWidth(1)
                else
                    K.color(K.C.surf2, 1)
                    lg.rectangle("fill", cbx, cby, bw, bw, 4, 4)
                    K.color(K.C.line, is_cur and 1 or 0.7)
                    lg.setLineWidth(is_cur and 2 or 1)
                    lg.rectangle("line", cbx, cby, bw, bw, 4, 4)
                    lg.setLineWidth(1)
                end
                -- bordo selezione corrente
                if is_cur then
                    K.color(K.acc, 1)
                    lg.setLineWidth(2)
                    lg.rectangle("line", cbx - 4, cby - 4, bw + 8, bw + 8, 6, 6)
                    lg.setLineWidth(1)
                end
                -- label
                local lf = "small"
                local lw = K.width(lf, item.label)
                K.text(lf, item.label, cell_cx - lw / 2, cby + bw + 4,
                       is_cur and K.acc or K.C.dim)
            end
        end
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
        K.color(tc, 0.20); lg.rectangle("fill", tpx, y + h / 2 - 10, tw, 20, 5, 5)
        K.color(tc, 1);    lg.rectangle("line", tpx, y + h / 2 - 10, tw, 20, 5, 5)
        K.text(tf, row.tag.text, tpx + 5, y + h / 2 - 7, tc)
        name_end = tpx + tw
    end

    if row.editor_label and focused then
        local a = math.min(1, S._sel_t * 5)
        local slide = (1 - a) * 4
        local lx = name_end + 12
        local cy = y + h / 2 + slide
        K.color(K.acc, 0.20 * a); lg.circle("fill", lx + 9, cy, 10)
        K.color(K.acc, 1.0 * a); lg.setLineWidth(1.4); lg.circle("line", lx + 9, cy, 10); lg.setLineWidth(1)
        K.text("key", "A", lx + 5, cy - 7, K.acc, a)
        K.text("small", row.editor_label:upper(), lx + 24, cy - 8, K.acc, a)
    end

    local right = x + w - 14
    if row.kind == "toggle" then
        K.switch(right - 38, y + h / 2, row.get(), focused)
        return
    end
    if row.kind == "overlays" then
        -- 4 checkbox orizzontali: FPS VPS Speed OSD
        local bx = tx + 4
        local bw = 26
        local gap = 10
        local cy = y + h / 2
        for i, item in ipairs(row.items) do
            local cbx = bx + (i - 1) * (bw + gap)
            local on = U.yes(launch_key(item.key))
            local is_cur = focused and (i == S.overlay_sel)
            -- casella
            if on then
                K.color(K.C.ok, 0.20)
                love.graphics.rectangle("fill", cbx, cy - 10, 20, 20, 4, 4)
                K.color(K.C.ok, 1)
                love.graphics.rectangle("line", cbx, cy - 10, 20, 20, 4, 4)
                -- tick
                love.graphics.setLineWidth(2)
                love.graphics.line(cbx + 4, cy, cbx + 8, cy + 5, cbx + 16, cy - 5)
                love.graphics.setLineWidth(1)
            else
                K.color(K.C.surf2, 1)
                love.graphics.rectangle("fill", cbx, cy - 10, 20, 20, 4, 4)
                K.color(K.C.line, is_cur and 1 or 0.7)
                love.graphics.setLineWidth(is_cur and 2 or 1)
                love.graphics.rectangle("line", cbx, cy - 10, 20, 20, 4, 4)
                love.graphics.setLineWidth(1)
            end
            -- bordo selezione corrente
            if is_cur then
                K.color(K.acc, 1)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", cbx - 4, cy - 13, 28, 26, 6, 6)
                love.graphics.setLineWidth(1)
            end
            -- label sotto
            local lf = "small"
            local lw = K.width(lf, item.label)
            K.text(lf, item.label, cbx + 10 - lw / 2, cy + 14, is_cur and K.acc or K.C.dim)
        end
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
            lg.rectangle("fill", right - bw, y + h / 2 - pv, bw, pv * 2, 5, 5)
            K.color(b.color, 1)
            lg.rectangle("line", right - bw, y + h / 2 - pv, bw, pv * 2, 5, 5)
            K.text(f, b.text, right - bw + ph, y + h / 2 - (compact and 7 or 10), b.color)
        end
        return
    end
    if row.profile_label then
        local v = tostring(row.get() or "Default")
        local pcol = profile_color(v)
        local disp = v
        if U.is_family and U.is_family(v) then
            local tier = tostring(launch_key("RtProfileVariant") or "std"):upper()
            disp = v .. "  ·  " .. tier
        end
        local lw = K.width("value", disp)
        K.text("value", disp, right - lw, y + h / 2 - 10, pcol)
        if K.draw_tool_icon then K.draw_tool_icon("profile", right - lw - 22, y + h / 2, 14, pcol, 1) end
        if focused then
            K.text("body", "<", right - lw - 40, y + h / 2 - 11, K.C.faint)
            K.text("body", ">", right + 2, y + h / 2 - 11, K.C.faint)
        end
        return
    end
    if row.tier_gauge then
        local v = tostring(row.get() or "std")
        local m = TIER_META[v] or TIER_META.std
        local t = K.t or 0
        K.gauge(right - 30, y + h / 2, 18, S.gauge.pos, m.color, t)
        local label_r = right - 56
        draw_tier_label(m, label_r, y + h / 2, focused, t)
        if focused then
            local lw = (m.label == "LITE") and K.width("small", "lite") or K.width("h", m.label)
            K.text("body", "<", label_r - lw - 14, y + h / 2 - 11, K.C.faint)
        end
        return
    end
    if row.kind == "choice" then
        local v = row.get() or ""
        v = row.fmt and row.fmt(v) or tostring(v)
        local lw = K.width("value", v)
        local col = focused and K.acc or K.C.text
        if row.choice_label and v == "Disabled" then col = K.C.faint end
        K.text("value", v, right - lw, y + h / 2 - 10, col)
        if focused then
            K.text("body", "<", right - lw - 14, y + h / 2 - 11, K.C.faint)
            K.text("body", ">", right + 2, y + h / 2 - 11, K.C.faint)
        end
        return
    end
    if row.kind == "action" then
        local sub = type(row.sub) == "function" and row.sub() or row.sub
        if sub and not row.badge and not row.editor_label then
            K.text("small", sub, right - K.width("small", sub) - 16, y + h / 2 - 9,
                   row.danger and K.C.warn or K.C.faint)
            K.text("body", ">", right - 8, y + h / 2 - 11, focused and K.acc or K.C.faint)
        elseif row.danger and not row.editor_label then
            K.text("body", ">", right - 8, y + h / 2 - 11, focused and K.acc or K.C.faint)
        end
    end
end

local function draw_game_header(g)
    local m = K.MARGIN
    local disc_r = 26
    local disc_cx = m + disc_r + 4
    local disc_cy = 40
    local tex = get_disc_texture(g)
    K.disc(disc_cx, disc_cy, disc_r, tex, K.t or 0,
           (g.system == "Wii") and K.ACC.wii or K.ACC.gc)
    local tx = m + disc_r * 2 + 20
    local title = U.clean_title(g.title or g.id or "?")
    K.text("h", K.clip("h", title, K.W - tx - m - 20), tx, 8, K.C.text)
    local ry = 36
    K.region_flag(g.region or "?", tx, ry, 48, 20)
    K.id_plate(g.id or "??????", tx + 56, ry, 96, 20)
    K.color(K.acc, 1)
    love.graphics.rectangle("fill", tx, 64, K.W - tx - m - 20, 2)
end

function S.draw()
    local g = S.game
    if g then draw_game_header(g) else K.header("Game", "", nil) end
    S.list:draw(draw_row)
    if S.doc.slide > 0.01 and g then draw_doc(g, S.doc.blocks) end
    K.footer({
        { key = "A", label = "Change" },
        { key = "< >", label = "Value" },
        { key = "SELECT", label = "Docs" },
        { key = "START", label = "Play" },
        { key = "B", label = "Back" },
    })
end

-- NEXUS exposes the active game's launch configuration while reusing
-- the existing selectors, modals, editors and launcher.
function S.register_actions(ui)
    if not ui or type(ui.register_action) ~= "function" then
        return false, "UI action registrar unavailable"
    end

    local function active_game()
        local game = S.game
        if type(game) ~= "table" or type(game.id) ~= "string"
            or #game.id < 3 or #game.id > 16 or not game.id:match("^[%w_%-]+$") then
            return nil
        end
        return game
    end
    local function selected()
        return S.list and S.list:cur() or nil
    end
    local function launch_game()
        local game = active_game()
        if not game then return false, "no valid game is active" end
        local ok, result, detail = pcall(U.launch, game)
        if not ok then return false, tostring(result) end
        if result ~= true then return false, tostring(detail or "launcher rejected the request") end
        return true
    end
    local function find_row(key)
        local game = active_game()
        local labels = {
            RtProfile = "Profile",
            RtProfileVariant = "Tier",
            GameSettings = "GameSettings",
            Controller = U.is_wii(game) and "Wii Mote" or "GameCube Pad",
            Hotkeys = "Hotkeys",
        }
        local label = labels[key] or key
        for _, row in ipairs(S.rows or {}) do
            if row.kind == "choice" and row.get and (row.key == key or row.label == label) then
                return row
            end
        end
    end
    local function safe_profile_name(name)
        return type(name) == "string" and #name > 0 and #name <= 64
            and name:match("^[%w_%-]+$") ~= nil
    end

    local specs = {
        {
            id = "game.launch", title = "Launch selected game", order = 10,
            run = launch_game,
        },
        {
            id = "game.select_row", title = "Select game option", order = 20,
            run = function(index)
                if not active_game() then return false, "no valid game is active" end
                if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #S.list.items then
                    return false, "game option index out of range"
                end
                local row = S.list.items[index]
                if not row or row.skip or row.kind == "section" then
                    return false, "cannot select a section header"
                end
                S.list.sel = index
                return true
            end,
        },
        {
            id = "game.change_selected", title = "Change selected game option", order = 30,
            run = function(direction)
                if not active_game() then return false, "no valid game is active" end
                if direction ~= -1 and direction ~= 1 then return false, "direction must be -1 or 1" end
                local row = selected()
                if not row or row.skip or row.kind == "section" then
                    return false, "no editable game option selected"
                end
                if row.kind == "choice" then
                    local ok, err = pcall(cycle, row, direction)
                    if not ok then return false, tostring(err) end
                elseif row.kind == "toggle" then
                    local ok, err = pcall(row.set, direction > 0)
                    if not ok then return false, tostring(err) end
                    SFX.play("menu_toggleoption")
                else
                    return false, "selected game option is not editable"
                end
                return true
            end,
        },
        {
            id = "game.set_choice", title = "Set game launch choice", order = 40,
            run = function(key, value)
                if not active_game() then return false, "no valid game is active" end
                if type(key) ~= "string" or type(value) ~= "string" then
                    return false, "key and value must be strings"
                end
                local row = find_row(key)
                if not row then return false, "game choice not found" end
                local ok, choices = pcall(function()
                    return type(row.list) == "function" and row.list() or (row.list or {})
                end)
                if not ok or type(choices) ~= "table" then return false, "could not read game choices" end
                local available = false
                for _, choice in ipairs(choices) do
                    if choice == value then available = true; break end
                end
                if not available then return false, "value is not available for this game choice" end
                local saved, err = pcall(row.set, value)
                if not saved then return false, tostring(err) end
                return true
            end,
        },
        {
            id = "game.set_overlay", title = "Set game HUD overlay", order = 50,
            run = function(overlay_id, enabled)
                if not active_game() then return false, "no valid game is active" end
                if type(enabled) ~= "boolean" then return false, "enabled must be boolean" end
                local allowed = {
                    OverlayFPS = true, OverlayVPS = true,
                    OverlaySpeed = true, OverlayOSD = true,
                }
                if not allowed[overlay_id] then return false, "unknown game overlay" end
                put(overlay_id, enabled and "yes" or "no")
                return true
            end,
        },
        {
            id = "game.run_selected", title = "Run selected game action", order = 60,
            run = function()
                if not active_game() then return false, "no valid game is active" end
                local row = selected()
                if not row or row.skip or row.kind == "section" then
                    return false, "no game action selected"
                end
                if row.play then return launch_game() end
                if row.kind ~= "action" or type(row.run) ~= "function" then
                    return false, "selected row is not an action"
                end
                local ok, result, detail = pcall(row.run)
                if not ok then return false, tostring(result) end
                if result == false then return false, tostring(detail or "game action rejected") end
                return true
            end,
        },
        {
            id = "game.open_editor", title = "Open selected game editor", order = 70,
            run = function()
                if not active_game() then return false, "no valid game is active" end
                local row = selected()
                if not row or row.skip or row.kind == "section" then
                    return false, "no game option selected"
                end
                if row.keymap_target then
                    local system = U.is_wii(S.game) and "Wii" or "GameCube"
                    local profile = launch_key("Controller")
                    if not safe_profile_name(profile) then return false, "invalid controller profile name" end
                    local dir = "workshop/controller/" .. system .. "/" .. profile
                    local ok, err = pcall(require("ui").go, "controller_map", {
                        dir = dir, name = profile, system = system,
                    })
                    if not ok then return false, tostring(err) end
                    return true
                end
                if not row.editor_target then return false, "selected option has no editor" end
                local params = {}
                if row.editor_params then
                    local ok, value = pcall(row.editor_params)
                    if not ok then return false, tostring(value) end
                    if type(value) == "table" then params = value end
                end
                local ok, err = pcall(require("ui").go, row.editor_target, params)
                if not ok then return false, tostring(err) end
                return true
            end,
        },
        {
            id = "game.request_reset", title = "Request reset of game options", order = 80,
            run = function()
                if not active_game() then return false, "no valid game is active" end
                Modal.show("Reset options", "Restore the default launch options for this game?",
                    { accept_label = "Reset", cancel_label = "Cancel", color = K.C.warn, on_accept = reset_all })
                return true
            end,
        },
        {
            id = "game.state", title = "Get per-game launch state", order = 90,
            run = function()
                local game = active_game()
                local row = selected()
                local rows = {}
                for i, item in ipairs(S.rows or {}) do
                    rows[#rows + 1] = {
                        index = i,
                        label = item.label,
                        kind = item.kind,
                        skip = item.skip == true,
                        key = item.key,
                    }
                end
                local result = {
                    game_id = game and game.id or nil,
                    title = game and game.title or nil,
                    selected_index = S.list and S.list.sel or nil,
                    selected_label = row and row.label or nil,
                    selected_kind = row and row.kind or nil,
                    documentation_open = S.doc.open == true,
                    rows = rows,
                }
                if game then
                    result.profile = launch_key("RtProfile")
                    result.profile_variant = launch_key("RtProfileVariant")
                    result.controller = launch_key("Controller")
                    result.hotkeys = launch_key("Hotkeys")
                    result.game_settings = launch_key("GameSettings")
                    result.safe_exit = U.yes(launch_key("SafeExit"))
                    result.overlays = {
                        fps = U.yes(launch_key("OverlayFPS")),
                        vps = U.yes(launch_key("OverlayVPS")),
                        speed = U.yes(launch_key("OverlaySpeed")),
                        osd = U.yes(launch_key("OverlayOSD")),
                    }
                end
                return result
            end,
        },
    }

    for _, spec in ipairs(specs) do
        local ok, err = ui.register_action(spec.id, spec.run, {
            title = spec.title, group = "game", order = spec.order, screen = "game",
        })
        if not ok then return false, err or ("could not register " .. spec.id) end
    end
    return true
end

return S
