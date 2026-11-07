-- screens/homebrew.lua — Wii Homebrew Channel style banner list.
--
-- Homebrew apps are PowerPC binaries (.dol / .elf). They run through
-- Dolphin, not natively on the ARM H700 — launching them goes through
-- launcher.launch(), same path as games.
--
-- v0.5.1 — launch diagnostics
--   * do_launch() now verifies that the boot file actually exists on
--     disk before handing off to Launcher. If it doesn't, a Modal is
--     shown with the exact path. This replaces the previous silent
--     failure mode ("press A, nothing happens, no feedback") that
--     made the homebrew screen look broken when the real problem was
--     a missing .dol or a path that didn't resolve.
--   * The boot path in State.homebrew is now ABSOLUTE (see state.lua
--     v0.5.1), so the file test here matches what launch_game.sh will
--     actually see after its internal `cd dolphin-emu/`.
--   * System detection: hb.system (from rtcore_hb.ini) if present,
--     else "Wii" (most HBC apps are Wii homebrew).
--
-- Layout:
--   <root>/hb/<AppDir>/                each app
--   <root>/hb/<AppDir>/rtcore_hb.ini   metadata
--   <root>/hb/<AppDir>/icon.png        banner (wide is preferred)

local A      = require("assets")
local SFX    = require("sfx")
local State  = require("state")
local IM     = require("input_map")
local D      = require("ui.draw")
local BG     = require("ui.bg")
local Header = require("ui.header")
local BI     = require("ui.button_icons")
local Modal  = require("modal")
local Notify = require("notify")
local Launcher = require("launcher")

local S = {}
local W, H = 640, 480

local BAN_W   = 560
local BAN_H   = 90
local BAN_X   = (W - BAN_W) / 2
local GAP     = 14
local TOP_Y   = 78
local VISIBLE = math.floor((H - TOP_Y - 36) / (BAN_H + GAP))

S.sel    = 1
S.scroll = 0
S.target = 0
S.t      = 0

function S.enter()
    S.sel = 1
    S.scroll = 0
    S.target = 0
end

function S.leave()
    State.raw_input = false
end

function S.re_enter()
    S.target = S.scroll
end

-- ── Launch ──────────────────────────────────────────────────
local function file_exists(p)
    if not p or p == "" then return false end
    local f = io.open(p, "rb")
    if f then f:close(); return true end
    return false
end

-- Homebrew is a PowerPC binary: it must go through Dolphin, exactly
-- like a game ROM. We reuse launcher.launch() so profile handling,
-- GameSettings override and the launcher shell script all apply.
local function do_launch(hb)
    local sys = hb.system or "Wii"
    Launcher.launch({
        title = hb.name or "Homebrew",
        sys   = sys,
        path  = hb.boot,
        id    = hb.dir and ("HB-" .. hb.dir) or "HOMEBREW",
        file  = hb.boot and hb.boot:match("([^/]+)$") or "boot.dol",
    })
    SFX.play("menu_select")
end

local function launch()
    local hb = State.homebrew[S.sel]
    if not hb then return end

    -- Verify the boot file exists before doing anything else. In the
    -- previous revision a missing .dol caused the whole launch to
    -- fail silently: no error, no modal, the user just saw "nothing
    -- happens". Now we tell them exactly which file is missing and
    -- where we expected it.
    if not file_exists(hb.boot) then
        Modal.show("Boot file missing",
            (hb.name or "?") .. "\n\n" ..
            "Expected:\n" .. tostring(hb.boot) .. "\n\n" ..
            "Check that the homebrew folder contains a " ..
            "boot.dol / boot.elf, or fix the `dol =` line in " ..
            "rtcore_hb.ini.",
            {
                accept_label = "OK",
                color = {0.90, 0.30, 0.30},
            })
        return
    end

    local msg = (hb.description or ""):sub(1, 200)
    if hb.instructions and hb.instructions ~= "" then
        msg = msg .. "\n\n── HOW TO USE ──\n" ..
              hb.instructions:sub(1, 500)
    end
    Modal.show("Launch " .. hb.name .. "?", msg, {
        accept_label = "Launch",
        on_accept = function() do_launch(hb) end,
    })
end

-- ── Navigation ──────────────────────────────────────────────
local function ensure_visible()
    local item_h = BAN_H + GAP
    local item_y = (S.sel - 1) * item_h
    local vis_h  = VISIBLE * item_h
    if item_y < S.target then
        S.target = item_y
    elseif item_y + BAN_H > S.target + vis_h then
        S.target = item_y + BAN_H - vis_h
    end
end

local function move(delta)
    local n = #State.homebrew
    if n == 0 then return end
    local ni = math.max(1, math.min(n, S.sel + delta))
    if ni ~= S.sel then
        S.sel = ni
        ensure_visible()
        SFX.play("menu_move")
    end
end

function S.pad(b)
    if b == IM.A then launch() end
end

