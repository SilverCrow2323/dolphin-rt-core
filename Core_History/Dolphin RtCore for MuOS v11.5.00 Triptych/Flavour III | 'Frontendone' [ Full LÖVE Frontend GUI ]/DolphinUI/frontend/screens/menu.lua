-- frontend/screens/menu.lua — Nexus main menu.
--
-- v0.7.0 — mirror layout on Wii
--   * When theme.grid_mirror is true (Wii), the whole layout is
--     horizontally mirrored: hero panel on the right, sign panels
--     on the left, danger panels at the bottom-left.
--   * NAV left/right is swapped in mirror mode, so the D-pad
--     follows the visual layout.
--   * Carets, cables, cursor arrows are all flipped to match.
--   * Panel bodies now come from theme.card_bg / theme.card_bg_alt
--     with a theme-aware fallback. On Wii this yields light azure
--     cards instead of the old hardcoded dark slabs that looked
--     out of place against the light background.
--   * Panel borders come from theme.card_border / card_border_lo.

local A       = require("assets")
local SFX     = require("sfx")
local State   = require("state")
local IM      = require("input_map")
local D       = require("ui.draw")
local BG      = require("ui.bg")
local Header  = require("ui.header")
local Icons   = require("ui.icons")
local BI      = require("button_icons")
local GL      = require("ui.glyph")
local PM      = require("profile_manager")

local S = {}
local W, H = 640, 480

-- ── Mirror helpers ─────────────────────────────────────────
local function mirrored()
  return State.theme and State.theme.grid_mirror == true
end

-- Mirror an x coordinate: place a `w`-wide element that would
-- normally sit at `x` on the opposite side.
local function MX(x, w)
  if not mirrored() then return x end
  return W - x - w
end

-- Sign of the mirror, for cable bulges, caret direction, etc.
local function MDIR()
  return mirrored() and -1 or 1
end

-- Caret placement: outside the panel, on the "outer" side.
local function caret_x(x, w, offset, t)
  offset = offset or 8
  if mirrored() then
    return x + w + offset + math.sin(t * 6) * 3
  end
  return x - offset + math.sin(t * 6) * 3
end

-- ── Card colours ───────────────────────────────────────────
local function card_colors(th, focused)
  local is_wii = (th.id == "wii")
  local base = th.card_bg
      or (is_wii and {0.88, 0.94, 0.99})
      or  {0.06, 0.05, 0.09}
  local hi   = th.card_bg_alt
      or (is_wii and {0.76, 0.88, 0.97})
      or  {0.04, 0.03, 0.07}
  return focused and hi or base
end

local function card_border(th, focused)
  local is_wii = (th.id == "wii")
  if focused then
    return th.card_border
        or (is_wii and {0.30, 0.62, 0.88})
        or  {0.55, 0.45, 0.75}
  end
  return th.card_border_lo
      or (is_wii and {0.62, 0.78, 0.90})
      or  {0.28, 0.28, 0.35}
end

-- ── Layout ─────────────────────────────────────────────────
-- All positions are given as if the layout were NOT mirrored.
-- The renderer calls MX(x, w) at draw time to flip them.
local HERO_X, HERO_Y, HERO_W, HERO_H = 20, 82, 290, 240

local SIGN_X, SIGN_W = 320, 270
local SIGN_H         = 76
local SIGN1_Y        = 82
local SIGN2_Y        = 166
local SIGN3_Y        = 250

local FLAT_Y, FLAT_H = 330, 76

local INFO_Y, INFO_H = 412, 22
local FOOTER_CENTER  = H - 22

-- ── Scanner helper ─────────────────────────────────────────
local function draw_scanner(x, y, w, h, col, period, phase)
  local t = (State.t_ui or 0) + (phase or 0)
  local p = (t % period) / period
  local e = p < 0.5 and (2 * p * p) or (1 - ((-2 * p + 2) ^ 2) / 2)
  local cx = x + e * (w - 40)
  for i = 0, 2 do
    local a = (0.40 - i * 0.12)
    love.graphics.setColor(col[1], col[2], col[3], a)
    love.graphics.rectangle("fill", cx - i * 3, y, 3, h, 1, 1)
  end
  love.graphics.setColor(1, 1, 1, 0.85)
  love.graphics.rectangle("fill", cx, y + 2, 2, h - 4, 1, 1)
end

