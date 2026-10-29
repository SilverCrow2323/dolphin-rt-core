-- screens/workshop_rollback.lua — config backup restore.
-- Timeline layout with connecting rail on the left.

local A = require("assets")
local SFX = require("sfx")
local State = require("state")
local IM = require("input_map")
local D = require("ui.draw")
local BG = require("ui.bg")
local Header = require("ui.header")
local Icons = require("ui.icons")
local BI = require("ui.button_icons")
local BM = require("backup_manager")
local Notify = require("notify")

local S = {}
local W, H = 640, 480
S.sel = 1
S.list = {}

local function scan()
    S.list = BM.list()
    S.sel = math.max(1, math.min(#S.list, S.sel or 1))
end

function S.enter() S.sel = 1; scan() end

local function move(delta)
    local n = #S.list
    if n == 0 then return end
    local ni = math.max(1, math.min(n, S.sel + delta))
    if ni ~= S.sel then S.sel = ni; SFX.play("menu_move") end
end

local function activate()
    local item = S.list[S.sel]
    if not item then return end
    if BM.restore(item.path) then
        Notify.show("success", "Restored: " .. item.filename)
        scan()
    else
        Notify.show("error", "Restore failed")
    end
end

function S.pad(b) if b == IM.A then activate() end end
function S.hat(dir)
    if dir == "up" then move(-1)
    elseif dir == "down" then move(1) end
end
function S.key(k)
    if k == "up" then move(-1)
    elseif k == "down" then move(1)
    elseif k == "return" or k == "space" then activate() end
end

local function fmt_time(ts)
    if not ts then return "?" end
    local ok, d = pcall(os.date, "*t", ts)
    if not ok or not d then return "?" end
    return string.format("%04d-%02d-%02d %02d:%02d",
        d.year, d.month, d.day, d.hour, d.min)
end

function S.draw()
    local th = State.theme
    BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
    Header.draw("ROLLBACK", "save")

    if #S.list == 0 then
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 12))
        love.graphics.printf(
            "No backups available.\n\n" ..
            "Backups are created automatically when you apply a profile.",
            0, 200, W, "center")
    else
        -- Timeline rail
        local y0 = 74
        local y1 = 74 + (#S.list * 46) - 8
        love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.20)
        love.graphics.rectangle("fill", 28, y0, 2, y1 - y0, 1, 1)

        local y = y0
        local t = State.t_ui or 0
        for i, item in ipairs(S.list) do
            local focused = (i == S.sel)
            local x, w, h = 46, W - 66, 42
            local c = {0.96, 0.77, 0.26}

            -- Timeline dot
            local dot_col = focused and c or {0.5, 0.5, 0.55}
            local dot_r = focused and 6 or 4
            love.graphics.setColor(dot_col[1], dot_col[2], dot_col[3], 0.95)
            love.graphics.circle("fill", 29, y + h/2, dot_r)
            if focused then
                love.graphics.setColor(c[1], c[2], c[3], 0.35)
                love.graphics.circle("line", 29, y + h/2, dot_r + 3)
            end

            if focused then
                local pulse = 0.5 + 0.5 * math.sin(t * 4)
                D.glow(x + w/2, y + h/2, 50, c, 0.7 + pulse * 0.2)
            end
            love.graphics.setColor(focused and c[1]*0.30 or c[1]*0.11,
                                   focused and c[2]*0.30 or c[2]*0.11,
                                   focused and c[3]*0.30 or c[3]*0.11, 0.95)
            love.graphics.rectangle("fill", x, y, w, h, 4, 4)
            love.graphics.setColor(c)
            D.rough_rect(x, y, w, h,
                { jitter = focused and 1.2 or 0.8,
                  thickness = focused and 2.5 or 1.5, seed = i * 11, cut = 12 })

            Icons.draw("save", x + 12, y + 10, 22, c)

            love.graphics.setColor(focused and {1,1,1} or th.text)
            love.graphics.setFont(A.font(th.font_body_bold, 12))
            love.graphics.print(item.filename .. ".ini", x + 44, y + 8)
            love.graphics.setColor(th.text_dim)
            love.graphics.setFont(A.font(th.font_body, 10))
            love.graphics.print(
                fmt_time(item.ts) .. "   ·   " .. math.floor(item.size/1024) .. " KB",
                x + 44, y + 26)

            y = y + h + 6
        end
    end

    BI.draw_hint_centered("[↑↓] Nav   [A] Restore   [B] Back",
        W, H - 22, A.font(th.font_body, 12), th)
end

return S