function S.hat(dir)
    if dir == "up"   then move(-1)
    elseif dir == "down" then move(1) end
end

function S.key(k)
    if k == "up"   then move(-1)
    elseif k == "down" then move(1)
    elseif k == "return" or k == "space" then launch() end
end

function S.update(dt)
    S.t = S.t + dt
    S.scroll = S.scroll + (S.target - S.scroll) * math.min(1, dt * 12)
    if math.abs(S.scroll - S.target) < 0.5 then S.scroll = S.target end
end

-- ── Banner render ───────────────────────────────────────────
local function accent_for(hb)
    if hb.type == "elf" then return {0.90, 0.30, 0.30} end
    if hb.type == "iso" or hb.type == "rvz" then return {0.55, 0.35, 0.95} end
    return {0.20, 0.72, 0.98}
end

local function draw_banner(hb, i, focused, y)
    local th = State.theme
    local pulse = 0.5 + 0.5 * math.sin(S.t * 4 + i * 0.3)
    local accent = accent_for(hb)
    local x, w, h = BAN_X, BAN_W, BAN_H

    if focused then
        D.glow(x + w/2, y + h/2, 110 + pulse * 25, accent, 1.0)
    end

    love.graphics.setColor(0.05, 0.06, 0.09, 1)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.85)
    love.graphics.rectangle("fill", x, y, 4, h)

    local img_path = hb.banner or hb.icon
    local img = img_path and A.image(img_path)
    local use_contain = false
    local iw, ih, ar

    if img then
        iw, ih = img:getWidth(), img:getHeight()
        ar = iw / ih
        if hb.banner and hb.icon and hb.banner == hb.icon then
            use_contain = true
        elseif ar < 3.0 then
            use_contain = true
        end
    end

    if img and not use_contain then
        local s = math.max(w / iw, h / ih)
        local dw, dh = iw * s, ih * s
        local dx = x + (w - dw) / 2
        local dy = y + (h - dh) / 2

        love.graphics.setScissor(x, y, w, h)
        love.graphics.setColor(1, 1, 1, focused and 1.0 or 0.82)
        love.graphics.draw(img, dx, dy, 0, s, s)
        love.graphics.setScissor()

        for k = 0, 8 do
            love.graphics.setColor(0, 0, 0, 0.60 * (1 - k/8))
            love.graphics.rectangle("fill", x + k * 40, y, 40, h)
        end
        for k = 0, 5 do
            love.graphics.setColor(0, 0, 0, 0.45 * (1 - k/5))
            love.graphics.rectangle("fill", x + w - (k + 1) * 40, y, 40, h)
        end
        love.graphics.setColor(0, 0, 0, 0.12)
        love.graphics.rectangle("fill", x, y, w, h)

    elseif img then
        local box_size = h - 8
        local s = math.min(box_size / iw, box_size / ih)
        local dw, dh = iw * s, ih * s
        local dx = x + 8 + (box_size - dw) / 2
        local dy = y + (h - dh) / 2

        love.graphics.setColor(accent[1]*0.15, accent[2]*0.15,
                               accent[3]*0.15, 1)
        love.graphics.rectangle("fill", x + 4, y + 4, box_size, box_size, 3, 3)

        love.graphics.setColor(1, 1, 1, focused and 1.0 or 0.90)
        love.graphics.draw(img, dx, dy, 0, s, s)

        love.graphics.setColor(accent[1], accent[2], accent[3], 0.45)
        love.graphics.rectangle("line", x + 4, y + 4, box_size, box_size, 3, 3)

        local grad_start = x + box_size + 4
        for k = 0, 6 do
            love.graphics.setColor(0, 0, 0, 0.55 * (1 - k/6))
            love.graphics.rectangle("fill", grad_start + k * 40, y, 40, h)
        end
    else
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.10)
        love.graphics.rectangle("fill", x + 4, y + 4, w - 8, h - 8, 3, 3)
    end

    if focused then
        love.graphics.setColor(1, 1, 1, 0.55 + pulse * 0.45)
        D.rough_rect(x - 2, y - 2, w + 4, h + 4,
            { jitter = 1.6, thickness = 2.5, seed = i * 7 })
        love.graphics.setColor(accent)
        D.rough_rect(x, y, w, h,
            { jitter = 1.1, thickness = 2.5, seed = i * 11, cut = 12 })
        D.corner_brackets(x, y, w, h, accent, 14)
    else
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.55)
        D.rough_rect(x, y, w, h,
            { jitter = 0.7, thickness = 1.3, seed = i * 11, cut = 12 })
    end

    love.graphics.setColor(0, 0, 0, 0.06)
    for yy = y + 2, y + h - 2, 3 do
        love.graphics.line(x + 2, yy, x + w - 2, yy)
    end

    local text_x = x + 20
    if use_contain then text_x = x + h + 12 end

    local fnt = A.font(th.font_body_bold, 22)
    love.graphics.setFont(fnt)
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.print(hb.name, text_x + 1, y + 22 + 1)
    love.graphics.setColor(focused and {1,1,1} or {0.88, 0.90, 0.94})
    love.graphics.print(hb.name, text_x, y + 22)

    local sub = ""
    if hb.author ~= "" and hb.version ~= "" then
        sub = hb.author .. "  ·  v" .. hb.version
    elseif hb.author ~= "" then
        sub = hb.author
    elseif hb.version ~= "" then
        sub = "v" .. hb.version
    end
    if sub ~= "" then
        local f2 = A.font(th.font_body, 11)
        love.graphics.setFont(f2)
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.print(sub, text_x + 1, y + 50 + 1)
        love.graphics.setColor(accent[1], accent[2], accent[3], 0.95)
        love.graphics.print(sub, text_x, y + 50)
    end

    if hb.description and hb.description ~= "" then
        local desc = hb.description
        if #desc > 70 then desc = desc:sub(1, 68) .. "…" end
        love.graphics.setFont(A.font(th.font_body, 10))
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.print(desc, text_x + 1, y + h - 18 + 1)
        love.graphics.setColor(focused and {0.95, 0.96, 1.0}
            or {0.70, 0.74, 0.80})
        love.graphics.print(desc, text_x, y + h - 18)
    end

    local badge = (hb.type or "dol"):upper()
    local bw = 44
    love.graphics.setColor(accent[1]*0.75, accent[2]*0.75, accent[3]*0.75,
        0.95)
    love.graphics.rectangle("fill", x + w - bw - 10, y + 10, bw, 16, 2, 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(A.font(th.font_body_bold, 9))
    love.graphics.printf(badge, x + w - bw - 10, y + 13, bw, "center")

    if focused then
        local px = x - 18 + math.sin(S.t * 6) * 3
        love.graphics.setColor(accent)
        love.graphics.polygon("fill",
            px, y + h/2 - 10,
            px + 12, y + h/2,
            px, y + h/2 + 10)

        for j = 1, 12 do
            local ang = (j / 12) * math.pi * 2 + S.t * 1.2
            local pr = 8 + 4 * math.sin(S.t * 4 + j)
            local px2 = x + w/2 + math.cos(ang) * (w/2 + pr)
            local py2 = y + h/2 + math.sin(ang) * (h/2 + pr)
            love.graphics.setColor(accent[1], accent[2], accent[3], 0.65)
            love.graphics.circle("fill", px2, py2,
                1.4 + math.sin(S.t * 7 + j))
        end
    end
end

-- ── Draw ────────────────────────────────────────────────────
function S.draw()
    local th = State.theme
    BG.draw_nexus(W, H, love.timer.getDelta(), th.accent)
    Header.draw("HOMEBREW CHANNEL", "homebrew")

    local list = State.homebrew
    if #list == 0 then
        love.graphics.setColor(th.text_dim)
        love.graphics.setFont(A.font(th.font_body, 12))
        love.graphics.printf(
            "No homebrew found.\n\n" ..
            "Add apps to:   hb/<folder>/\n" ..
            "Each folder needs:   rtcore_hb.ini   +   icon.png   (banner wide)",
            0, H/2 - 30, W, "center")
        Modal.draw()
        return
    end

    love.graphics.setScissor(0, TOP_Y, W, H - TOP_Y - 28)
    local base_y = TOP_Y - math.floor(S.scroll)
    for i, hb in ipairs(list) do
        local y = base_y + (i - 1) * (BAN_H + GAP)
        if y + BAN_H >= TOP_Y and y <= H - 28 then
            draw_banner(hb, i, i == S.sel, y)
        end
    end
    love.graphics.setScissor()

    if #list > VISIBLE then
        local track_x = W - 6
        local track_y = TOP_Y
        local track_h = H - TOP_Y - 28
        love.graphics.setColor(0.15, 0.15, 0.20, 0.65)
        love.graphics.rectangle("fill", track_x, track_y, 3, track_h, 1, 1)

        local total_h = #list * (BAN_H + GAP) - GAP
        local ratio = (H - TOP_Y - 28) / total_h
        local bar_h = math.max(24, track_h * ratio)
        local span = total_h - (H - TOP_Y - 28)
        local bar_y = track_y + (span > 0
            and (S.target / span) * (track_h - bar_h) or 0)
        bar_y = math.max(track_y, math.min(track_y + track_h - bar_h, bar_y))

        love.graphics.setColor(th.accent)
        love.graphics.rectangle("fill", track_x, bar_y, 3, bar_h, 1, 1)
    end

    BI.draw_footer(th, {
        { key = "dpad", label = "Navigate" },
        { key = "a",    label = "Launch"   },
        { key = "b",    label = "Back"     },
        { key = "y",    label = ("%d apps"):format(#list) },
    }, W, H - 22, A.font(th.font_body, 12))

    Modal.draw()
end

return S