-- ── Item catalogue (positions are logical, not mirrored) ───
local ITEMS = {
    {
        key = "library", label = "GAME LIBRARY", icon = "library",
        x = HERO_X, y = HERO_Y, w = HERO_W, h = HERO_H,
        style = "hero", color = {0.55, 0.35, 0.95},
        desc = "Browse & play", tag = "PLAY",
    },
    {
        key = "homebrew", label = "HOMEBREW HUB", icon = "homebrew",
        x = SIGN_X, y = SIGN1_Y, w = SIGN_W, h = SIGN_H,
        style = "sign", color = {0.20, 0.72, 0.98},
        desc = "Homebrew apps",
    },
    {
        key = "enhancer", label = "RT:ENHANCER DOCK", icon = "enhancer",
        x = SIGN_X, y = SIGN2_Y, w = SIGN_W, h = SIGN_H,
        style = "sign", color = {0.96, 0.77, 0.26},
        desc = "Content store",
    },
    {
        key = "compatibility", label = "COMPATIBILITY", icon = "info",
        x = SIGN_X, y = SIGN3_Y, w = SIGN_W, h = SIGN_H,
        style = "sign", color = {0.30, 0.80, 0.60},
        desc = "Community test reports",
    },
    {
        key = "workshop", label = "WORKSHOP", icon = "workshop",
        x = 20, y = FLAT_Y, w = 190, h = FLAT_H,
        style = "flat", color = {0.90, 0.30, 0.55},
        desc = "Profiles & mods",
    },
    {
        key = "settings", label = "SETTINGS", icon = "settings",
        x = 220, y = FLAT_Y, w = 190, h = FLAT_H,
        style = "flat", color = {0.30, 0.80, 0.60},
        desc = "App & core config",
    },
    {
        key = "restart", label = "RESTART", icon = "restart",
        x = 420, y = FLAT_Y, w = 100, h = 34,
        style = "danger", color = {0.30, 0.80, 0.40},
    },
    {
        key = "logout", label = "LOG OUT", icon = "logout",
        x = 420, y = FLAT_Y + 40, w = 100, h = 34,
        style = "danger", color = {0.85, 0.25, 0.25},
    },
}

-- ── Navigation graph ────────────────────────────────────────
-- Both tables are precomputed. The correct one is selected at
-- read time by `nav_for()`.
local NAV_NORMAL = {
    library       = { left = "library",       right = "homebrew",        up = "library",       down = "workshop"      },
    homebrew      = { left = "library",       right = "homebrew",        up = "homebrew",      down = "enhancer"      },
    enhancer      = { left = "library",       right = "enhancer",        up = "homebrew",      down = "compatibility" },
    compatibility = { left = "library",       right = "compatibility",   up = "enhancer",      down = "settings"      },
    workshop      = { left = "workshop",      right = "settings",        up = "library",       down = "workshop"      },
    settings      = { left = "workshop",      right = "restart",         up = "compatibility", down = "settings"      },
    restart       = { left = "settings",      right = "restart",         up = "compatibility", down = "logout"        },
    logout        = { left = "settings",      right = "logout",          up = "restart",       down = "logout"        },
}

-- Mirror: swap left and right for every entry.
local NAV_MIRROR = {}
for k, v in pairs(NAV_NORMAL) do
    NAV_MIRROR[k] = {
        left  = v.right,
        right = v.left,
        up    = v.up,
        down  = v.down,
    }
end

local function nav_for(focus)
    if mirrored() then return NAV_MIRROR[focus] end
    return NAV_NORMAL[focus]
end

S.focus = "library"
S.glitch_t = 0
S.glitch_active = 0
S.info = nil

-- ── Info strip data ────────────────────────────────────────
local function compute_info()
    local drift = { saved = true, profile = "Default" }
    pcall(function() drift = PM.detect_drift("rtcoreprofile") end)

    local gc, wii, hb = 0, 0, 0
    if State.roms then
        for _, g in ipairs(State.roms) do
            if g.sys == "GC" then gc = gc + 1
            elseif g.sys == "Wii" then wii = wii + 1 end
        end
    end
    if State.homebrew then hb = #State.homebrew end

    local stats = State.games_data_stats
        and State.games_data_stats() or { total = 0 }
    local now = os.date("*t")

    S.info = {
        profile  = drift.profile or "Default",
        saved    = drift.saved,
        gc       = gc,
        wii      = wii,
        hb       = hb,
        compat   = stats.total or 0,
        time     = string.format("%02d:%02d", now.hour, now.min),
        update   = State.update_available,
    }
