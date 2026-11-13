-- ui/screens/home.lua — hub: brand banner + coloured section list.
local K        = require("ui.kit")
local SFX      = require("ui.sfx")
local U        = require("ui.util")
local Library  = require("core.library")
local Settings = require("core.settings")
local Cheats   = require("core.rtcheats")
local Mascot   = require("ui.mascot")

local S = {}
S.sel, S.t = 1, 0

local ICONS = {
    library = function(cx, cy, s, c)
        K.color(c, 1); love.graphics.setLineWidth(1.6)
        love.graphics.rectangle("line", cx-s*0.55, cy-s*0.45, s*0.75, s*0.75, 3, 3)
        love.graphics.rectangle("line", cx-s*0.35, cy-s*0.55, s*0.75, s*0.75, 3, 3)
        love.graphics.setLineWidth(1)
    end,
    play = function(cx, cy, s, c)
        K.color(c, 1)
        love.graphics.polygon("fill",
            cx-s*0.40, cy-s*0.55,
            cx-s*0.40, cy+s*0.55,
            cx+s*0.55, cy)
    end,
    star = function(cx, cy, s, c) K.star(cx, cy, s*0.55, c, 1) end,
    cube = function(cx, cy, s, c) K.cube(cx, cy, s*0.50, S.t * 0.8, 0.55, c, 1) end,
    keys = function(cx, cy, s, c)
        K.color(c, 0.95); love.graphics.setLineWidth(1.6)
        love.graphics.rectangle("line", cx-s*0.55, cy-s*0.35, s*0.55, s*0.55, 4, 4)
        love.graphics.rectangle("line", cx-s*0.05, cy-s*0.05, s*0.55, s*0.55, 4, 4)
        love.graphics.setLineWidth(1)
    end,
    gear = function(cx, cy, s, c)
        K.color(c, 1)
        for i = 0, 7 do
            local ang = i * math.pi / 4 + S.t * 0.3
            love.graphics.setLineWidth(2)
            love.graphics.line(
                cx + math.cos(ang) * s * 0.55, cy + math.sin(ang) * s * 0.55,
                cx + math.cos(ang) * s * 0.85, cy + math.sin(ang) * s * 0.85)
        end
        love.graphics.circle("line", cx, cy, s * 0.50)
        love.graphics.circle("fill", cx, cy, s * 0.16)
        love.graphics.setLineWidth(1)
    end,
    folder = function(cx, cy, s, c)
        K.color(c, 0.95); love.graphics.setLineWidth(1.6)
        love.graphics.rectangle("line", cx-s*0.55, cy-s*0.30, s*1.05, s*0.72, 3, 3)
        love.graphics.rectangle("line", cx-s*0.55, cy-s*0.45, s*0.42, s*0.20, 2, 2)
        love.graphics.setLineWidth(1)
    end,
    chart = function(cx, cy, s, c)
        K.color(c, 0.95); love.graphics.setLineWidth(1.8)
        love.graphics.line(cx - s * 0.65, cy + s * 0.55, cx + s * 0.65, cy + s * 0.55)
        love.graphics.rectangle("line", cx - s * 0.52, cy + s * 0.03, s * 0.24, s * 0.50, 2, 2)
        love.graphics.rectangle("line", cx - s * 0.12, cy - s * 0.30, s * 0.24, s * 0.83, 2, 2)
        love.graphics.rectangle("line", cx + s * 0.28, cy - s * 0.58, s * 0.24, s * 1.11, 2, 2)
        love.graphics.setLineWidth(1)
    end,
    dolphin = function(cx, cy, s, c)
        if Mascot.loaded() then
            Mascot.draw(Mascot.frame_at(S.t, 0.7), cx, cy - s * 0.55, s / Mascot.FH * 1.6, 1)
        else
            K.color(c, 1); love.graphics.setLineWidth(2)
            love.graphics.circle("line", cx, cy, s * 0.50)
            love.graphics.setLineWidth(1)
        end
    end,
}

local function last_game()
    local id = Settings.get("last_game")
    if not id then return nil end
    for _, g in ipairs(Library.games or {}) do if g.id == id then return g end end
end

local function sub_library()   return #(Library.games or {}) .. " games" end
local function sub_last()
    local g = last_game()
    return g and K.clip("small", g.title or g.id, 220) or "nothing yet"
end
local function sub_cheatdb()
    return U.memo("sub_cheatdb", 30.0, function()
        local n, b = 0, 0
        for _, v in pairs(Cheats.index()) do n = n + 1; if v.boost then b = b + 1 end end
        return n .. " titles  ·  " .. b .. " boost"
    end)
end
local function sub_mods()  return #U.mods_installed() .. " installed" end
local function sub_nil()   return nil end

local function build()
    S.items = {
        { id = "library",  label = "Library",        icon = "library", acc = "gc",    sub = sub_library, go = "library" },
        { id = "last",     label = "Last played",    icon = "play",    acc = "wii",   sub = sub_last,
          fn = function() local g = last_game(); if g then U.launch(g) else require("ui").go("library") end end },
        { id = "compat",   label = "Compatibility",  icon = "chart",   acc = "wii",   sub = function() return "community game reports" end, go = "compat_list" },
        { id = "cheatdb",  label = "Cheat database", icon = "star",    acc = "boost", sub = sub_cheatdb, go = "cheatdb" },
        { id = "mods",     label = "Graphic mods",   icon = "cube",    acc = "mods",  sub = sub_mods,    go = "mods", params = {} },
        { id = "settings", label = "Settings",       icon = "gear",    acc = "sys",   sub = sub_nil,     go = "settings" },
        { id = "folders",  label = "ROM folders",    icon = "folder",  acc = "blue",  sub = sub_nil,     go = "folders" },
        { id = "about",    label = "About",          icon = "dolphin", acc = "lime",  sub = sub_nil,     go = "about" },
    }
    if S.sel > #S.items then S.sel = #S.items end
