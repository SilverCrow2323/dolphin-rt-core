-- screens/workshop_snapshots.lua — full config snapshots.
-- Restore and delete confirmations use Modal callbacks.
--
-- State.raw_input is held true for the whole lifetime of this screen so
-- B reaches S.pad even when the create-mode is active.

local A = require("assets")
local SFX = require("sfx")
local State = require("state")
local IM = require("input_map")
local D = require("ui.draw")
local BG = require("ui.bg")
local Header = require("ui.header")
local Icons = require("ui.icons")
local BI = require("ui.button_icons")
local SM = require("snapshot_manager")
local Modal = require("modal")
local Notify = require("notify")

local S = {}
local W, H = 640, 480
S.sel = 1
S.list = {}
S.mode = "list"
S._create_label = ""

local function reload()
    S.list = SM.list()
    S.sel = math.max(1, math.min(#S.list, S.sel))
end

function S.enter()
    S.sel = 1
    S.mode = "list"
    S._create_label = ""
    reload()
    State.raw_input = true
end

function S.leave()
    State.raw_input = false
end

function S.re_enter()
    State.raw_input = true
    reload()
end

local function move(delta)
    local n = #S.list
    if n == 0 then return end
    local ni = math.max(1, math.min(n, S.sel + delta))
    if ni ~= S.sel then S.sel = ni; SFX.play("menu_move") end
end

local function create_new()
    S.mode = "create"
    S._create_label = ""
    SFX.play("menu_select")
end

local function save_new()
    local label = (S._create_label ~= "" and S._create_label) or "manual"
    local id = SM.create(label)
    if id then
        Notify.show("success", "Snapshot created: " .. id)
    else
        Notify.show("error", "Snapshot failed")
    end
    S.mode = "list"
    reload()
end

local function restore_focused()
    local item = S.list[S.sel]
    if not item then return end
    Modal.show("Restore snapshot?",
        item.label .. "\n" .. item.created ..
        "\n\nThis will overwrite your current config.",
        {
            accept_label = "Restore",
            color = {0.96, 0.77, 0.26},
            on_accept = function()
                if SM.restore(item.id) then
                    Notify.show("success", "Restored: " .. item.label)
                else
                    Notify.show("error", "Restore failed")
                end
            end,
        })
end

local function delete_focused()
    local item = S.list[S.sel]
    if not item then return end
    Modal.show("Delete snapshot?",
        item.label .. "\n" .. item.created,
        {
            accept_label = "Delete",
            color = {0.90, 0.30, 0.30},
            on_accept = function()
                SM.delete(item.id)
                Notify.show("info", "Deleted")
                reload()
            end,
        })
end

local function activate()
    if S.mode == "create" then save_new(); return end
    restore_focused()
end

function S.pad(b)
    if b == IM.Y then create_new(); return end
    if b == IM.A then activate(); return end
    if b == IM.X and S.mode == "list" then delete_focused(); return end
    if b == IM.B then
        if S.mode == "create" then
            S.mode = "list"
            SFX.play("menu_back")
        else
            State.raw_input = false
            State.back()
        end
    end
end

function S.hat(dir)
    if S.mode ~= "list" then return end
    if dir == "up" then move(-1)
    elseif dir == "down" then move(1) end
end

function S.key(k)
    if S.mode == "create" then
        if k == "backspace" then
            S._create_label = S._create_label:sub(1, -2)
        elseif k == "return" then
            save_new()
        elseif k == "escape" then
            S.mode = "list"
        elseif #k == 1 and k:match("[%w_%- ]") then
            S._create_label = S._create_label .. k
        end
        return
    end
    if k == "up" then move(-1)
    elseif k == "down" then move(1)
    elseif k == "return" or k == "space" then activate()
    elseif k == "y" then create_new()
    elseif k == "x" then delete_focused()
    elseif k == "escape" then
        State.raw_input = false
        State.back()
    end
end

local function draw_list(th)
    if #S.list == 0 then
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 12))
        love.graphics.printf(
            "No snapshots yet.\n\nPress [Y] to create one.",
            0, 220, W, "center")
        return
    end

    local y = 92
    local t = State.t_ui or 0
    for i, item in ipairs(S.list) do
        local focused = (i == S.sel)
        local c = {0.96, 0.77, 0.26}
        local x, w, h = 20, W - 40, 52

        if focused then
            local pulse = 0.5 + 0.5 * math.sin(t * 4)
            D.glow(x + w/2, y + h/2, 60, c, 0.7 + pulse * 0.25)
        end
        love.graphics.setColor(focused and c[1]*0.30 or c[1]*0.11,
                               focused and c[2]*0.30 or c[2]*0.11,
                               focused and c[3]*0.30 or c[3]*0.11, 0.95)
        love.graphics.rectangle("fill", x, y, w, h, 3, 3)

        love.graphics.setColor(0, 0, 0, 0.5)
        for py = 6, h - 10, 14 do
            love.graphics.rectangle("fill", x + 4, y + py, 4, 8)
        end
        love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.55)
        love.graphics.rectangle("fill", x + 12, y, 3, h)

        love.graphics.setColor(c)
        D.rough_rect(x, y, w, h,
            { jitter = focused and 1.2 or 0.7,
              thickness = focused and 2.5 or 1.5,
              seed = i * 11, cut = 12 })

        Icons.draw("save", x + 22, y + 14, 22, c)

        love.graphics.setColor(focused and {1,1,1} or th.text)
        love.graphics.setFont(A.font(th.font_body_bold, 12))
        love.graphics.print(item.label, x + 54, y + 6)

        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 10))
        love.graphics.print(item.created .. "   ·   " .. item.size_kb .. " KB",
            x + 54, y + 26)

        love.graphics.setFont(
            A.font("assets/fonts/JetBrainsMono-Regular.ttf", 8))
        love.graphics.setColor(0.48, 0.48, 0.58)
        love.graphics.print(item.id, x + 54, y + 40)

        y = y + h + 6
    end
end

local function draw_create(th)
    local y = 130
    local x, w, h = 40, W - 80, 40
    local c = {0.30, 0.80, 0.60}

    love.graphics.setColor(c[1]*0.25, c[2]*0.25, c[3]*0.25, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(c)
    D.rough_rect(x, y, w, h, { jitter = 1.2, thickness = 2.5, seed = 11 })

    love.graphics.setColor({1,1,1})
    love.graphics.setFont(A.font(th.font_body_bold, 14))
    local cursor = (math.floor((State.t_ui or 0) * 2) % 2 == 0) and "_" or " "
    love.graphics.print("Label: " .. S._create_label .. cursor, x + 14, y + 10)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print("Type letters with keyboard, [Enter] to save",
        x, y + 60)
end

function S.draw()
    local th = State.theme
    BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
    Header.draw("SNAPSHOTS", "save")

    if S.mode == "list" then draw_list(th)
    else draw_create(th) end

    local hint = S.mode == "list"
        and "[Y] Create   [A] Restore   [X] Delete   [B] Back"
        or  "[Enter] Save   [Esc] Cancel"
    BI.draw_hint_centered(hint, W, H - 22, A.font(th.font_body, 12), th)

    Modal.draw()
end

return S