end

function S.enter() compute_info() end
function S.re_enter() compute_info() end

-- ── Activation ─────────────────────────────────────────────
local function find_item(key)
    for _, it in ipairs(ITEMS) do if it.key == key then return it end end
end

local function activate()
    local it = find_item(S.focus)
    if not it then return end
    SFX.play("menu_select")
    if     it.key == "library"       then State.go("library")
    elseif it.key == "homebrew"      then State.go("homebrew_hub")
    elseif it.key == "enhancer"      then State.go("enhancer_boot")
    elseif it.key == "compatibility" then State.go("compatibility")
    elseif it.key == "workshop"      then State.go("workshop")
    elseif it.key == "settings"      then State.go("settings")
    elseif it.key == "restart"       then
        if State.restart_app then State.restart_app()
        else love.event.quit("restart") end
    elseif it.key == "logout"        then love.event.quit() end
end

local function move(dir)
    local adj = nav_for(S.focus)
    if not adj then return end
    local target = adj[dir]
    if target and target ~= S.focus then
        S.focus = target
        SFX.play("menu_move")
    end
end

function S.pad(b) if b == IM.A then activate() end end

function S.hat(dir)
    if     dir == "left"  then move("left")
    elseif dir == "right" then move("right")
    elseif dir == "up"    then move("up")
    elseif dir == "down"  then move("down") end
end

function S.key(k)
    if     k == "left"  then move("left")
    elseif k == "right" then move("right")
    elseif k == "up"    then move("up")
    elseif k == "down"  then move("down")
    elseif k == "return" or k == "space" then activate() end
end

function S.update(dt)
    S.glitch_t = S.glitch_t + dt
    if S.glitch_active > 0 then
        S.glitch_active = S.glitch_active - dt
    elseif S.glitch_t > 3 + math.random() * 3 then
        S.glitch_t = 0
        S.glitch_active = 0.06
    end
end

-- ── Drawing helpers ────────────────────────────────────────
local function draw_cable(p0, p1, p2, col, alpha, thick)
    local segs = 20
    thick = thick or 2
    love.graphics.setLineWidth(thick)
    love.graphics.setColor(col[1], col[2], col[3], alpha or 1)
    local pts = {}
    for i = 0, segs do
        local t = i / segs
        local u = 1 - t
        local x = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]
        local y = u * u * p0[2] + 2 * u * t * p1[2] + t * t * p2[2]
        table.insert(pts, x)
        table.insert(pts, y)
    end
    love.graphics.line(pts)
    love.graphics.setLineWidth(1)
end

local function screw_colors(th)
    if th.id == "wii" then
        return {0.72, 0.74, 0.80}, {0.45, 0.48, 0.55}
    end
    return {0.45, 0.45, 0.50}, {0.20, 0.20, 0.24}
end

local function draw_screw(cx, cy, r, th)
    local hi, lo = screw_colors(th)
    love.graphics.setColor(hi)
    love.graphics.circle("fill", cx, cy, r)
    love.graphics.setColor(lo)
    love.graphics.setLineWidth(1)
    love.graphics.line(cx - r + 1, cy, cx + r - 1, cy)
    love.graphics.line(cx, cy - r + 1, cx, cy + r - 1)
    love.graphics.setColor(0.7, 0.7, 0.75, 0.6)
    love.graphics.circle("line", cx - 0.5, cy - 0.5, r - 0.5)
end

local function draw_restart_icon(cx, cy, size, col)
    love.graphics.setColor(col)
    love.graphics.setLineWidth(math.max(1.5, size * 0.14))
    local r = size / 2 - 2
    love.graphics.arc("line", "open", cx, cy, r, math.rad(-30), math.rad(240))
    love.graphics.setLineWidth(1)
    local a = math.rad(-30)
    local ax = cx + math.cos(a) * r
    local ay = cy + math.sin(a) * r
    local s = size * 0.22
    love.graphics.polygon("fill",
        ax - s * 0.3, ay - s,
        ax + s, ay,
        ax - s * 0.3, ay + s)
end

