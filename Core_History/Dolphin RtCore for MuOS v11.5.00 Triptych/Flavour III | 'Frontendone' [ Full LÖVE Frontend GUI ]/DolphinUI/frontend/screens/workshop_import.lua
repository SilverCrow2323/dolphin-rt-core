-- screens/workshop_import.lua — import from games_data.json / muOS ext.

local A = require("assets")
local SFX = require("sfx")
local State = require("state")
local IM = require("input_map")
local D = require("ui.draw")
local BG = require("ui.bg")
local Header = require("ui.header")
local Icons = require("ui.icons")
local BI = require("ui.button_icons")
local IMgr = require("import_manager")
local Modal = require("modal")
local Notify = require("notify")

local S = {}
local W, H = 640, 480

local SOURCES = {
    { key = "games_data", label = "games_data.json",  color = {0.30, 0.80, 0.60} },
    { key = "ext_muos",   label = "muOS ext-dolphin", color = {0.20, 0.72, 0.98} },
}

S.src = 1
S.sel = 1
S.scroll = 0
S.items = {}

-- Importing can block for seconds (remote fetch). We store the request
-- here and run it from S.update(), so at least one frame is drawn with
-- the "Importing…" overlay before the UI stalls.
S.pending = nil
local PENDING_FRAMES = 2
local _pending_frames = 0

local function reload()
    local src = SOURCES[S.src].key
    if src == "games_data" then S.items = IMgr.scan_games_data()
    elseif src == "ext_muos" then S.items = IMgr.scan_ext_dolphin() end
    S.sel = math.max(1, math.min(#S.items, 1))
    S.scroll = 0
end

function S.enter() S.src = 1; S.sel = 1; reload() end

local function change_src(delta)
    local n = #SOURCES
    S.src = ((S.src - 1 + delta) % n) + 1
    S.sel = 1; S.scroll = 0
    reload()
    SFX.play("menu_pagescroll")
end

local function move(delta)
    local n = #S.items
    if n == 0 then return end
    local ni = math.max(1, math.min(n, S.sel + delta))
    if ni ~= S.sel then
        S.sel = ni
        SFX.play("menu_move")
        local item_h = 56
        local vis_h = H - 160
        local top = (S.sel - 1) * item_h
        if top < S.scroll then S.scroll = top
        elseif top + item_h > S.scroll + vis_h then
            S.scroll = top + item_h - vis_h
        end
    end
end

local function activate()
    local item = S.items[S.sel]
    if not item then return end
    local src = SOURCES[S.src].key
    if src == "games_data" then
        Modal.show("Import setting?",
            string.format("%s\n%s\n\nFile: %s",
                item.game_id, item.game_name, item.set_filename),
            {
                accept_label = "Import",
                color = {0.30, 0.80, 0.60},
                on_accept = function()
                    S.pending = { kind = "games_data", item = item }
                    _pending_frames = PENDING_FRAMES
                end,
            })
    elseif src == "ext_muos" then
        Modal.show("Import profile?",
            string.format("Source: %s\nProfile: %s_%s",
                item.file, item.base, item.suffix),
            {
                accept_label = "Import",
                color = {0.20, 0.72, 0.98},
                on_accept = function()
                    S.pending = { kind = "ext_muos", item = item }
                    _pending_frames = PENDING_FRAMES
                end,
            })
    end
end

local function run_pending()
    local p = S.pending
    S.pending = nil
    if not p then return end
    if p.kind == "games_data" then
        local ok = IMgr.import_games_data_set(p.item)
        Notify.show(ok and "success" or "error",
            ok and ("Imported: " .. tostring(p.item.game_id)) or "Import failed")
    else
        local ok, err = IMgr.import_ext_profile(p.item)
        Notify.show(ok and "success" or "error",
            ok and ("Imported: " .. tostring(p.item.base) .. "_" .. tostring(p.item.suffix))
            or (err or "Failed"))
    end
    reload()
end

function S.update(dt)
    if not S.pending then return end
    _pending_frames = _pending_frames - 1
    if _pending_frames <= 0 then run_pending() end
end

function S.pad(b)
    if S.pending then return end
    if b == IM.L1 then change_src(-1)
    elseif b == IM.R1 then change_src(1)
    elseif b == IM.A then activate() end
end

function S.hat(dir)
    if dir == "up" then move(-1)
    elseif dir == "down" then move(1)
    elseif dir == "left" then change_src(-1)
    elseif dir == "right" then change_src(1) end
end

function S.key(k)
    if k == "up" then move(-1)
    elseif k == "down" then move(1)
    elseif k == "left" then change_src(-1)
    elseif k == "right" then change_src(1)
    elseif k == "return" or k == "space" then activate() end
end

local function draw_src_tabs(th)
    local x = 20
    for i, s in ipairs(SOURCES) do
        local w = 200
        local active = (i == S.src)
        local c = s.color
        love.graphics.setColor(active and c[1]*0.4 or 0.08,
                               active and c[2]*0.4 or 0.09,
                               active and c[3]*0.4 or 0.12, 0.95)
        love.graphics.rectangle("fill", x, 58, w, 24, 4, 4)
        love.graphics.setColor(active and {1,1,1} or th.text_dim)
        love.graphics.setFont(A.font(th.font_body_bold, 11))
        love.graphics.printf(">> " .. s.label, x, 63, w, "center")
        if active then
            love.graphics.setColor(c)
            D.rough_rect(x, 58, w, 24,
                { jitter = 0.6, thickness = 1.8, seed = i * 7 })
            D.corner_brackets(x, 58, w, 24, c, 5)
        end
        x = x + w + 8
    end
end

local function draw_item(item, i, focused, y)
    local th = State.theme
    local c = SOURCES[S.src].color
    local x, w, h = 20, W - 40, 52

    if focused then D.glow(x + w/2, y + h/2, 60, c, 0.8) end
    love.graphics.setColor(focused and c[1]*0.30 or c[1]*0.11,
                           focused and c[2]*0.30 or c[2]*0.11,
                           focused and c[3]*0.30 or c[3]*0.11, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)

    love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.55)
    love.graphics.rectangle("fill", x, y, 3, h)

    love.graphics.setColor(c)
    D.rough_rect(x, y, w, h,
        { jitter = focused and 1.2 or 0.7,
          thickness = focused and 2.5 or 1.5, seed = i * 11, cut = 14 })

    Icons.draw("save", x + 14, y + 15, 22, c)

    if SOURCES[S.src].key == "games_data" then
        love.graphics.setFont(A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10))
        local idw = love.graphics.getFont():getWidth(item.game_id) + 12
        love.graphics.setColor(c[1], c[2], c[3], 0.6)
        love.graphics.rectangle("fill", x + 44, y + 8, idw, 14, 7, 7)
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.printf(item.game_id, x + 44, y + 10, idw, "center")

        love.graphics.setColor(focused and {1,1,1} or th.text)
        love.graphics.setFont(A.font(th.font_body_bold, 11))
        love.graphics.print(item.game_name, x + 44 + idw + 8, y + 8)

        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 9))
        love.graphics.print(item.set_filename .. "  ·  " .. item.set_type,
            x + 44, y + 26)
        love.graphics.setColor(0.55, 0.55, 0.65)
        love.graphics.print(item.region .. "  ·  " .. item.system, x + 44, y + 40)
    else
        love.graphics.setColor(focused and {1,1,1} or th.text)
        love.graphics.setFont(A.font(th.font_body_bold, 11))
        love.graphics.print(item.base .. "  ·  " .. item.suffix, x + 44, y + 12)
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 9))
        love.graphics.print(item.file, x + 44, y + 32)
    end
