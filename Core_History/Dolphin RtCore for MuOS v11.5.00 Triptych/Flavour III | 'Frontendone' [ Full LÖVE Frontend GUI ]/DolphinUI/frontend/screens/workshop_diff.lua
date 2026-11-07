-- screens/workshop_diff.lua — profile vs base diff viewer.

local A = require("assets")
local SFX = require("sfx")
local State = require("state")
local IM = require("input_map")
local D = require("ui.draw")
local BG = require("ui.bg")
local Header = require("ui.header")
local Icons = require("ui.icons")
local BI = require("ui.button_icons")
local PMerger = require("profile_merger")

local S = {}
local W, H = 640, 480
S.kind = "rtcoreprofile"
S.name = nil
S.diffs = {}
S.scroll = 0

local function compute_diff(kind, name)
    local out = {}
    local files = { "Dolphin.ini", "GFX.ini" }
    for _, file in ipairs(files) do
        local base = PMerger.parse_ini("workshop/base/" .. file)
        local merged = PMerger.merge_chain(kind, name, file, "workshop")
        if base and merged then
            for section, kv in pairs(merged.data) do
                for k, v in pairs(kv) do
                    local bv = base.data[section] and base.data[section][k]
                    if bv ~= v then
                        table.insert(out, {
                            file = file,
                            section = section,
                            key = k,
                            from = bv or "(unset)",
                            to = v,
                        })
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.file ~= b.file then return a.file < b.file end
        if a.section ~= b.section then return a.section < b.section end
        return a.key < b.key
    end)
    return out
end

function S.enter(params)
    S.kind = (params and params.kind) or "rtcoreprofile"
    S.name = (params and params.name) or "Default"
    S.diffs = compute_diff(S.kind, S.name)
    S.scroll = 0
end

local function move(delta)
    S.scroll = math.max(0, S.scroll + delta)
end

function S.pad(b)
    if b == IM.UP then move(-3)
    elseif b == IM.DOWN then move(3) end
end

function S.hat(dir)
    if dir == "up" then move(-3)
    elseif dir == "down" then move(3) end
end

function S.key(k)
    if k == "up" then move(-3)
    elseif k == "down" then move(3) end
end

function S.draw()
    local th = State.theme
    BG.draw_cyberpunk(W, H, love.timer.getDelta(), th.accent)
    Header.draw("DIFF: " .. tostring(S.name), "settings")

    love.graphics.setColor(th.text_dim)
    love.graphics.setFont(A.font(th.font_body, 10))
    love.graphics.print(
        ("vs base  ·  %d change(s)"):format(#S.diffs),
        20, 60)

    if #S.diffs == 0 then
        love.graphics.setColor(0.30, 0.80, 0.40)
        love.graphics.setFont(A.font(th.font_body_bold, 12))
        love.graphics.printf(
            "No changes — profile matches base.",
            0, 220, W, "center")
        BI.draw_hint_centered("[B] Back",
            W, H - 22, A.font(th.font_body, 12), th)
        return
    end

    local TOP = 82
    local BOT = H - 40
    local ROW_H = 16
    local font = A.font("assets/fonts/JetBrainsMono-Regular.ttf", 10)
    local font_bold = A.font(th.font_body_bold, 10)

    -- Column headers
    love.graphics.setFont(font_bold)
    love.graphics.setColor(0.55, 0.58, 0.68)
    love.graphics.print("KEY",  24,  TOP - 16)
    love.graphics.print("FROM", 280, TOP - 16)
    love.graphics.print("TO",   460, TOP - 16)

    love.graphics.setScissor(0, TOP, W, BOT - TOP)

    local y = TOP - S.scroll
    local last_file, last_section = nil, nil
    for _, d in ipairs(S.diffs) do
        if d.file ~= last_file then
            love.graphics.setFont(A.font(th.font_body_bold, 11))
            love.graphics.setColor(0.96, 0.77, 0.26)
            love.graphics.print("── " .. d.file .. " ──", 20, y)
            y = y + 20
            last_file = d.file
            last_section = nil
        end
        if d.section ~= last_section then
            love.graphics.setFont(A.font(th.font_body_bold, 10))
            love.graphics.setColor(0.60, 0.60, 0.75)
            love.graphics.print("[" .. d.section .. "]", 20, y)
            y = y + 14
            last_section = d.section
        end

        if y + ROW_H >= TOP and y <= BOT then
            love.graphics.setFont(font)
            love.graphics.setColor(0.45, 0.55, 0.85)
            local key = d.key
            if #key > 30 then key = key:sub(1, 28) .. "…" end
            love.graphics.print(key, 24, y)

            love.graphics.setColor(0.90, 0.55, 0.55)
            local from = tostring(d.from)
            if #from > 22 then from = from:sub(1, 20) .. "…" end
            love.graphics.print(from, 280, y)

            love.graphics.setColor(0.60, 0.60, 0.70)
            love.graphics.print("→", 420, y)

            love.graphics.setColor(0.30, 0.90, 0.45)
            local to = tostring(d.to)
            if #to > 22 then to = to:sub(1, 20) .. "…" end
            love.graphics.print(to, 448, y)
        end
        y = y + ROW_H
    end

    love.graphics.setScissor()

    -- Scroll rail
    local total_h = 0
    local last_f, last_s = nil, nil
    for _, d in ipairs(S.diffs) do
        if d.file ~= last_f then total_h = total_h + 20; last_f = d.file; last_s = nil end
        if d.section ~= last_s then total_h = total_h + 14; last_s = d.section end
        total_h = total_h + ROW_H
    end
    if total_h > BOT - TOP then
        local rail_x = W - 6
        love.graphics.setColor(0.30, 0.30, 0.35, 0.55)
        love.graphics.rectangle("fill", rail_x, TOP, 3, BOT - TOP, 1, 1)
        local ratio = (BOT - TOP) / total_h
        local bar_h = math.max(20, (BOT - TOP) * ratio)
        local span = total_h - (BOT - TOP)
        local bar_y = TOP + (span > 0 and (S.scroll / span) * (BOT - TOP - bar_h) or 0)
        love.graphics.setColor(th.accent)
        love.graphics.rectangle("fill", rail_x, bar_y, 3, bar_h, 1, 1)
    end

    BI.draw_hint_centered(
        ("[↑↓] Scroll   [B] Back   (%d changes)"):format(#S.diffs),
        W, H - 22, A.font(th.font_body, 12), th)
end

return S