-- ── Hero panel ─────────────────────────────────────────────
local function draw_hero(it, focused, t, th)
    local c = it.color
    local rad = 14
    -- Mirror-aware position
    local x = MX(it.x, it.w)
    local y, w, h = it.y, it.w, it.h

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x + 2, y + 3, w, h, rad, rad)

    -- Body: theme card colour
    local body = card_colors(th, focused)
    love.graphics.setColor(body[1], body[2], body[3], focused and 0.99 or 0.94)
    love.graphics.rectangle("fill", x, y, w, h, rad, rad)

    -- Top accent gradient
    love.graphics.setColor(c[1], c[2], c[3], focused and 0.30 or 0.10)
    love.graphics.rectangle("fill", x, y, w, h * 0.5, rad, rad)

    -- Frame
    local bd1 = card_border(th, false)
    love.graphics.setColor(bd1[1], bd1[2], bd1[3], 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, w, h, rad, rad)
    local bd2 = card_border(th, focused)
    love.graphics.setColor(bd2[1], bd2[2], bd2[3], focused and 0.9 or 0.5)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x + 2, y + 2, w - 4, h - 4,
        rad - 1, rad - 1)
    love.graphics.setColor(c[1], c[2], c[3], focused and 1.0 or 0.45)
    love.graphics.setLineWidth(focused and 3.0 or 1.2)
    love.graphics.rectangle("line", x + 5, y + 5, w - 10, h - 10,
        rad - 2, rad - 2)
    love.graphics.setLineWidth(1)

    -- Screws
    draw_screw(x + 12, y + 12, 4, th)
    draw_screw(x + w - 12, y + 12, 4, th)
    draw_screw(x + 12, y + h - 12, 4, th)
    draw_screw(x + w - 12, y + h - 12, 4, th)

    -- Scanlines
    love.graphics.setColor(0, 0, 0, th.id == "wii" and 0.035 or 0.06)
    for yy = y + 8, y + h - 8, 3 do
        love.graphics.line(x + 10, yy, x + w - 10, yy)
    end

    -- Icon and title — kept left-aligned regardless of mirror.
    Icons.draw(it.icon, x + 24, y + 24, 60, c)

    love.graphics.setFont(A.title_font("GAME", 22))
    love.graphics.setColor(focused and th.text or th.text_dim)
    love.graphics.print("GAME",    x + 100, y + 32)
    love.graphics.print("LIBRARY", x + 100, y + 60)

    love.graphics.setFont(A.font(th.font_body, 12))
    love.graphics.setColor(c[1], c[2], c[3], focused and 1.0 or 0.7)
    local info = S.info or {}
    local gc = info.gc or 0
    local wii = info.wii or 0
    love.graphics.print(string.format("%d GC · %d Wii", gc, wii),
        x + 24, y + 100)

    love.graphics.setColor(c[1], c[2], c[3], focused and 0.6 or 0.3)
    love.graphics.line(x + 24, y + 118, x + w - 24, y + 118)

    -- Stats row
    local cols = {
        { "GC",     tostring(info.gc     or 0), {0.55, 0.35, 0.95} },
        { "WII",    tostring(info.wii    or 0), {0.20, 0.72, 0.98} },
        { "HB",     tostring(info.hb     or 0), {0.30, 0.80, 0.60} },
        { "COMPAT", tostring(info.compat or 0), {0.96, 0.77, 0.26} },
    }
    local colw = (w - 48) / #cols
    for i, col in ipairs(cols) do
        local cx = x + 24 + (i - 1) * colw
        love.graphics.setFont(A.font(th.font_body_bold, 9))
        love.graphics.setColor(0.55, 0.58, 0.68, focused and 1.0 or 0.7)
        love.graphics.print(col[1], cx, y + 138)

        love.graphics.setFont(A.font(th.font_body_bold, 20))
        love.graphics.setColor(col[3][1], col[3][2], col[3][3],
            focused and 1.0 or 0.72)
        love.graphics.print(col[2], cx, y + 152)
    end

    -- Tag
    if it.tag then
        local font = A.font(th.font_body_bold, 10)
        love.graphics.setFont(font)
        local tw = font:getWidth(it.tag) + 14
        love.graphics.setColor(c[1], c[2], c[3], focused and 1.0 or 0.7)
        love.graphics.rectangle("fill", x + w - tw - 16, y + 22, tw, 18, 9, 9)
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.printf(it.tag, x + w - tw - 16, y + 25, tw, "center")
    end

    -- Focus effects
    if focused then
        local pulse = 0.5 + 0.5 * math.sin(t * 4)
        D.glow(x + w/2, y + h/2, w * 0.62, c, 0.55 + pulse * 0.30)
        D.glow(x + w/2, y + h/2, w * 0.40, c, 0.35 + pulse * 0.20)

        draw_scanner(x + 8, y + h - 12, w - 16, 3, c, 1.6, 0.0)
        D.corner_brackets(x - 6, y - 6, w + 12, h + 12, c, 26)

        -- Caret, mirrored
        local ax = caret_x(x, w, 10, t)
        local tip_sign = mirrored() and -1 or 1
        love.graphics.setColor(c[1], c[2], c[3], 0.5)
        love.graphics.polygon("fill",
            ax - tip_sign * 2, y + h/2 - 10,
            ax + tip_sign * 8, y + h/2 - 10,
            ax + tip_sign * 12, y + h/2,
            ax + tip_sign * 8, y + h/2 + 10,
            ax - tip_sign * 2, y + h/2 + 10)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.polygon("fill",
            ax, y + h/2 - 7,
            ax + tip_sign * 7, y + h/2,
            ax, y + h/2 + 7)

        -- Indicator label — position follows the panel edge
        love.graphics.setFont(A.font(th.font_body_bold, 9))
        local label = "FOCUSED"
        local lw = love.graphics.getFont():getWidth(label) + 14
        love.graphics.setColor(c)
        love.graphics.rectangle("fill", x + w - lw - 16, y + h - 24, lw, 16, 8, 8)
        GL.dot(x + w - lw - 16 + 8, y + h - 16, 2.5, {0, 0, 0}, 0.9)
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.printf(label, x + w - lw - 16 + 12, y + h - 21, lw - 14,
            "center")
    end
