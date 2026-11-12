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
        { id = "cheatdb",  label = "Cheat database", icon = "star",    acc = "boost", sub = sub_cheatdb, go = "cheatdb" },
        { id = "mods",     label = "Graphic mods",   icon = "cube",    acc = "mods",  sub = sub_mods,    go = "mods", params = {} },
        { id = "hotkeys",  label = "Hotkeys",        icon = "keys",    acc = "hot",   sub = sub_nil,     go = "hotkeys", params = {} },
        { id = "settings", label = "Settings",       icon = "gear",    acc = "sys",   sub = sub_nil,     go = "settings" },
        { id = "folders",  label = "ROM folders",    icon = "folder",  acc = "blue",  sub = sub_nil,     go = "folders" },
        { id = "about",    label = "About",          icon = "dolphin", acc = "lime",  sub = sub_nil,     go = "about" },
    }
    if S.sel > #S.items then S.sel = #S.items end
end

function S.enter() S.t = 0; K.set_accent("gc"); build() end
function S.update(dt) S.t = S.t + dt end

local function move(d)
    local n = #S.items
    if n == 0 then return end
    local i = S.sel + d
    if i < 1 then i = n elseif i > n then i = 1 end
    if i ~= S.sel then S.sel = i; SFX.play("menu_move") end
end

function S.pad(b)
    local it = S.items[S.sel]
    if b == "UP" then move(-1)
    elseif b == "DOWN" then move(1)
    elseif b == "A" and it then
        SFX.play("menu_select")
        if it.fn then it.fn()
        elseif it.go then require("ui").go(it.go, it.params) end
    elseif b == "START" then require("ui").go("settings")
    end
end

local BANNER_Y, BANNER_H = 16, 74
local LIST_Y, ROW_H      = BANNER_Y + BANNER_H + 10, 42

local function draw_banner()
    local acc = K.ACC.gc
    K.panel(K.MARGIN, BANNER_Y, K.W - K.MARGIN * 2, BANNER_H, { cut = 12, accent = acc })
    K.cube(K.MARGIN + 42, BANNER_Y + BANNER_H / 2, 24, S.t * 1.2, 0.55, acc, 1)

    local ok_v, V = pcall(require, "version")
    local vs = (ok_v and V and V.string) or "?"
    K.text("title", "DOLPHIN RT:UI", K.MARGIN + 84, BANNER_Y + 12, K.C.text)
    K.text("small", "Definitive  ·  v" .. vs, K.MARGIN + 84, BANNER_Y + 42, K.C.dim)

    local n_games  = #(Library.games or {})
    local n_titles = 0
    for _ in pairs(Cheats.index()) do n_titles = n_titles + 1 end
    local right1 = ("%d games  ·  %d titles"):format(n_games, n_titles)
    local right2 = "SELECT → Rt:Stream  ·  GameCube / Wii"
    local rx = K.W - K.MARGIN - 12
    K.text("small", right1, rx - K.width("small", right1), BANNER_Y + 12, K.C.dim)
    K.text("small", right2, rx - K.width("small", right2), BANNER_Y + 42, K.C.faint)
end

local function draw_item(it, x, y, w, h, focused)
    local acc = K.ACC[it.acc] or K.ACC.gc
    K.panel(x, y + 2, w, h - 4, { focus = focused, accent = acc, cut = 6 })
    local ic = ICONS[it.icon]
    if ic then
        ic(x + 24, y + h / 2, 16, focused and acc or { acc[1] * 0.8, acc[2] * 0.8, acc[3] * 0.8 })
    end
    K.text("body", it.label, x + 52, y + h / 2 - 9, focused and K.C.text or K.C.dim)
    local sub = it.sub and it.sub() or nil
    if sub then
        local sw = K.width("small", sub)
        K.text("small", sub, x + w - sw - 30, y + h / 2 - 8, acc, focused and 1 or 0.7)
    end
    K.text("body", "›", x + w - 16, y + h / 2 - 9, focused and acc or K.C.faint)
end

function S.draw()
    local it = S.items[S.sel]
    K.set_accent((it and K.ACC[it.acc]) or K.ACC.gc)
    draw_banner()
    local y = LIST_Y
    for i, item in ipairs(S.items) do
        draw_item(item, K.MARGIN, y, K.W - K.MARGIN * 2, ROW_H, i == S.sel)
        y = y + ROW_H
    end
    K.footer({
        { key = "D-PAD", label = "Move" },
        { key = "A",     label = "Open" },
        { key = "START", label = "Settings" },
        { key = "SELECT", label = "Rt:Stream" },
    })
end

return S
