-- ui/kit.lua — Dolphin Rt:UI design system (v2).
--
-- Principles: one accent per system (GameCube violet / Wii cyan), flat dark
-- surfaces with chamfered corners, readable type (>= 12 px), almost no
-- per-frame work: the background is rendered once into a canvas, text
-- metrics are cached, lists only draw what is visible.
--
-- Effects level (Settings > Effects):  full = animated glow + sweep,
-- lite = static, off = no glow at all. K.fx reads from core.settings.

local Fonts = require("ui.theme.fonts")

local K = {}
K.W, K.H = 640, 480
K.MARGIN = 24
K.HEAD_H = 76
K.FOOT_H = 36
K.TOP = K.HEAD_H + 8                    -- first usable y under the header
K.BOT = K.H - K.FOOT_H - 8              -- last usable y above the footer

K.C = {
    bg0   = { 0.030, 0.035, 0.070 },
    bg1   = { 0.065, 0.075, 0.125 },
    surf  = { 0.090, 0.105, 0.170 },
    surf2 = { 0.130, 0.150, 0.235 },
    line  = { 0.220, 0.250, 0.370 },
    text  = { 0.94, 0.95, 0.99 },
    dim   = { 0.64, 0.68, 0.80 },
    faint = { 0.42, 0.46, 0.60 },
    ok    = { 0.29, 0.87, 0.50 },
    warn  = { 0.96, 0.77, 0.26 },
    bad   = { 1.00, 0.36, 0.42 },
}
K.ACC = {
    workshop = { 0.35, 0.55, 0.95 },
    gc    = { 0.55, 0.47, 1.00 },
    wii   = { 0.25, 0.80, 0.98 },
    boost = { 0.96, 0.77, 0.26 },
    hot   = { 1.00, 0.42, 0.64 },
    sys   = { 0.40, 0.88, 0.72 },
    mods  = { 1.00, 0.55, 0.22 },
    blue  = { 0.36, 0.56, 1.00 },
    teal  = { 0.30, 0.85, 0.90 },
    lime  = { 0.66, 0.92, 0.34 },
}
K.acc = K.ACC.gc
K.fx = "lite"
K.t = 0


-- ── palettes ────────────────────────────────────────────────
K.PALETTES = {
    gc = {
        C = {
            bg0={0.030,0.035,0.070}, bg1={0.065,0.075,0.125},
            surf={0.090,0.105,0.170}, surf2={0.130,0.150,0.235},
            line={0.220,0.250,0.370}, text={0.94,0.95,0.99},
            dim={0.64,0.68,0.80},     faint={0.42,0.46,0.60},
            ok={0.29,0.87,0.50},      warn={0.96,0.77,0.26}, bad={1.00,0.36,0.42},
        },
        ACC = {
            gc={0.55,0.47,1.00},   wii={0.25,0.80,0.98},
            boost={0.96,0.77,0.26}, hot={1.00,0.42,0.64},
            sys={0.40,0.88,0.72},   mods={1.00,0.55,0.22},
            blue={0.36,0.56,1.00},  teal={0.30,0.85,0.90},
            lime={0.66,0.92,0.34},
        },
    },
    wii = {
        C = {
            bg0={0.024,0.055,0.098}, bg1={0.045,0.105,0.180},
            surf={0.070,0.135,0.230}, surf2={0.105,0.185,0.290},
            line={0.180,0.320,0.460}, text={0.92,0.97,1.00},
            dim={0.58,0.68,0.78},     faint={0.38,0.48,0.58},
            ok={0.29,0.87,0.50},      warn={0.96,0.77,0.26}, bad={1.00,0.36,0.42},
        },
        ACC = {
            gc={0.30,0.85,0.95},   wii={0.20,0.75,0.99},
            boost={1.00,0.80,0.35}, hot={1.00,0.50,0.72},
            sys={0.35,0.90,0.75},   mods={1.00,0.60,0.30},
            blue={0.35,0.65,1.00},  teal={0.25,0.90,0.95},
            lime={0.68,0.94,0.38},
        },
    },
    aurora = {
        C = {
            bg0={0.016,0.071,0.102}, bg1={0.043,0.153,0.208},
            surf={0.070,0.200,0.275}, surf2={0.095,0.275,0.345},
            line={0.150,0.420,0.500}, text={0.88,0.970,0.980},
            dim={0.480,0.620,0.670},  faint={0.320,0.430,0.480},
            ok={0.290,0.870,0.500},   warn={0.960,0.770,0.260}, bad={1.000,0.360,0.420},
        },
        ACC = {
            gc={0.00,0.90,0.69},   wii={0.25,0.85,1.00},
            boost={1.00,0.78,0.34}, hot={1.00,0.55,0.76},
            sys={0.30,0.88,0.75},   mods={1.00,0.66,0.35},
            blue={0.40,0.78,1.00},  teal={0.20,0.90,0.85},
            lime={0.70,0.95,0.40},
        },
    },
}

K.palette_name = "gc"

function K.set_palette(name)
    local p = K.PALETTES[name] or K.PALETTES.gc
    for k, v in pairs(p.C) do
        if K.C[k] then for i=1,3 do K.C[k][i] = v[i] end
        else K.C[k] = { v[1], v[2], v[3] } end
    end
    for k, v in pairs(p.ACC) do
        if K.ACC[k] then for i=1,3 do K.ACC[k][i] = v[i] end
        else K.ACC[k] = { v[1], v[2], v[3] } end
    end
    K.palette_name = name
end