end

-- ── Sign panel ─────────────────────────────────────────────
local function draw_sign(it, focused, t, th)
    local c = it.color
    local rad = 8
    local x = MX(it.x, it.w)
    local y, w, h = it.y, it.w, it.h

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x + 2, y + 2, w, h, rad, rad)

    -- Body
    local body = card_colors(th, focused)
    love.graphics.setColor(body[1], body[2], body[3], focused and 0.99 or 0.90)
    love.graphics.rectangle("fill", x, y, w, h, rad, rad)

    -- Left rail (still on the left, since sign content is left-aligned)
    love.graphics.setColor(c[1], c[2], c[3], focused and 1.0 or 0.65)
    love.graphics.rectangle("fill", x, y, focused and 6 or 4, h, rad, rad)

    -- Inner tint
    love.graphics.setColor(c[1], c[2], c[3], focused and 0.20 or 0.06)
    love.graphics.rectangle("fill", x, y, w, h, rad, rad)

    -- Borders
    local bd1 = card_border(th, false)
    love.graphics.setColor(bd1[1], bd1[2], bd1[3], 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, rad, rad)
    local bd2 = card_border(th, focused)
    love.graphics.setColor(bd2[1], bd2[2], bd2[3], focused and 1.0 or 0.55)
    love.graphics.setLineWidth(focused and 2.6 or 1.2)
    love.graphics.rectangle("line", x + 3, y + 3, w - 6, h - 6, rad - 2, rad - 2)
    love.graphics.setLineWidth(1)

    local icon_size = 32
    Icons.draw(it.icon, x + 16, y + (h - icon_size) / 2, icon_size,
        focused and {1, 1, 1} or c)

    love.graphics.setFont(A.title_font(it.label, 14))
    love.graphics.setColor(focused and th.text or th.text_dim)
    love.graphics.print(it.label, x + 60, y + 16)

    love.graphics.setFont(A.font(th.font_body, 11))
    love.graphics.setColor(c[1], c[2], c[3], focused and 1.0 or 0.75)
    love.graphics.print(it.desc or "", x + 60, y + 36)

    if it.key == "homebrew" then
        love.graphics.setFont(A.font(th.font_body, 10))
        love.graphics.setColor(0.60, 0.65, 0.75, focused and 1.0 or 0.7)
        love.graphics.print(
            ("%d apps"):format((S.info and S.info.hb) or 0),
            x + 60, y + 52)
    elseif it.key == "compatibility" then
        love.graphics.setFont(A.font(th.font_body, 10))
        love.graphics.setColor(0.60, 0.65, 0.75, focused and 1.0 or 0.7)
        love.graphics.print(
            ("%d reports"):format((S.info and S.info.compat) or 0),
            x + 60, y + 52)
    end

    if focused then
        local pulse = 0.5 + 0.5 * math.sin(t * 4)
        D.glow(x + w/2, y + h/2, w * 0.55, c, 0.5 + pulse * 0.25)
        draw_scanner(x + 8, y + h - 8, w - 16, 2, c, 1.4, it.x * 0.01)
        D.corner_brackets(x - 4, y - 4, w + 8, h + 8, c, 14)

        -- Caret: same story as hero, but no caret on signs by
        -- default. Add a small left-pointing arrow if mirrored.
        if mirrored() then
            local ax = x + w + 12
            love.graphics.setColor(c[1], c[2], c[3], 0.55)
            love.graphics.polygon("fill",
                ax + 2, y + h/2 - 8,
                ax - 7, y + h/2 - 8,
                ax - 10, y + h/2,
                ax - 7, y + h/2 + 8,
                ax + 2, y + h/2 + 8)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.polygon("fill",
                ax, y + h/2 - 6,
                ax - 6, y + h/2,
                ax, y + h/2 + 6)
        end
    end