end

function S.draw()
    local th = State.theme
    BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
    Header.draw("IMPORT", "enhancer")

    draw_src_tabs(th)

    if #S.items == 0 then
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 12))
        local msg
        if SOURCES[S.src].key == "games_data" then
            msg = "No custom settings found in games_data.json"
        else
            msg = "No ext-dolphin profiles found.\n\n" ..
                  "Expected in:\n" ..
                  "/opt/muos/share/emulator/dolphin/Config/"
        end
        love.graphics.printf(msg, 0, 220, W, "center")
    else
        local top = 92
        local bottom = H - 30
        love.graphics.setScissor(0, top, W, bottom - top)
        local y = top - S.scroll
        for i, item in ipairs(S.items) do
            if y + 56 > top and y < bottom then
                draw_item(item, i, i == S.sel, y)
            end
            y = y + 56
        end
        love.graphics.setScissor()
    end

    BI.draw_hint_centered(
        ("[L1/R1] Source   [↑↓] Nav   [A] Import   [B] Back   (%d items)")
        :format(#S.items),
        W, H - 22, A.font(th.font_body, 12), th)

    if S.pending then
        love.graphics.setColor(0, 0, 0, 0.72)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setColor(th.text)
        love.graphics.setFont(A.font(th.font_body_bold, 16))
        love.graphics.printf("Importing…", 0, H / 2 - 24, W, "center")
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 11))
        love.graphics.printf("Fetching the remote file, this can take a few seconds.",
            0, H / 2 + 4, W, "center")
    end

    Modal.draw()
end

return S