function K.cube(cx, cy, s, ay, ax, base, a)
    ax   = ax   or 0.55
    base = base or K.acc or K.ACC.gc
    a    = a    or 1
    local V = {{-1,-1,-1},{1,-1,-1},{1,1,-1},{-1,1,-1},{-1,-1,1},{1,-1,1},{1,1,1},{-1,1,1}}
    local F = {
        {{1,2,3,4},{0,0,-1}}, {{5,6,7,8},{0,0,1}},
        {{1,2,6,5},{0,-1,0}}, {{3,4,8,7},{0,1,0}},
        {{2,3,7,6},{1,0,0}},  {{1,4,8,5},{-1,0,0}},
    }
    local ca, sa  = math.cos(ay), math.sin(ay)
    local cxx, sx = math.cos(ax), math.sin(ax)
    local pts = {}
    for i, v in ipairs(V) do
        local x, y, z = v[1], v[2], v[3]
        local x1, z1  = x*ca + z*sa, -x*sa + z*ca
        pts[i] = { x1, y*cxx - z1*sx, y*sx + z1*cxx }
    end
    local faces = {}
    for _, f in ipairs(F) do
        local n = f[2]
        local nx, ny, nz = n[1]*ca + n[3]*sa, n[2], -n[1]*sa + n[3]*ca
        if nz > 0 then
            local br = 0.42 + 0.58 * math.max(0, nx*-0.45 + ny*-0.65 + nz*0.62)
            faces[#faces+1] = { nz, f[1], br }
        end
    end
    table.sort(faces, function(p, q) return p[1] < q[1] end)
    for _, f in ipairs(faces) do
        local poly = {}
        for _, i in ipairs(f[2]) do
            poly[#poly+1] = cx + pts[i][1]*s
            poly[#poly+1] = cy + pts[i][2]*s
        end
        local br = f[3]
        love.graphics.setColor(base[1]*br, base[2]*br, base[3]*br, a)
        love.graphics.polygon("fill", poly)
        love.graphics.setColor(
            math.min(1, base[1]*0.8 + 0.30),
            math.min(1, base[2]*0.8 + 0.30),
            math.min(1, base[3]*0.8 + 0.30), a)
        love.graphics.setLineWidth(math.max(1, s / 18))
        love.graphics.polygon("line", poly)
    end
    love.graphics.setLineWidth(1)
end
function K.set_accent(a)
    if type(a) == "string" then a = K.ACC[a] end
    K.acc = a or K.ACC.gc
end

-- ── fonts ───────────────────────────────────────────────────
local FONT_PATHS = {
    xl       = { "assets/fonts/Oxanium-Bold.ttf", 38 },
    title    = { "assets/fonts/Oxanium-Bold.ttf", 32 },
    h        = { "assets/fonts/Oxanium-Bold.ttf", 22 },
    body     = { "assets/fonts/Oxanium-Regular.ttf", 18 },
    small    = { "assets/fonts/Oxanium-Regular.ttf", 16 },
    mono     = { "assets/fonts/JetBrainsMono-Regular.ttf", 14 },
    key      = { "assets/fonts/Oxanium-Bold.ttf", 14 },
    small_i  = { "assets/fonts/ChakraPetch-Italic.ttf", 15 },
    body_i   = { "assets/fonts/ChakraPetch-Italic.ttf", 17 },
    mono_i   = { "assets/fonts/ChakraPetch-Italic.ttf", 14 },
    value    = { "assets/fonts/JetBrainsMono-Bold.ttf", 17 },
}
function K.font(kind)
    local f = FONT_PATHS[kind or "body"] or FONT_PATHS.body
    local ok, font = pcall(Fonts.get, f[1], f[2])
    if ok and font then return font end
    return Fonts.fallback(f[2])
end

-- ── small drawing helpers ───────────────────────────────────
local function col(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end
K.color = col

function K.text(kind, str, x, y, c, a, limit, align)
    love.graphics.setFont(K.font(kind))
    col(c or K.C.text, a)
    if limit then love.graphics.printf(str, x, y, limit, align or "left")
    else love.graphics.print(str, x, y) end
end

-- cut a string to a pixel width, adding an ellipsis
local clip_cache, clip_n = {}, 0
function K.clip(kind, str, maxw)
    str = tostring(str or "")
    local ck = kind .. "|" .. maxw .. "|" .. str
    local hit = clip_cache[ck]
    if hit then return hit end
    if clip_n > 800 then clip_cache, clip_n = {}, 0 end
    local f = K.font(kind)
    if f:getWidth(str) <= maxw then clip_cache[ck] = str; clip_n = clip_n + 1; return str end
    local lo, hi = 0, #str
    while lo < hi do
        local mid = math.ceil((lo + hi) / 2)
        if f:getWidth(str:sub(1, mid) .. "…") <= maxw then lo = mid else hi = mid - 1 end
    end
    local out = str:sub(1, lo) .. "…"
    clip_cache[ck] = out; clip_n = clip_n + 1
    return out
end

function K.width(kind, str) return K.font(kind):getWidth(tostring(str)) end

-- chamfered rectangle (top-left and bottom-right corners cut)
function K.chamfer(x, y, w, h, c)
    c = c or 8
    return { x + c, y, x + w, y, x + w, y + h - c, x + w - c, y + h, x, y + h, x, y + c }
end

function K.panel(x, y, w, h, o)
    o = o or {}
    local a = o.accent or K.acc
    local cut = o.cut or 8
    local pts = K.chamfer(x, y, w, h, cut)
    if o.focus and K._slide and not o.force then return end

    -- Neo-cube surface: shared extrusion, bevel and accent rim.
    local shadow = K.chamfer(x, y + 3, w, h, cut)
    col(K.C.bg0, o.focus and 0.78 or 0.48)
    love.graphics.polygon("fill", shadow)

    if o.focus then
        col(K.C.surf2, 1); love.graphics.polygon("fill", pts)
        col(a, 0.10); love.graphics.polygon("fill", pts)
        if K.fx ~= "off" then
            love.graphics.setLineWidth(5)
            col(a, 0.10 + (K.fx == "full" and 0.035 * math.sin(K.t * 4) or 0))
            love.graphics.polygon("line", pts)
        end
        love.graphics.setLineWidth(2)
        col(a, 1); love.graphics.polygon("line", pts)
    else
        col(o.fill or K.C.surf, o.alpha or 0.96)
        love.graphics.polygon("fill", pts)
        love.graphics.setLineWidth(1)
        col(K.C.line, 0.72); love.graphics.polygon("line", pts)
    end

    -- Top bevel: a reflected edge makes the plate read as a physical surface.
    love.graphics.setLineWidth(1)
    col({ 1, 1, 1 }, o.focus and 0.13 or 0.055)
    love.graphics.line(x + cut, y + 1, x + w - cut, y + 1)
    love.graphics.setLineWidth(1)
end

function K.pill(str, x, yc, c, filled)
    local f = K.font("key")
    love.graphics.setFont(f)
    local w = f:getWidth(str) + 14
    local h = 20
    local y = yc - h / 2
    if filled then col(c, 0.22); love.graphics.rectangle("fill", x - w, y, w, h, 5, 5) end
    col(c, filled and 1 or 0.6)
    love.graphics.rectangle("line", x - w, y, w, h, 5, 5)
    love.graphics.print(str, x - w + 7, yc - f:getHeight() / 2)
    return w + 6
end

function K.switch(x, yc, on, focused)
    local w, h = 38, 20
    local y = yc - h / 2
    local on_col  = K.C.ok
    local off_col = K.C.line
    local c = on and on_col or off_col
    if on then col(on_col, 0.30) else col(off_col, 0.25) end
    love.graphics.rectangle("fill", x, y, w, h, h / 2, h / 2)
    col(c, focused and 1 or 0.85)
    love.graphics.setLineWidth(focused and 2 or 1.4)
    love.graphics.rectangle("line", x, y, w, h, h / 2, h / 2)
    love.graphics.setLineWidth(1)
    col(c, 1)
    love.graphics.circle("fill", on and (x + w - h / 2) or (x + h / 2), yc, h / 2 - 3)
end

function K.bar(x, y, w, h, frac, c)
    col(K.C.surf2, 1); love.graphics.rectangle("fill", x, y, w, h, h / 2, h / 2)
    frac = math.max(0, math.min(1, frac or 0))
    if frac > 0 then
        col(c or K.acc, 1); love.graphics.rectangle("fill", x, y, math.max(h, w * frac), h, h / 2, h / 2)
        col({ 1, 1, 1 }, 0.22)
        love.graphics.rectangle("fill", x + h/2, y + 1, math.max(1, w * frac - h), 1)
    end
end

-- ── background: rendered once ───────────────────────────────
local bg_canvas, bg_for
function K.bg()
    local acc = K.acc
    local key = acc[1] * 3 + acc[2] * 5 + acc[3] * 7
    if not bg_canvas or bg_for ~= key then
        bg_canvas = bg_canvas or love.graphics.newCanvas(K.W, K.H)
        bg_for = key
        love.graphics.push("all")
        love.graphics.setCanvas(bg_canvas)
        love.graphics.origin()
        for y = 0, K.H, 4 do
            local f = y / K.H
            love.graphics.setColor(K.C.bg0[1] + (K.C.bg1[1] - K.C.bg0[1]) * f,
                                   K.C.bg0[2] + (K.C.bg1[2] - K.C.bg0[2]) * f,
                                   K.C.bg0[3] + (K.C.bg1[3] - K.C.bg0[3]) * f, 1)
            love.graphics.rectangle("fill", 0, y, K.W, 4)
        end
        love.graphics.setColor(acc[1], acc[2], acc[3], 0.07)
        love.graphics.circle("fill", 0, 0, 260)
        love.graphics.setColor(acc[1], acc[2], acc[3], 0.04)
        love.graphics.circle("fill", K.W, K.H, 220)
        love.graphics.setColor(1, 1, 1, 0.025)
        for x = 0, K.W, 40 do love.graphics.rectangle("fill", x, 0, 1, K.H) end
        for y = 0, K.H, 40 do love.graphics.rectangle("fill", 0, y, K.W, 1) end
        love.graphics.pop()
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg_canvas, 0, 0)
    if K.fx == "full" then
        local y = (K.t * 40) % (K.H + 80) - 40
        love.graphics.setColor(K.acc[1], K.acc[2], K.acc[3], 0.035)
        love.graphics.rectangle("fill", 0, y, K.W, 36)
    end
end

-- ── header / footer ─────────────────────────────────────────
function K.header(title, sub, right, opts)
    opts = opts or {}
    local m = K.MARGIN
    local acc = opts.accent or K.acc
    local tx = m
    local right_w = right and 154 or 0

    -- A dedicated title rail keeps the subtitle and right-side status capsule
    -- in separate lanes; long names are clipped before they can collide.
    col(K.C.bg1, 0.92)
    love.graphics.rectangle("fill", 0, 0, K.W, K.HEAD_H)
    col(K.C.bg0, 0.52)
    love.graphics.rectangle("fill", 0, K.HEAD_H - 5, K.W, 5)

    if opts.icon then
        local cx, cy = m + 20, 34
        col(acc, 0.14); love.graphics.circle("fill", cx, cy, 20)
        col(acc, 0.72); love.graphics.setLineWidth(1.4)
        love.graphics.circle("line", cx, cy, 20)
        love.graphics.setLineWidth(1)
        K.draw_tool_icon(opts.icon, cx, cy, 21, acc, 1)
        tx = m + 48
    end

    local max_title = K.W - m - tx - (right_w > 0 and right_w + 14 or 0)
    max_title = math.max(90, max_title)
    K.text("title", K.clip("title", title, max_title), tx, 10, K.C.text)
    if sub and sub ~= "" then
        K.text("small", K.clip("small", sub, math.max(80, max_title)),
            tx, 43, K.C.dim)
    end

    if right then
        local rx = K.W - m - right_w
        col(acc, 0.11); love.graphics.rectangle("fill", rx, 23, right_w, 29, 7, 7)
        col(acc, 0.55); love.graphics.rectangle("line", rx, 23, right_w, 29, 7, 7)
        K.text("mono", K.clip("mono", right, right_w - 16),
            rx + 8, 31, K.C.text, 0.95, right_w - 16, "right")
    end

    col(K.C.line, 0.55)
    love.graphics.rectangle("fill", m, K.HEAD_H - 2, K.W - m * 2, 1)
    col(acc, 1)
    love.graphics.rectangle("fill", m, K.HEAD_H - 3, 58, 3, 1.5, 1.5)
end

local FACE_KEYS = {
    A = { color = { 0.91, 0.20, 0.27 }, ink = { 1, 1, 1 } },
    B = { color = { 0.97, 0.75, 0.16 }, ink = { 0.13, 0.12, 0.08 } },
    X = { color = { 0.20, 0.48, 0.96 }, ink = { 1, 1, 1 } },
    Y = { color = { 0.20, 0.70, 0.39 }, ink = { 0.04, 0.10, 0.06 } },
}
local function footer_key_label(key)
    return tostring(key or ""):upper():gsub("%s+", "+")
end
local function footer_key_width(key)
    local face = FACE_KEYS[tostring(key or ""):upper()]
    if face then return 19 end
    local label = footer_key_label(key)
    return math.max(25, math.min(52, K.width("key", label) + 10))
end
local function draw_footer_key(key, x, cy)
    key = tostring(key or ""):upper()
    local face = FACE_KEYS[key]
    if face then
        local r = 8.5
        col({ 0, 0, 0 }, 0.45); love.graphics.circle("fill", x + r + 1, cy + 1, r + 1)
        col(face.color, 1); love.graphics.circle("fill", x + r, cy, r)
        col({ 1, 1, 1 }, 0.38); love.graphics.setLineWidth(1)
        love.graphics.circle("line", x + r, cy, r - 0.5)
        K.text("key", key, x, cy - 6.5, face.ink, 1, 18, "center")
        return 19
    end

    local label = footer_key_label(key)
    local w = footer_key_width(key)
    local h = 18
    local dark = (label == "START" or label == "SELECT" or label == "D-PAD")
    local fill = dark and { 0.17, 0.20, 0.28 } or { 0.38, 0.43, 0.54 }
    local edge = dark and { 0.35, 0.40, 0.53 } or { 0.62, 0.68, 0.79 }
    col({ 0, 0, 0 }, 0.42); love.graphics.rectangle("fill", x + 1, cy - h / 2 + 2, w, h, 4, 4)
    col(fill, 1); love.graphics.rectangle("fill", x, cy - h / 2, w, h, 4, 4)
    col(edge, 0.95); love.graphics.rectangle("line", x, cy - h / 2, w, h, 4, 4)
    if label == "D-PAD" then
        local cx = x + w / 2
        col({ 0.88, 0.91, 0.98 }, 0.95)
        love.graphics.rectangle("fill", cx - 2, cy - 6, 4, 12, 1, 1)
        love.graphics.rectangle("fill", cx - 6, cy - 2, 12, 4, 1, 1)
    else
        K.text("key", label, x + 2, cy - 6.5, { 0.96, 0.97, 1 },
            1, w - 4, "center")
    end
    return w
end

-- items: { {key="A", label="Play"}, ... }
function K.footer(items)
    local y = K.H - K.FOOT_H
    col({ 0.025, 0.030, 0.055 }, 0.96)
    love.graphics.rectangle("fill", 0, y, K.W, K.FOOT_H)
    col(K.C.line, 0.65); love.graphics.rectangle("fill", 0, y, K.W, 1)
    local small = K.font("small")
    local gap = 12
    local total = 0
    local records = {}
    for _, item in ipairs(items or {}) do
        local kw = footer_key_width(item.key)
        local label = tostring(item.label or "")
        local lw = small:getWidth(label)
        records[#records + 1] = { key = item.key, label = label, kw = kw, lw = lw }
        total = total + kw + 6 + lw
    end
    local available = K.W - K.MARGIN * 2
    if #records > 1 then gap = math.min(12, math.max(4, (available - total) / (#records - 1))) end
    if total + gap * math.max(0, #records - 1) > available then
        local each = math.max(22, (available - gap * math.max(0, #records - 1)) / #records - 28)
        total = 0
        for _, item in ipairs(records) do
            item.label = K.clip("small", item.label, each)
            item.lw = small:getWidth(item.label)
            total = total + item.kw + 6 + item.lw
        end
        if #records > 1 then gap = math.max(3, (available - total) / (#records - 1)) end
    end
    local x = K.MARGIN
    for i, item in ipairs(records) do
        local cy = y + K.FOOT_H / 2
        local used = draw_footer_key(item.key, x, cy)
        love.graphics.setFont(small); col(K.C.dim, 1)
        love.graphics.print(item.label, x + used + 6, cy - small:getHeight() / 2)
        x = x + used + 6 + item.lw + gap
    end
end

-- ── scrolling list ──────────────────────────────────────────
local List = {}
List.__index = List
K.List = function(x, y, w, h, ih) return setmetatable({
    x = x, y = y, w = w, h = h, ih = ih or 40,
    items = {}, heights = {}, cumulative = { 0 },
    sel = 1, scroll = 0, target = 0, fy = 0,
}, List) end

function List:_recalc()
    self.heights = {}
    self.cumulative = { 0 }
    for i, it in ipairs(self.items) do
        local h = (it._h) or self.ih
        self.heights[i] = h
        self.cumulative[i + 1] = self.cumulative[i] + h
    end
end

function List:set(items, keep)
    self.items = items or {}
    self:_recalc()
    if not keep then self.sel = 1; self.scroll = 0 end
    self.sel = math.max(1, math.min(self.sel, math.max(1, #self.items)))
    self:_aim(true)
end

function List:cur() return self.items[self.sel] end

function List:_aim(snap)
    local total = self.cumulative[#self.items + 1] or 0
    local max = math.max(0, total - self.h)
    local top = self.cumulative[self.sel] or 0
    local h = self.heights[self.sel] or self.ih
    local target = top - (self.h - h) / 2
    self.target = math.max(0, math.min(max, target))
    if snap then
        self.scroll = self.target
        self.fy = top
    end
end

function List:move(d)
    local n = #self.items
    if n == 0 then return false end
    local i = self.sel
    for _ = 1, n do
        i = i + d
        if i < 1 or i > n then return false end
        if not self.items[i].skip then
            self.sel = i; self:_aim(); return true
        end
    end
    return false
end

function List:page(d)
    local step = math.max(1, math.floor(self.h / self.ih) - 1)
    local old = self.sel
    self.sel = math.max(1, math.min(#self.items, self.sel + d * step))
    self:_aim()
    return self.sel ~= old
end

function List:update(dt)
    self.scroll = self.scroll + (self.target - self.scroll) * (1 - math.exp(-dt * 16))
    if math.abs(self.target - self.scroll) < 0.3 then self.scroll = self.target end
    local want = self.cumulative[self.sel] or 0
    self.fy = self.fy + (want - self.fy) * (1 - math.exp(-dt * 22))
    if math.abs(want - self.fy) < 0.3 then self.fy = want end
end

function List:draw(fn)
    -- prima riga visibile
    local first = 1
    for i = 1, #self.items do
        if (self.cumulative[i + 1] or 0) > self.scroll then first = i; break end
    end
    if first < 1 then first = 1 end
    -- ultima riga visibile
    local last = #self.items
    for i = first, #self.items do
        if (self.cumulative[i] or 0) >= self.scroll + self.h then last = i - 1; break end
    end
    if last < first then last = first end

    love.graphics.setScissor(self.x - 6, self.y, self.w + 12, self.h)
    local cur = self.items[self.sel]
    if cur and not cur.skip and self.sel >= first and self.sel <= last then
        local top = (self.cumulative[self.sel] or 0)
        local h = self.heights[self.sel] or self.ih
        K.panel(self.x, self.y + top - self.scroll + 2, self.w, h - 4,
            { focus = true, cut = 6, accent = self.accent })
    end
    K._slide = true
    for i = first, last do
        local h = self.heights[i] or self.ih
        local top = self.cumulative[i] or 0
        local y = self.y + top - self.scroll
        fn(self.items[i], self.x, y, self.w, h, i == self.sel, i)
    end
    K._slide = false
    love.graphics.setScissor()

    local total = self.cumulative[#self.items + 1] or 0
    if total > self.h then
        local track_h = math.max(18, self.h * self.h / total)
        local ty = self.y + (self.h - track_h) * (self.scroll / (total - self.h))
        K.color(K.C.line, 0.6)
        love.graphics.rectangle("fill", self.x + self.w + 8, self.y, 3, self.h, 1, 1)
        K.color(K.acc, 0.9)
        love.graphics.rectangle("fill", self.x + self.w + 8, ty, 3, track_h, 1, 1)
    end
end
-- word-wrapped paragraph; returns height used
function K.para(kind, str, x, y, w, c, a)
    local f = K.font(kind)
    love.graphics.setFont(f)
    col(c or K.C.dim, a)
    local _, lines = f:getWrap(str, w)
    love.graphics.printf(str, x, y, w, "left")
    return #lines * f:getHeight()
end

-- tiny vector glyphs (no dependency on font coverage)
-- Fix: la stella e' concava, e polygon("fill") riempie solo poligoni convessi
-- (si vedevano triangoli mancanti/sbavature). Ventaglio dal centro: corretto
-- per qualsiasi forma "a stella".
function K.star(cx, cy, r, c, a)
    local pts = { cx, cy }
    for i = 0, 10 do
        local ang = -math.pi / 2 + i * math.pi / 5
        local rr = (i % 2 == 0) and r or r * 0.45
        pts[#pts + 1] = cx + math.cos(ang) * rr
        pts[#pts + 1] = cy + math.sin(ang) * rr
    end
    col(c, a); love.graphics.polygon("fill", pts)
end
function K.bolt(cx, cy, h, c, a)
    local w = h * 0.55
    col(c, a)
    love.graphics.polygon("fill", cx + w * 0.15, cy - h / 2, cx - w / 2, cy + h * 0.08, cx - w * 0.02, cy + h * 0.08,
                          cx - w * 0.15, cy + h / 2, cx + w / 2, cy - h * 0.1, cx + w * 0.02, cy - h * 0.1)
end



-- ── sprite sheet loader (grid cols x rows) ────────────────
local _sprite_cache = {}
function K.load_sprite(path, cols, rows)
    local key = path .. "|" .. cols .. "x" .. rows
    if _sprite_cache[key] ~= nil then return _sprite_cache[key] or nil end
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then _sprite_cache[key] = false; return nil end
    img:setFilter("linear", "linear")
    local iw, ih = img:getDimensions()
    local fw, fh = iw / cols, ih / rows
    local quads, n = {}, 0
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            n = n + 1
            quads[n] = love.graphics.newQuad(c * fw, r * fh, fw, fh, iw, ih)
        end
    end
    local s = { img = img, quads = quads, frames = n, fw = fw, fh = fh, iw = iw, ih = ih }
    _sprite_cache[key] = s
    return s
end

function K.draw_sprite(s, cx, cy, size, frame, fps, t)
    if not s then return false end
    local f
    if t then f = math.floor(t * (fps or 12)) % s.frames
    else     f = (frame or 0) % s.frames end
    local sc = size / math.max(s.fw, s.fh)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(s.img, s.quads[f + 1],
                       cx - s.fw * sc / 2, cy - s.fh * sc / 2, 0, sc, sc)
    return true
end

-- ── workshop animated background ──────────────────────────
function K.bg_workshop(t)
    -- gradient blue/indigo
    local c1, c2 = { 0.025, 0.045, 0.10 }, { 0.075, 0.115, 0.22 }
    for i = 0, 15 do
        local k = i / 15
        love.graphics.setColor(
            c1[1] + (c2[1] - c1[1]) * k,
            c1[2] + (c2[2] - c1[2]) * k,
            c1[3] + (c2[3] - c1[3]) * k, 1)
        love.graphics.rectangle("fill", 0, i * K.H / 16, K.W, K.H / 16 + 1)
    end
    local acc = K.acc or K.ACC.workshop
    -- scrolled grid
    local off = (t * 18) % 40
    love.graphics.setColor(acc[1], acc[2], acc[3], 0.07)
    for x = -off, K.W, 40 do love.graphics.rectangle("fill", x, 0, 1, K.H) end
    for y = -off, K.H, 40 do love.graphics.rectangle("fill", 0, y, K.W, 1) end
    -- gears (slowly rotating)
    local function gear(cx, cy, r, teeth, ang, a)
        love.graphics.setColor(acc[1], acc[2], acc[3], a)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", cx, cy, r)
        for i = 0, teeth - 1 do
            local th = ang + i * math.pi * 2 / teeth
            love.graphics.line(
                cx + math.cos(th) * r, cy + math.sin(th) * r,
                cx + math.cos(th) * (r * 1.28), cy + math.sin(th) * (r * 1.28))
        end
        love.graphics.circle("line", cx, cy, r * 0.36)
        love.graphics.setLineWidth(1)
    end
    gear(K.W - 90, 110, 44, 12, t * 0.25, 0.14)
    gear(K.W - 42, 210, 26, 8, -t * 0.42, 0.11)
    gear(76, K.H - 90, 56, 14, t * 0.16, 0.09)
    -- scanline (subtle)
    love.graphics.setColor(1, 1, 1, 0.02)
    for y = 0, K.H, 3 do love.graphics.rectangle("fill", 0, y, K.W, 1) end
end



-- ── tool icons (folder, rescan, profile, hotkeys, mods, cheats) ──
function K.draw_tool_icon(name, cx, cy, size, color, a)
    a = a or 1
    K.color(color or K.C.text, a)
    love.graphics.setLineWidth(1.7)
    local s = size / 2
    if name == "folder" then
        love.graphics.rectangle("line", cx - s*0.9, cy - s*0.4, s*1.8, s*1.1, 3, 3)
        love.graphics.rectangle("line", cx - s*0.9, cy - s*0.75, s*0.6, s*0.35, 2, 2)
    elseif name == "rescan" then
        love.graphics.arc("line", "open", cx, cy, s*0.9, -math.pi*0.85, math.pi*0.85, 16)
        love.graphics.polygon("fill", cx + s*0.55, cy - s*1.05, cx + s*1.05, cy - s*0.35, cx + s*0.30, cy - s*0.55)
    elseif name == "profile" then
        love.graphics.circle("line", cx, cy - s*0.35, s*0.45)
        love.graphics.arc("line", "open", cx, cy + s*0.9, s*0.85, math.pi, 2*math.pi, 18)
    elseif name == "gamepad" then
        love.graphics.polygon("line", cx - s*0.95, cy - s*0.35, cx + s*0.95, cy - s*0.35,
            cx + s*1.05, cy + s*0.5, cx + s*0.55, cy + s*0.65, cx + s*0.25, cy + s*0.2,
            cx - s*0.25, cy + s*0.2, cx - s*0.55, cy + s*0.65, cx - s*1.05, cy + s*0.5)
        love.graphics.line(cx - s*0.6, cy - s*0.05, cx - s*0.6, cy + s*0.15)
        love.graphics.line(cx - s*0.75, cy + s*0.05, cx - s*0.45, cy + s*0.05)
        love.graphics.circle("fill", cx + s*0.55, cy - s*0.05, 1.6)
        love.graphics.circle("fill", cx + s*0.78, cy + s*0.1, 1.6)
    elseif name == "hotkeys" then
        love.graphics.rectangle("line", cx - s*0.9, cy - s*0.55, s*1.8, s*1.1, 3, 3)
        for i = -1, 1 do love.graphics.circle("fill", cx + i*s*0.5, cy - s*0.1, 1.4) end
        love.graphics.line(cx - s*0.6, cy + s*0.35, cx + s*0.6, cy + s*0.35)
    elseif name == "mods" then
        love.graphics.polygon("line", cx, cy - s*0.85, cx + s*0.75, cy - s*0.42,
            cx + s*0.75, cy + s*0.42, cx, cy + s*0.85,
            cx - s*0.75, cy + s*0.42, cx - s*0.75, cy - s*0.42)
        love.graphics.line(cx - s*0.75, cy - s*0.42, cx, cy, cx + s*0.75, cy - s*0.42)
        love.graphics.line(cx, cy, cx, cy + s*0.85)
    elseif name == "cheats" then
        local pts = {}
        for i = 0, 9 do
            local ang = -math.pi/2 + i * math.pi/5
            local rr = (i % 2 == 0) and s*0.9 or s*0.42
            pts[#pts+1] = cx + math.cos(ang) * rr
            pts[#pts+1] = cy + math.sin(ang) * rr
        end
        love.graphics.polygon("line", pts)
    elseif name == "tier" then
        love.graphics.arc("line", "open", cx, cy + s*0.4, s*0.9, -math.pi*0.8, -math.pi*0.2, 16)
        love.graphics.line(cx, cy + s*0.4, cx + math.cos(-math.pi*0.45) * s*0.7, cy + s*0.4 + math.sin(-math.pi*0.45) * s*0.7)
        love.graphics.circle("fill", cx, cy + s*0.4, 1.6)
    elseif name == "screen" then
        love.graphics.rectangle("line", cx - s*0.9, cy - s*0.7, s*1.8, s*1.3, 2, 2)
        love.graphics.line(cx, cy + s*0.6, cx, cy + s*0.9)
        love.graphics.line(cx - s*0.5, cy + s*0.9, cx + s*0.5, cy + s*0.9)
    elseif name == "chart" then
        love.graphics.rectangle("fill", cx - s*0.9, cy + s*0.1, s*0.5, s*0.9)
        love.graphics.rectangle("fill", cx - s*0.25, cy - s*0.4, s*0.5, s*1.4)
        love.graphics.rectangle("fill", cx + s*0.4, cy - s*0.9, s*0.5, s*1.9)
    elseif name == "gear" then
        love.graphics.circle("line", cx, cy, s*0.55)
        love.graphics.circle("fill", cx, cy, s*0.18)
        for i = 0, 7 do
            local ang = i * math.pi / 4
            love.graphics.line(cx + math.cos(ang)*s*0.55, cy + math.sin(ang)*s*0.55,
                               cx + math.cos(ang)*s*1.0, cy + math.sin(ang)*s*1.0)
        end
    elseif name == "trash" then
        love.graphics.line(cx - s*0.85, cy - s*0.55, cx + s*0.85, cy - s*0.55)
        love.graphics.line(cx - s*0.28, cy - s*0.55, cx - s*0.28, cy - s*0.9,
            cx + s*0.28, cy - s*0.9, cx + s*0.28, cy - s*0.55)
        love.graphics.rectangle("line", cx - s*0.65, cy - s*0.55, s*1.3, s*1.5, 2, 2)
    elseif name == "boost" then
        love.graphics.polygon("fill", cx + s*0.3, cy - s*0.9, cx - s*0.5, cy + s*0.1,
            cx + s*0.2, cy + s*0.1, cx - s*0.3, cy + s*0.9,
            cx + s*0.5, cy - s*0.1, cx - s*0.2, cy - s*0.1)
    elseif name == "info" then
        love.graphics.circle("line", cx, cy, s*0.85)
        love.graphics.circle("fill", cx, cy - s*0.35, 1.8)
        love.graphics.line(cx, cy - s*0.05, cx, cy + s*0.55)
    elseif name == "list" then
        for i = -1, 1 do
            love.graphics.circle("fill", cx - s*0.6, cy + i*s*0.55, 1.6)
            love.graphics.line(cx - s*0.3, cy + i*s*0.55, cx + s*0.8, cy + i*s*0.55)
        end
    elseif name == "play" then
        love.graphics.polygon("fill", cx - s*0.5, cy - s*0.7, cx - s*0.5, cy + s*0.7, cx + s*0.8, cy)
    elseif name == "bomb" then
        love.graphics.circle("line", cx - s*0.1, cy + s*0.15, s*0.6)
        love.graphics.line(cx + s*0.1, cy - s*0.45, cx + s*0.4, cy - s*0.7)
        love.graphics.line(cx + s*0.35, cy - s*0.9, cx + s*0.55, cy - s*0.7)
        love.graphics.circle("fill", cx + s*0.45, cy - s*0.9, 1.5)
    elseif name == "file" then
        -- icona "CD/disco documento": cerchio + etichetta con righe
        love.graphics.circle("line", cx, cy, s*0.9)
        love.graphics.circle("line", cx, cy, s*0.28)
        love.graphics.setLineWidth(1)
        love.graphics.line(cx - s*0.65, cy - s*0.65, cx - s*0.20, cy - s*0.20)
        love.graphics.line(cx + s*0.65, cy + s*0.65, cx + s*0.20, cy + s*0.20)
    else
        -- fallback: quadratino con iniziale, così un'icona mancante è visibile
        local initial = tostring(name or "?"):sub(1,1):upper()
        love.graphics.rectangle("line", cx - s*0.7, cy - s*0.7, s*1.4, s*1.4, 3, 3)
        K.text("key", initial, cx - 5, cy - 8, color or K.C.text)
    end
    love.graphics.setLineWidth(1)
end



-- ── gauge (tachimetro) ────────────────────────────────────
function K.gauge(cx, cy, r, frac, color, t, opts)
    opts = opts or {}
    t = t or 0
    -- arco rainbow: da -170° a -10° passando per -90° (up)
    -- 160° di sweep, gauge a "tachimetro"
    local a0 = -math.pi * 170 / 180
    local a1 = -math.pi * 10 / 180
    local max_zone = opts.max_zone or 0.72
    local ease_power = opts.ease or 1.35
    local function pos(f)
        f = math.max(0, math.min(1, f))
        return f ^ ease_power
    end

    -- track di fondo
    K.color(K.C.surf2, 1)
    love.graphics.setLineWidth(4)
    love.graphics.arc("line", "open", cx, cy, r, a0, a1, 40)

    -- zona MAX rossa (sulla scala non-lineare)
    local max_start = pos(max_zone)
    K.color({ 0.90, 0.25, 0.25 }, 0.60)
    love.graphics.setLineWidth(4)
    love.graphics.arc("line", "open", cx, cy, r,
                      a0 + (a1 - a0) * max_start, a1, 20)

    -- valore riempito fino a p
    local p = pos(frac or 0)
    if p > 0.005 then
        K.color(color, 1)
        love.graphics.setLineWidth(5)
        love.graphics.arc("line", "open", cx, cy, r, a0, a0 + (a1 - a0) * p, 40)
    end

    -- tacche
    love.graphics.setLineWidth(1)
    K.color(K.C.line, 0.85)
    for i = 0, 8 do
        local aa = a0 + (a1 - a0) * (i / 8)
        love.graphics.line(
            cx + math.cos(aa) * (r - 3), cy + math.sin(aa) * (r - 3),
            cx + math.cos(aa) * (r + 2), cy + math.sin(aa) * (r + 2))
    end

    -- lancetta: angolo base + wobble visibile
    local base_ang = a0 + (a1 - a0) * p
    local in_max = (p >= max_start)
    -- wobble in RADIANTI (piu' grande = visibile)
    local wobble
    if in_max then
        -- MAX: trema continuamente, frequenza alta, ampiezza grande
        wobble = math.sin(t * 26) * 0.30 + math.sin(t * 41) * 0.10
    else
        -- idle: oscillazione lenta e piccola
        wobble = math.sin(t * 4.2) * 0.12
    end
    local an = base_ang + wobble

    -- scia luminosa dietro la lancetta
    local sweep = a1 - a0
    for i = 1, 5 do
        local trail_ang = an - sweep * 0.018 * i
        K.color(color, 0.30 - i * 0.05)
        love.graphics.setLineWidth(3.5 - i * 0.5)
        love.graphics.line(
            cx + math.cos(trail_ang) * (r * 0.28),
            cy + math.sin(trail_ang) * (r * 0.28),
            cx + math.cos(trail_ang) * (r - 2),
            cy + math.sin(trail_ang) * (r - 2))
    end

    -- lancetta bianca principale
    K.color({ 1, 1, 1 }, 1)
    love.graphics.setLineWidth(2.2)
    love.graphics.line(cx, cy, cx + math.cos(an) * (r - 2), cy + math.sin(an) * (r - 2))

    -- puntino colorato all'estremita'
    K.color(color, 1)
    love.graphics.circle("fill",
        cx + math.cos(an) * (r - 4),
        cy + math.sin(an) * (r - 4), 2.6)

    -- perno centrale
    K.color({ 1, 1, 1 }, 1)
    love.graphics.circle("fill", cx, cy, 2.8)
    K.color(color, 1)
    love.graphics.circle("fill", cx, cy, 1.3)

    love.graphics.setLineWidth(1)
end


-- ── disco rotante 3D (prospettiva) ────────────────────────
function K.disc(cx, cy, r, texture, t, color)
    color = color or { 0.35, 0.55, 0.95 }
    local ang = (t or 0) * 1.4
    local cos_a = math.cos(ang)
    local sx = math.abs(cos_a)
    local face = cos_a >= 0

    -- ombra a terra
    K.color({ 0, 0, 0 }, 0.35)
    love.graphics.ellipse("fill", cx, cy + r * 0.88, r * 0.55, r * 0.10)

    if sx > 0.18 then
        -- bordo scuro (contorno del disco)
        K.color({ 0.06, 0.07, 0.10 }, 1)
        love.graphics.ellipse("fill", cx, cy, r * sx + 2, r + 2)
        -- faccia colorata base
        K.color(color, 1)
        love.graphics.ellipse("fill", cx, cy, r * sx, r)

        -- texture della cover del disco (se disponibile)
        if texture then
            love.graphics.setColor(1, 1, 1, 1)
            local iw, ih = texture:getDimensions()
            local sc = math.min((r * sx * 2) / iw, (r * 2) / ih)
            love.graphics.draw(texture, cx - (iw * sc) / 2, cy - (ih * sc) / 2, 0, sc, sc)
        end

        -- faccia posteriore (piu' scura)
        if not face then
            K.color({ 0, 0, 0 }, 0.45)
            love.graphics.ellipse("fill", cx, cy, r * sx, r)
        end

        -- foro centrale
        K.color({ 0.06, 0.07, 0.10 }, 1)
        love.graphics.ellipse("fill", cx, cy, math.max(1, r * sx * 0.10), r * 0.10)

        -- riflesso (diagonale)
        K.color({ 1, 1, 1 }, 0.20)
        love.graphics.ellipse("fill", cx - r * sx * 0.35, cy - r * 0.32, r * sx * 0.25, r * 0.32)
    else
        -- di taglio: barra verticale con spessore
        local th = math.max(2, r * 0.10)
        K.color({ 0.06, 0.07, 0.10 }, 1)
        love.graphics.rectangle("fill", cx - th / 2, cy - r, th, r * 2, 1, 1)
        K.color(color, 0.7)
        love.graphics.rectangle("fill", cx - th / 2, cy - r, 1, r * 2)
    end
end

-- ── bandierina regione (pill) ─────────────────────────────
function K.region_flag(region, x, y, w, h)
    region = region or "?"
    local c, label
    if region == "NTSC-U" or region == "US" or region == "E" then
        c, label = { 0.22, 0.38, 0.75 }, "US"
    elseif region == "PAL" or region == "EU" or region == "P" then
        c, label = { 0.18, 0.32, 0.68 }, "PAL"
    elseif region == "NTSC-J" or region == "JP" or region == "J" then
        c, label = { 0.85, 0.22, 0.22 }, "JP"
    elseif region == "NTSC-K" or region == "KR" or region == "K" then
        c, label = { 0.85, 0.22, 0.22 }, "KR"
    else
        c, label = { 0.5, 0.5, 0.55 }, tostring(region)
    end
    K.color(c, 0.85)
    love.graphics.rectangle("fill", x, y, w, h, h / 2, h / 2)
    K.color(c, 1)
    love.graphics.setLineWidth(1.4)
    love.graphics.rectangle("line", x, y, w, h, h / 2, h / 2)
    love.graphics.setLineWidth(1)
    K.text("key", label, x, y + h / 2 - 8, { 1, 1, 1 }, 1, w, "center")
end

-- ── targhetta metallica con game ID ───────────────────────
function K.id_plate(id, x, y, w, h)
    -- corpo metallico
    K.color({ 0.15, 0.16, 0.20 }, 1)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    -- bordo
    K.color({ 0.35, 0.37, 0.42 }, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, w, h, 3, 3)
    love.graphics.setLineWidth(1)
    -- rivetti angoli
    K.color({ 0.50, 0.52, 0.58 }, 1)
    for dx = 4, w - 4, w - 8 do
        for dy = 4, h - 4, h - 8 do
            love.graphics.circle("fill", x + dx, y + dy, 1.5)
        end
    end
    -- testo mono
    K.text("mono", K.clip("mono", tostring(id or "?"), w - 20), x + 10, y + h / 2 - 8, K.C.text)
end

function K.update(dt) K.t = K.t + dt end


-- ── category icon (per il pannello settings) ──────────────
function K.draw_category_icon(name, cx, cy, size, col, a)
    a = a or 1
    K.color(col, a)
    love.graphics.setLineWidth(1.8)
    local s = size / 2
    if name == "list" then
        for i = -1, 1 do
            love.graphics.circle("fill", cx - s*0.6, cy + i*s*0.55, 2)
            love.graphics.line(cx - s*0.3, cy + i*s*0.55, cx + s*0.8, cy + i*s*0.55)
        end
    elseif name == "library" then
        love.graphics.rectangle("line", cx - s*0.6, cy - s*0.6, s*0.6, s*1.2, 2, 2)
        love.graphics.rectangle("line", cx - s*0.1, cy - s*0.5, s*0.6, s*1.1, 2, 2)
        love.graphics.rectangle("line", cx + s*0.4, cy - s*0.7, s*0.6, s*1.3, 2, 2)
    elseif name == "wrench" then
        love.graphics.line(cx - s*0.7, cy + s*0.7, cx + s*0.3, cy - s*0.3)
        love.graphics.circle("line", cx + s*0.5, cy - s*0.5, s*0.4)
    elseif name == "settings" then
        love.graphics.circle("line", cx, cy, s*0.6)
        love.graphics.circle("fill", cx, cy, s*0.2)
        for i = 0, 7 do
            local ang = i * math.pi / 4
            love.graphics.line(cx + math.cos(ang)*s*0.6, cy + math.sin(ang)*s*0.6,
                               cx + math.cos(ang)*s*1.0, cy + math.sin(ang)*s*1.0)
        end
    elseif name == "info" then
        love.graphics.circle("line", cx, cy, s*0.85)
        love.graphics.circle("fill", cx, cy - s*0.35, 2)
        love.graphics.line(cx, cy - s*0.05, cx, cy + s*0.55)
    elseif name == "file" then
        love.graphics.rectangle("line", cx - s*0.75, cy - s*0.95, s*1.5, s*1.9, 2, 2)
        love.graphics.line(cx - s*0.5, cy - s*0.55, cx + s*0.5, cy - s*0.55)
        love.graphics.line(cx - s*0.5, cy - s*0.2, cx + s*0.5, cy - s*0.2)
        love.graphics.line(cx - s*0.5, cy + s*0.15, cx + s*0.1, cy + s*0.15)
    elseif name == "play" then
        love.graphics.polygon("fill", cx - s*0.5, cy - s*0.7, cx - s*0.5, cy + s*0.7, cx + s*0.8, cy)
    elseif name == "bomb" then
        love.graphics.circle("line", cx - s*0.1, cy + s*0.15, s*0.6)
        love.graphics.line(cx + s*0.1, cy - s*0.45, cx + s*0.4, cy - s*0.7)
        love.graphics.line(cx + s*0.35, cy - s*0.9, cx + s*0.55, cy - s*0.7)
        love.graphics.circle("fill", cx + s*0.45, cy - s*0.9, 1.5)
    end
    love.graphics.setLineWidth(1)
end

return K