end

-- ── Sign connectors ────────────────────────────────────────
local function draw_sign_cables(t)
    local dir = MDIR()

    -- Outer x of the sign column, in mirrored coordinates.
    -- Non-mirror: right edge of sign. Mirror: left edge of sign.
    local sign_outer = mirrored() and SIGN_X or (SIGN_X + SIGN_W)

    local y1 = SIGN1_Y + SIGN_H / 2
    local y2 = SIGN2_Y + SIGN_H / 2
    local y3 = SIGN3_Y + SIGN_H / 2

    local function col_for(key)
        local it = find_item(key)
        return it and it.color or {0.55, 0.55, 0.65}
    end
    local c_hb = col_for("homebrew")
    local c_en = col_for("enhancer")
    local c_cp = col_for("compatibility")

    local function cable_pair(top_y, bot_y, offset_outer, offset_inner)
        local p0 = { sign_outer, top_y }
        local p1 = { sign_outer + offset_outer * dir, (top_y + bot_y) / 2 }
        local p2 = { sign_outer, bot_y }
        local q0 = { sign_outer, top_y + 15 }
        local q1 = { sign_outer + offset_inner * dir, (top_y + bot_y) / 2 }
        local q2 = { sign_outer, bot_y - 15 }

        draw_cable(p0, p1, p2, {0.20, 0.20, 0.25}, 0.9, 3)
        draw_cable(q0, q1, q2, {0.20, 0.20, 0.25}, 0.85, 2.5)
        local base = {0.42, 0.42, 0.50}
        draw_cable(p0, p1, p2, base, 0.85, 2.2)
        draw_cable(q0, q1, q2, base, 0.75, 1.8)

        local any = (S.focus == "homebrew" or S.focus == "enhancer"
                     or S.focus == "compatibility")
        if any then
            local pulse = 0.55 + 0.45 * math.sin((State.t_ui or 0) * 3)
            local cc = (S.focus == "homebrew") and c_hb
                    or (S.focus == "enhancer") and c_en
                    or c_cp
            draw_cable(p0, p1, p2, cc, pulse * 0.65, 1.3)
            draw_cable(q0, q1, q2, cc, pulse * 0.55, 1.1)
        end

        love.graphics.setColor(0.30, 0.30, 0.36, 1)
        love.graphics.circle("fill", sign_outer, top_y, 3.5)
        love.graphics.circle("fill", sign_outer, bot_y, 3.5)
        love.graphics.setColor(0.55, 0.55, 0.62, 0.8)
        love.graphics.circle("line", sign_outer, top_y, 3.5)
        love.graphics.circle("line", sign_outer, bot_y, 3.5)

        love.graphics.setColor(0.30, 0.30, 0.36, 1)
        love.graphics.circle("fill", sign_outer, top_y + 15, 2.5)
        love.graphics.circle("fill", sign_outer, bot_y - 15, 2.5)
    end

    cable_pair(y1, y2, 50, 30)
    cable_pair(y2, y3, 50, 30)
end

