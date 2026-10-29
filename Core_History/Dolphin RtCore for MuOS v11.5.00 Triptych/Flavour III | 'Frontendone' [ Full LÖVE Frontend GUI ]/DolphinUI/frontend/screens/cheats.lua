-- screens/cheats.lua — cheat codes viewer with per-code toggle.
--
-- Dolphin's ActionReplay format:
--   $Code name            → enabled
--   $*Code name           → disabled
--
-- Toggling a code rewrites the line in dolphin-emu/Config/GameSettings/<ID>.ini.
-- The global "EnableCheats" in Dolphin.ini is toggled separately with [X].
--
-- Rescans on re_enter() so returning from a sub-screen shows up-to-date
-- state.
--
-- v0.4.3
--   * SFX.play("re_menu_2") -> SFX.play("menu_move"). The former file
--     does not ship; the sfx.lua fallback remapped it, but this is the
--     correct name.
--   * Added a proper BI.draw_footer with icons (previously the footer
--     was only inline text). Matches the rest of the app.

local A   = require("assets")
local SFX = require("sfx")
local State = require("state")
local IM  = require("input_map")
local BI  = require("ui.button_icons")
local D   = require("ui.draw")
local BG  = require("ui.bg")
local Header = require("ui.header")
local Modal = require("modal")
local Notify = require("notify")

local S = {}
local W, H = 640, 480
S.game = nil
S.cheats = {}
S.focus = 1
S.enabled = false
S.scroll = 0

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

local function read_enabled()
    local f = io.open(emu_root() .. "/Config/Dolphin.ini", "r")
    if not f then return false end
    local enabled = false
    for line in f:lines() do
        local k, v = line:match("^%s*([^=]+)%s*=%s*(.*)$")
        if k == "EnableCheats" then enabled = (v == "True") end
    end
    f:close()
    return enabled
end

local function write_enabled(state)
    local path = emu_root() .. "/Config/Dolphin.ini"
    local f = io.open(path, "r")
    if not f then return false end
    local lines = {}
    local done = false
    for line in f:lines() do
        if line:match("^EnableCheats%s*=") then
            line = "EnableCheats = " .. (state and "True" or "False")
            done = true
        end
        table.insert(lines, line)
    end
    f:close()
    if not done then
        for i, l in ipairs(lines) do
            if l:match("^%[Core%]") then
                table.insert(lines, i + 1,
                    "EnableCheats = " .. (state and "True" or "False"))
                break
            end
        end
    end
    local tmp = path .. ".tmp"
    local w = io.open(tmp, "w")
    if not w then return false end
    for _, l in ipairs(lines) do w:write(l .. "\n") end
    w:close()
    os.remove(path)
    os.rename(tmp, path)
    return true
end

local function gamesettings_path()
    local id = S.game and S.game.id
    if not id then return nil end
    return emu_root() .. "/Config/GameSettings/" .. id .. ".ini"
end

local function scan()
    S.cheats = {}
    S.enabled = read_enabled()
    local path = gamesettings_path()
    if not path then return end
    local f = io.open(path, "r")
    if not f then return end

    local section = nil
    local line_no = 0
    for line in f:lines() do
        line_no = line_no + 1
        local s = line:match("^%s*%[([^%]]+)%]")
        if s then
            section = s
        elseif section == "ActionReplay" then
            local raw = line:match("^%s*(%$[^\n]*)")
            if raw then
                local disabled = raw:sub(1, 2) == "$*"
                local name = disabled and raw:sub(3) or raw:sub(2)
                table.insert(S.cheats, {
                    name = name,
                    disabled = disabled,
                    line_no = line_no,
                    raw = line,
                })
            end
        end
    end
    f:close()
end

local function toggle_cheat_at(line_no)
    local path = gamesettings_path()
    if not path then return false end
    local f = io.open(path, "r")
    if not f then return false end
    local lines = {}
    local i = 0
    for line in f:lines() do
        i = i + 1
        if i == line_no then
            local raw = line:match("^%s*(%$.*)$")
            if raw then
                local indent = line:match("^(%s*)")
                if raw:sub(1, 2) == "$*" then
                    line = indent .. "$" .. raw:sub(3)
                else
                    line = indent .. "$*" .. raw:sub(2)
                end
            end
        end
        table.insert(lines, line)
    end
    f:close()

    local tmp = path .. ".tmp"
    local w = io.open(tmp, "w")
    if not w then return false end
    for _, l in ipairs(lines) do w:write(l .. "\n") end
    w:close()
    os.remove(path)
    os.rename(tmp, path)
    return true
end

function S.enter(game)
    S.game = game
    S.focus = 1
    S.scroll = 0
    scan()
end

function S.leave()
    State.raw_input = false
end

function S.re_enter()
    scan()
end

local function ensure_visible()
    local vis_h = H - 160
    local row_h = 28
    local top = (S.focus - 1) * row_h
    if top < S.scroll then
        S.scroll = top
    elseif top + row_h > S.scroll + vis_h then
        S.scroll = top + row_h - vis_h
    end