end

function S.enter() S.t = 0; K.set_accent("gc"); build() end
function S.update(dt) S.t = S.t + dt end

local function move_grid(b)
    local index = S.sel
    local row = math.floor((index - 1) / 2)
    local col = (index - 1) % 2
    if b == "UP" and row > 0 then index = index - 2
    elseif b == "DOWN" and row < 3 then index = index + 2
    elseif b == "LEFT" and col == 1 then index = index - 1
    elseif b == "RIGHT" and col == 0 then index = index + 1
    end
    if index ~= S.sel then S.sel = index; SFX.play("menu_move") end
end

function S.pad(b)
    local it = S.items[S.sel]
    if b == "UP" or b == "DOWN" or b == "LEFT" or b == "RIGHT" then
        move_grid(b)
    elseif b == "A" and it then
        SFX.play("menu_select")
        if it.fn then it.fn()
        elseif it.go then require("ui").go(it.go, it.params) end
    elseif b == "SELECT" then
        -- Rt:Stream is a Home-only mode switch.
        require("ui").go("stream_library")
    elseif b == "START" then
        require("ui").go("settings")
    elseif b == "B" then
        if Settings.get("confirm_quit") ~= false then
            require("ui.modal").show("Quit", "Close Dolphin Rt:UI?", {
                accept_label = "Quit", cancel_label = "Stay", color = K.C.bad,
                on_accept = function() love.event.quit() end,
            })
        else
            love.event.quit()
        end
    end
end

local HERO_Y, HERO_H = 14, 112
local GRID_Y, TILE_H, TILE_GAP = 140, 68, 8

local function draw_hero()
    local x, y, w = K.MARGIN, HERO_Y, K.W - K.MARGIN * 2
    local acc = K.ACC.gc
    K.panel(x, y, w, HERO_H, { cut = 14, accent = acc })
    K.color(acc, 0.10); love.graphics.circle("fill", x + 55, y + 55, 42)
    K.cube(x + 55, y + 55, 30, S.t * 0.55, 0.58, acc, 1)

    K.text("key", "YOUR NEXT ADVENTURE STARTS HERE", x + 112, y + 16, acc)
    K.text("title", "DOLPHIN RT:UI", x + 112, y + 36, K.C.text)
    K.text("small", "GAMECUBE  ·  WII  ·  YOUR COLLECTION", x + 114, y + 68, K.C.dim)

    local last = last_game()
    local label = last and K.clip("small", last.title or last.id, 190) or "Choose a game to begin"
    K.color(K.C.line, 0.7); love.graphics.rectangle("fill", x + 350, y + 14, 1, HERO_H - 28)
    K.text("key", "LAST PLAYED", x + 372, y + 18, K.C.faint)
    K.text("body", label, x + 372, y + 42, last and K.C.text or K.C.dim)
    K.text("small", last and ("ID  " .. tostring(last.id or "------")) or "Library ready for setup",
        x + 372, y + 72, K.C.faint)

    local n_games = #(Library.games or {})
    local stats = tostring(n_games) .. " GAMES"
    K.pill(stats, x + w - 14, y + 23, K.ACC.lime, true)
    local ok_v, V = pcall(require, "version")
    if ok_v and V then
        local version = "v" .. tostring(V.string or "?")
        K.text("mono", version, x + w - 18 - K.width("mono", version),
            y + HERO_H - 22, K.C.faint)
    end
end

local function draw_tile(it, index, x, y, w, h, focused)
    local acc = K.ACC[it.acc] or K.ACC.gc
    K.panel(x, y, w, h, { focus = focused, accent = acc, cut = 10 })
    if focused then
        K.color(acc, 0.9)
        love.graphics.rectangle("fill", x + 12, y + 13, 3, h - 26, 1.5, 1.5)
    end
    local icon = ICONS[it.icon]
    if icon then
        icon(x + 36, y + h / 2, 18, focused and acc or
            { acc[1] * 0.76, acc[2] * 0.76, acc[3] * 0.76 })
    end
    K.text("body", it.label, x + 66, y + 17, focused and K.C.text or K.C.dim)
    local sub = it.sub and it.sub() or nil
    if sub then
        K.text("small", K.clip("small", sub, w - 92), x + 66, y + 42,
            focused and acc or K.C.faint)
    end
    K.text("body", "›", x + w - 20, y + h / 2 - 10, focused and acc or K.C.faint)
end

function S.draw()
    local it = S.items[S.sel]
    K.set_accent((it and K.ACC[it.acc]) or K.ACC.gc)
    draw_hero()
    local gap = 8
    local tile_w = (K.W - K.MARGIN * 2 - gap) / 2
    for i, item in ipairs(S.items) do
        local row = math.floor((i - 1) / 2)
        local col = (i - 1) % 2
        local x = K.MARGIN + col * (tile_w + gap)
        local y = GRID_Y + row * (TILE_H + TILE_GAP)
        draw_tile(item, i, x, y, tile_w, TILE_H, i == S.sel)
    end
    K.footer({
        { key = "D-PAD", label = "Navigate" },
        { key = "A", label = "Open" },
        { key = "SELECT", label = "Rt:Stream" },
        { key = "START", label = "Settings" },
        { key = "B", label = "Quit" },
    })
end

return S