-- ── Flat panel ─────────────────────────────────────────────
local function draw_flat(it, focused, t, th)
    local c = it.color
    local x = MX(it.x, it.w)
    local y, w, h = it.y, it.w, it.h

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x + 2, y + 2, w, h, 4, 4)

    local body = card_colors(th, focused)
    love.graphics.setColor(body[1], body[2], body[3], focused and 0.99 or 0.90)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    love.graphics.setColor(c[1], c[2], c[3], focused and 0.35 or 0.18)
    love.graphics.rectangle("fill", x, y, focused and 7 or 5, h, 4, 4)

    love.graphics.setColor(c[1], c[2], c[3], focused and 0.18 or 0.06)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    local bd1 = card_border(th, false)
    love.graphics.setColor(bd1[1], bd1[2], bd1[3], 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    local bd2 = card_border(th, focused)
    love.graphics.setColor(bd2[1], bd2[2], bd2[3], focused and 1.0 or 0.5)
    love.graphics.setLineWidth(focused and 2.4 or 1.2)
    love.graphics.rectangle("line", x + 2, y + 2, w - 4, h - 4, 3, 3)
    love.graphics.setLineWidth(1)

    Icons.draw(it.icon, x + 14, y + h/2 - 14, 28,
        focused and {1, 1, 1} or c)

    love.graphics.setFont(A.title_font(it.label, 13))
    love.graphics.setColor(focused and th.text or th.text_dim)
    love.graphics.print(it.label, x + 52, y + 14)

    if it.desc then
        love.graphics.setFont(A.font(th.font_body, 10))
        love.graphics.setColor(c[1], c[2], c[3], focused and 1.0 or 0.7)
        love.graphics.print(it.desc, x + 52, y + 36)
    end

    if focused then
        local pulse = 0.5 + 0.5 * math.sin(t * 4)
        D.glow(x + w/2, y + h/2, w * 0.65, c, 0.55 + pulse * 0.25)
        draw_scanner(x + 6, y + h - 8, w - 12, 2, c, 1.5, it.y * 0.01)
        D.corner_brackets(x - 3, y - 3, w + 6, h + 6, c, 12)
    end
end

-- ── Danger panel ───────────────────────────────────────────
local function draw_danger(it, focused, t, th)
    local c = it.color
    local x = MX(it.x, it.w)
    local y, w, h = it.y, it.w, it.h

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x + 2, y + 2, w, h, 4, 4)

    love.graphics.setColor(c[1] * (focused and 0.55 or 0.35),
                           c[2] * (focused and 0.55 or 0.35),
                           c[3] * (focused and 0.55 or 0.35), 0.98)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    love.graphics.setColor(c[1] * 0.85, c[2] * 0.85, c[3] * 0.85,
        focused and 0.75 or 0.5)
    love.graphics.rectangle("fill", x + 2, y + 2, w - 4, h/2 - 2, 3, 3)

    love.graphics.setColor(c[1], c[2], c[3], focused and 1.0 or 0.72)
    love.graphics.setLineWidth(focused and 3.0 or 1.5)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    love.graphics.setLineWidth(1)

    local icon_size = 20
    local icon_x = x + 10
    local icon_y = y + (h - icon_size) / 2

    if it.key == "restart" then
        draw_restart_icon(icon_x + icon_size / 2, icon_y + icon_size / 2,
            icon_size, {1, 1, 1})
    else
        Icons.draw(it.icon, icon_x, icon_y, icon_size, {1, 1, 1})
    end

    love.graphics.setFont(A.title_font(it.label, 12))
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(it.label, x + 38, y + h/2 - 8)

    if focused then
        local pulse = 0.5 + 0.5 * math.sin(t * 5)
        D.glow(x + w/2, y + h/2, w * 0.75, c, 0.55 + pulse * 0.35)
        love.graphics.setColor(1, 1, 1, 0.65 + pulse * 0.35)
        D.rough_rect(x - 3, y - 3, w + 6, h + 6,
            { jitter = 1.2, thickness = 2, seed = 91 })
        D.corner_brackets(x - 2, y - 2, w + 4, h + 4, c, 8)
    end
end