end

local function move(delta)
    local n = #S.cheats
    if n == 0 then return end
    local ni = math.max(1, math.min(n, S.focus + delta))
    if ni ~= S.focus then
        S.focus = ni
        SFX.play("menu_move")
        ensure_visible()
    end
end

function S.hat(dir)
    if     dir == "up"   then move(-1)
    elseif dir == "down" then move(1) end
end

function S.key(k)
    if     k == "up"   then move(-1)
    elseif k == "down" then move(1)
    elseif k == "return" or k == "space" then S.pad(IM.A)
    elseif k == "x" then S.pad(IM.X) end
end

function S.pad(b)
    if b == IM.A then
        S.enabled = not S.enabled
        write_enabled(S.enabled)
        SFX.play("menu_toggleoption")

    elseif b == IM.X then
        local c = S.cheats[S.focus]
        if not c then return end
        if toggle_cheat_at(c.line_no) then
            SFX.play("menu_toggleoption")
            local was_disabled = c.disabled
            scan()
            S.focus = math.max(1, math.min(#S.cheats, S.focus))
            Notify.show("info",
                (was_disabled and "Enabled: " or "Disabled: ") .. c.name)
        else
            Notify.show("error", "Cannot write cheat file")
        end
    end
end

function S.draw()
    local th = State.theme
    local body = A.font(th.font_body, 11)

    BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
    Header.draw("CHEATS", "save")

    love.graphics.setColor(th.text)
    love.graphics.setFont(A.font(th.font_body_bold, 13))
    love.graphics.print(S.game and S.game.title or "—", 24, 62)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print("Cheats engine:", 24, 94)

    local col = S.enabled and th.focus or th.text_dim
    love.graphics.setColor(col)
    love.graphics.setFont(A.font(th.font_body_bold, 12))
    love.graphics.print(S.enabled and "ENABLED" or "DISABLED", 160, 93)

    local badge_size = 16
    BI.draw(th, "a", 260, 91, badge_size)
    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print("toggle", 260 + badge_size + 4, 95)

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body_bold, 11))
    love.graphics.print(
        ("Codes for this game (%d):"):format(#S.cheats), 24, 128)

    if #S.cheats == 0 then
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 11))
        love.graphics.printf(
            "No cheat codes found.\n\n" ..
            "Add them in GameSettings/<ID>.ini under [ActionReplay].",
            0, 200, W, "center")
    else
        local TOP = 156
        local BOT = H - 60
        love.graphics.setScissor(0, TOP, W, BOT - TOP)

        local y = TOP - S.scroll
        for i, c in ipairs(S.cheats) do
            local focused = (i == S.focus)
            local x, w, h = 20, W - 40, 26

            if focused then
                love.graphics.setColor(th.focus[1], th.focus[2],
                    th.focus[3], 0.15)
                love.graphics.rectangle("fill", x, y - 3, w, h, 4, 4)
                love.graphics.setColor(th.focus)
                love.graphics.rectangle("fill", x, y - 3, 3, h, 1, 1)
            end

            local ic = c.disabled and {0.55, 0.55, 0.62} or {0.30, 0.80, 0.40}
            love.graphics.setColor(ic)
            love.graphics.setFont(A.font(th.font_body_bold, 11))
            local prefix = c.disabled and "[ ] " or "[✓] "
            love.graphics.print(prefix .. c.name, 32, y)

            if focused then
                love.graphics.setColor(th.text_dim)
                love.graphics.setFont(A.font(th.font_body, 9))
                love.graphics.printf("[X] toggle",
                    0, y + 2, W - 24, "right")
            end

            y = y + 28
            if y > BOT + 28 then break end
        end
        love.graphics.setScissor()

        if #S.cheats * 28 > BOT - TOP then
            local rail_x = W - 6
            love.graphics.setColor(0.30, 0.30, 0.35, 0.5)
            love.graphics.rectangle("fill", rail_x, TOP, 3, BOT - TOP, 1, 1)
            local total_h = #S.cheats * 28
            local vis_h = BOT - TOP
            local ratio = vis_h / total_h
            local bar_h = math.max(20, vis_h * ratio)
            local span = total_h - vis_h
            local bar_y = TOP + (span > 0
                and (S.scroll / span) * (vis_h - bar_h) or 0)
            love.graphics.setColor(th.accent)
            love.graphics.rectangle("fill", rail_x, bar_y, 3, bar_h, 1, 1)
        end
    end

    -- v0.4.3: was inline printf before; now a proper icon footer to match
    -- the rest of the frontend.
    BI.draw_footer(th, {
        { key = "dpad", label = "Navigate" },
        { key = "a",    label = "Engine"   },
        { key = "x",    label = "Toggle"   },
        { key = "b",    label = "Back"     },
    }, W, H - 22, A.font(th.font_body, 12))
end

return S