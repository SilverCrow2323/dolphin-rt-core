-- screens/saves.lua — save state browser with delete confirmation.
-- The list is rescanned on enter() and on re_enter(), so returning from
-- a sub-screen always shows the up-to-date slots.
--
-- B is not handled here: with State.raw_input = false (default), B goes
-- to the global back handler in main.lua. Modal confirmations are
-- dispatched by main.lua before reaching the screen.

local A   = require("assets")
local SFX = require("sfx")
local State = require("state")
local IM  = require("input_map")
local BI  = require("ui.button_icons")
local D   = require("ui.draw")
local BG  = require("ui.bg")
local Header = require("ui.header")
local Modal = require("modal")

local S = {}
local W, H = 640, 480
S.game = nil
S.slots = {}
S.focus = 1

local function shq(s)
    if s == nil then return "''" end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function emu_root()
    if State.opts.core == "external" then
        return "/opt/muos/share/emulator/dolphin"
    end
    return "dolphin-emu"
end

local function scan()
    S.slots = {}
    local dir = emu_root() .. "/StateSaves"
    local id = S.game and S.game.id
    if not id then return end

    local p = io.popen('timeout 2 ls -1 ' .. shq(dir) .. ' 2>/dev/null')
    if not p then return end
    for f in p:lines() do
        if f:match("^" .. id .. "%.s%03d") then
            local full = dir .. "/" .. f
            local size = 0
            local h = io.popen('timeout 1 stat -c %s ' .. shq(full) ..
                               ' 2>/dev/null')
            if h then size = tonumber(h:read("*a")) or 0; h:close() end
            local date = "?"
            local d = io.popen('timeout 1 stat -c %y ' .. shq(full) ..
                               ' 2>/dev/null')
            if d then date = (d:read("*a") or "?"):sub(1, 19); d:close() end
            table.insert(S.slots, { name = f, path = full, size = size,
                                    date = date })
        end
    end
    p:close()
    table.sort(S.slots, function(a, b) return a.name < b.name end)
    S.focus = math.max(1, math.min(#S.slots, S.focus))
end

function S.enter(game)
    S.game = game
    S.focus = 1
    scan()
end

function S.leave()
    State.raw_input = false
end

function S.re_enter()
    scan()
end

function S.hat(dir)
    if     dir == "up"   then
        S.focus = math.max(1, S.focus - 1); SFX.play("menu_move")
    elseif dir == "down" then
        S.focus = math.min(math.max(#S.slots, 1), S.focus + 1)
        SFX.play("menu_move")
    end
end

function S.key(k)
    if     k == "up"   then S.hat("up")
    elseif k == "down" then S.hat("down") end
end

local function delete_focused()
    local slot = S.slots[S.focus]
    if not slot then return end
    Modal.show("Delete save state?",
        slot.name .. "\n\nThis cannot be undone.",
        {
            accept_label = "Delete",
            color = {0.90, 0.30, 0.30},
            on_accept = function()
                os.remove(slot.path)
                SFX.play("notif_general")
                scan()
            end,
        })
end

function S.pad(b)
    if b == IM.X then delete_focused() end
end

function S.draw()
    local th = State.theme
    local body = A.font(th.font_body, 11)

    BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
    Header.draw("SAVE STATES", "save")

    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 13))
    love.graphics.print(S.game and S.game.title or "—", 24, 62)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print("Slot directory: " .. emu_root() .. "/StateSaves",
        24, 82)

    if #S.slots == 0 then
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 12))
        love.graphics.printf(
            "No save states found for this game.\n\n" ..
            "Create one from the in-game Live Menu.",
            0, H/2 - 20, W, "center")
    else
        local y = 110
        local t = State.t_ui or 0
        for i, s in ipairs(S.slots) do
            local focused = (i == S.focus)
            local x, w, h = 24, W - 48, 44
            local c = {0.30, 0.80, 0.60}

            if focused then
                local pulse = 0.5 + 0.5 * math.sin(t * 4)
                D.glow(x + w/2, y + h/2, 60, c, 0.7 + pulse * 0.2)
            end
            love.graphics.setColor(focused and c[1]*0.28 or c[1]*0.10,
                                   focused and c[2]*0.28 or c[2]*0.10,
                                   focused and c[3]*0.28 or c[3]*0.10, 0.95)
            love.graphics.rectangle("fill", x, y, w, h, 4, 4)

            love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.55)
            love.graphics.rectangle("fill", x, y, 3, h)

            love.graphics.setColor(c)
            D.rough_rect(x, y, w, h,
                { jitter = focused and 1.2 or 0.8,
                  thickness = focused and 2.5 or 1.5, seed = i * 13 })

            love.graphics.setColor(focused and {1,1,1} or th.text)
            love.graphics.setFont(A.font(th.font_body_bold, 13))
            love.graphics.print(s.name, x + 14, y + 6)

            love.graphics.setColor(th.text_dim)
            love.graphics.setFont(A.font(th.font_body, 10))
            love.graphics.print(
                ("%d KB   %s"):format(math.floor(s.size / 1024), s.date),
                x + 14, y + 25)

            y = y + h + 6
        end
    end

    BI.draw_footer(th, {
        { key = "dpad", label = "Navigate" },
        { key = "x",    label = "Delete"   },
        { key = "b",    label = "Back"     },
    }, W, H - 22, body)

    Modal.draw()
end

return S