-- ── Info strip ─────────────────────────────────────────────
local function draw_info_strip(th)
    local info = S.info
    if not info then return end
    local y, h = INFO_Y, INFO_H

    love.graphics.setColor(0, 0, 0, th.id == "wii" and 0.30 or 0.55)
    love.graphics.rectangle("fill", 0, y, W, h)
    love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.35)
    love.graphics.rectangle("fill", 0, y, W, 1)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, y + h - 1, W, 1)

    local font = A.font(th.font_body_bold, 10)
    love.graphics.setFont(font)

    local cx = 14
    local function pill(label, value, col)
        love.graphics.setColor(0.55, 0.60, 0.72)
        love.graphics.print(label, cx, y + 6)
        cx = cx + font:getWidth(label) + 5
        love.graphics.setColor(col)
        love.graphics.print(value, cx, y + 6)
        cx = cx + font:getWidth(value) + 12
        love.graphics.setColor(0.35, 0.38, 0.45)
        love.graphics.rectangle("fill", cx - 6, y + 5, 1, 10)
    end

    pill("PROFILE:", info.profile, {0.96, 0.77, 0.26})
    pill("STATUS:", info.saved and "SAVED" or "UNSAVED",
        info.saved and {0.30, 0.80, 0.40} or {0.90, 0.30, 0.30})
    pill("GC:",  tostring(info.gc),  {0.55, 0.35, 0.95})
    pill("WII:", tostring(info.wii), {0.20, 0.72, 0.98})
    pill("HB:",  tostring(info.hb),  {0.30, 0.80, 0.60})
    pill("COMPAT:", tostring(info.compat), {0.96, 0.77, 0.26})

    local rx = W - 14
    love.graphics.setFont(font)
    local tw = font:getWidth(info.time)
    love.graphics.setColor(0.72, 0.76, 0.85)
    love.graphics.print(info.time, rx - tw, y + 6)
    rx = rx - tw - 16

    if info.update then
        local utxt = "UPDATE v" .. info.update.version
        local uw = font:getWidth(utxt)
        love.graphics.setColor(0.96, 0.77, 0.26)
        love.graphics.print(utxt, rx - uw, y + 6)
        local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 5)
        love.graphics.setColor(0.96, 0.77, 0.26, 0.4 + pulse * 0.6)
        love.graphics.circle("fill", rx - uw - 8, y + 11, 3)
    end
end

-- ── Viewport frame ─────────────────────────────────────────
local function draw_viewport_frame(th)
    local c = th.accent
    love.graphics.setColor(c[1], c[2], c[3], 0.25)
    love.graphics.setLineWidth(1)
    love.graphics.line(4, 74, 4, 54); love.graphics.line(4, 54, 20, 54)
    love.graphics.line(W - 20, 54, W - 4, 54)
    love.graphics.line(W - 4, 54, W - 4, 74)
    love.graphics.line(4, H - 20, 4, H - 4)
    love.graphics.line(4, H - 4, 20, H - 4)
    love.graphics.line(W - 20, H - 4, W - 4, H - 4)
    love.graphics.line(W - 4, H - 4, W - 4, H - 20)
end

-- ── Glitch ─────────────────────────────────────────────────
local function draw_glitch(th)
    if S.glitch_active <= 0 then return end
    local c = th.focus
    for i = 1, 6 do
        local y = math.random() * H
        local h = 1 + math.random() * 4
        local off = (math.random() - 0.5) * 24
        love.graphics.setColor(c[1], c[2], c[3], 0.35)
        love.graphics.rectangle("fill", off, y, W, h)
    end
    if math.random() < 0.3 then
        local y = math.random() * H
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("fill", 0, y, W, 1)
    end
end

-- ── Main draw ──────────────────────────────────────────────
function S.draw()
    local th = State.theme
    local t = State.t_ui

    BG.draw_nexus(W, H, love.timer.getDelta(), th.accent)
    draw_viewport_frame(th)

    Header.draw("DOLPHINUI - NEXUS", "library")

    draw_sign_cables(t)

    for _, it in ipairs(ITEMS) do
        local focused = (it.key == S.focus)
        if     it.style == "hero"   then draw_hero(it, focused, t, th)
        elseif it.style == "sign"   then draw_sign(it, focused, t, th)
        elseif it.style == "flat"   then draw_flat(it, focused, t, th)
        elseif it.style == "danger" then draw_danger(it, focused, t, th)
        end
    end

    draw_info_strip(th)

    BI.draw_footer(th, {
        { key = "dpad",   label = "Navigate"   },
        { key = "a",      label = "Enter"      },
    }, W, FOOTER_CENTER, A.font(th.font_body, 12))

    draw_glitch(th)
end

return S