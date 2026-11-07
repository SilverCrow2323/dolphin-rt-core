-- frontend/ui/bg.lua
-- Animated per-screen backgrounds.
-- Theme-aware: Wii uses light/clean palette, GC & RtCore use dark.
--
-- ── Performance notes ───────────────────────────────────────
--   * draw_matrix used to call math.random() once per character per
--     frame (~550 calls/frame). Now a pool of pre-generated characters
--     is rotated on a 10 Hz tick instead.
--   * draw_book caches its paper dots once per (w, h). The dot layout
--     is built with a module-local LCG so the global math.random state
--     is never perturbed by a background redraw.
--   * draw_hexgrid reuses a single `pts` table for the polygon points
--     instead of allocating a fresh table per hexagon per frame.
--   * draw_cyberpunk now uses the same module-local LCG family for its
--     occasional glitch line, so it can't perturb the global RNG that
--     screens (menu glitch, matrix) rely on.
--
-- ── API ─────────────────────────────────────────────────────
--   BG.set_particles_enabled(v)
--   BG.particles_enabled()
--   BG.draw_nexus(w, h, dt, col)
--   BG.draw_cockpit(w, h, dt, col)
--   BG.draw_deadspace(w, h, dt, col)
--   BG.draw_cyberpunk(w, h, dt, col)
--   BG.draw_matrix(w, h, dt, col)
--   BG.draw_hexgrid(w, h, dt, col)
--   BG.draw_book(w, h, dt, col)

local D  = require("ui.draw")
local BG = {}

-- ── Particles toggle ────────────────────────────────────────
local _particles_enabled = true
function BG.set_particles_enabled(v) _particles_enabled = (v ~= false) end
function BG.particles_enabled() return _particles_enabled end

-- ── Theme check ─────────────────────────────────────────────
local function is_wii()
    local ok, S = pcall(require, "state")
    return ok and S and S.theme_name == "wii"
end

-- ── Module-local RNG ────────────────────────────────────────
-- A cheap LCG, used by draw_book and draw_cyberpunk so that per-frame
-- background redraws never perturb the global math.random() state.
-- Two instances are needed: one per background, so their streams
-- don't interleave (the glitch line and the book dots must look
-- independent, not driven by the same sequence).
local function make_lcg(seed)
    local s = seed or 1
    return function()
        s = (s * 1103515245 + 12345) % 2147483648
        return s / 2147483648
    end
end

-- ── Particles helpers (shared) ──────────────────────────────
-- Built once per screen-resize (or first draw). Uses math.random for
-- the INITIAL layout only: a one-shot call at init time, not a per-
-- frame call, so perturbing the global RNG here is harmless.
local function make_particles(n, w, h)
    local p = {}
    for i = 1, n do
        p[i] = {
            x = math.random() * w, y = math.random() * h,
            vx = (math.random() - 0.5) * 12,
            vy = (math.random() - 0.5) * 12,
            r = 0.6 + math.random() * 1.4,
            a = 0.1 + math.random() * 0.35,
        }
    end
    return p
end

local function update_particles(p, dt, w, h)
    for _, q in ipairs(p) do
        q.x = q.x + q.vx * dt
        q.y = q.y + q.vy * dt
        if q.x < 0 then q.x = w elseif q.x > w then q.x = 0 end
        if q.y < 0 then q.y = h elseif q.y > h then q.y = 0 end
    end
end

local function draw_particles(p, col, alpha_scale)
    alpha_scale = alpha_scale or 1
    for _, q in ipairs(p) do
        love.graphics.setColor(col[1], col[2], col[3], q.a * alpha_scale)
        love.graphics.circle("fill", q.x, q.y, q.r)
    end
end

-- ═══════════════════════════════════════════════════════════
-- NEXUS (main menu)
-- ═══════════════════════════════════════════════════════════
local nexus = { t = 0, p = nil }
function BG.draw_nexus(w, h, dt, col)
    nexus.t = nexus.t + dt
    local wii = is_wii()

    if wii then
        love.graphics.clear(0.94, 0.96, 0.99)
        love.graphics.setColor(0.85, 0.92, 0.98, 0.35)
        love.graphics.circle("fill", w/2, -h/4, h)
        love.graphics.setColor(0.75, 0.82, 0.90, 0.35)
        love.graphics.setLineWidth(1)
        local off = (nexus.t * 20) % 40
        for x = -40 + off, w, 40 do love.graphics.line(x, 0, x, h) end
        for y = -40 + off, h, 40 do love.graphics.line(0, y, w, y) end

        if _particles_enabled then
            if not nexus.p then nexus.p = make_particles(30, w, h) end
            update_particles(nexus.p, dt, w, h)
            for i, a in ipairs(nexus.p) do
                for j = i + 1, #nexus.p do
                    local b = nexus.p[j]
                    local dx, dy = a.x - b.x, a.y - b.y
                    local d = math.sqrt(dx*dx + dy*dy)
                    if d < 90 then
                        love.graphics.setColor(0.10, 0.45, 0.72,
                            0.18 * (1 - d / 90))
                        love.graphics.line(a.x, a.y, b.x, b.y)
                    end
                end
            end
            draw_particles(nexus.p, {0.10, 0.55, 0.85}, 0.7)
        end
        for i = 1, 4 do
            love.graphics.setColor(0.55, 0.68, 0.82, 0.04 * i)
            love.graphics.rectangle("line", -i*4, -i*4, w + i*8, h + i*8)
        end
        return
    end

    love.graphics.clear(0.04, 0.05, 0.08)
    love.graphics.setColor(col[1], col[2], col[3], 0.06)
    love.graphics.setLineWidth(1)
    local off = (nexus.t * 30) % 40
    for x = -40 + off, w, 40 do love.graphics.line(x, 0, x, h) end
    for y = -40 + off, h, 40 do love.graphics.line(0, y, w, y) end

    if _particles_enabled then
        if not nexus.p then nexus.p = make_particles(40, w, h) end
        update_particles(nexus.p, dt, w, h)
        for i, a in ipairs(nexus.p) do
            for j = i + 1, #nexus.p do
                local b = nexus.p[j]
                local dx, dy = a.x - b.x, a.y - b.y
                local d = math.sqrt(dx*dx + dy*dy)
                if d < 90 then
                    love.graphics.setColor(col[1], col[2], col[3],
                        0.12 * (1 - d / 90))
                    love.graphics.line(a.x, a.y, b.x, b.y)
                end
            end
        end
        draw_particles(nexus.p, col)
    end

    D.scanlines(w, h, 0.04)
    D.vignette(w, h, 0.5)
end

-- ═══════════════════════════════════════════════════════════
-- COCKPIT (library)
-- ═══════════════════════════════════════════════════════════
local cockpit = { t = 0 }
function BG.draw_cockpit(w, h, dt, col)
    cockpit.t = cockpit.t + dt
    local wii = is_wii()

    if wii then
        love.graphics.clear(0.88, 0.93, 0.98)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("fill", 0, 0, w, h * 0.4)
        love.graphics.setColor(0.88, 0.93, 0.98, 0.7)
        love.graphics.rectangle("fill", 0, h * 0.4 - 40, w, 40)

        for y = 100, h - 40, 16 do
            local a = 0.04 + 0.03 * math.sin(cockpit.t * 1.4 + y * 0.05)
            love.graphics.setColor(0.15, 0.55, 0.85, a)
            love.graphics.line(0, y, w, y)
        end

        local rx, ry, rr = w - 90, h - 90, 50
        love.graphics.setColor(0.10, 0.55, 0.85, 0.55)
        love.graphics.setLineWidth(1.2)
        for i = 1, 3 do love.graphics.circle("line", rx, ry, rr * i/3) end
        love.graphics.line(rx - rr, ry, rx + rr, ry)
        love.graphics.line(rx, ry - rr, rx, ry + rr)
        local sweep = (cockpit.t * 1.2) % (math.pi * 2)
        love.graphics.setColor(0.10, 0.65, 0.92, 0.7)
        love.graphics.line(rx, ry,
            rx + math.cos(sweep) * rr, ry + math.sin(sweep) * rr)
        love.graphics.setLineWidth(1)

        D.corner_brackets(0, 0, w, h, {0.35, 0.65, 0.88, 0.5}, 24)
        for i = 1, 4 do
            love.graphics.setColor(0.55, 0.68, 0.82, 0.03 * i)
            love.graphics.rectangle("line", -i*4, -i*4, w + i*8, h + i*8)
        end
        return
    end

    love.graphics.clear(0.03, 0.04, 0.06)
    for y = 100, h - 40, 8 do
        local a = 0.04 + 0.03 * math.sin(cockpit.t * 2 + y * 0.1)
        love.graphics.setColor(col[1], col[2], col[3], a)
        love.graphics.line(0, y, w, y)
    end
    local rx, ry, rr = w - 90, h - 90, 50
    love.graphics.setColor(col[1], col[2], col[3], 0.25)
    for i = 1, 3 do love.graphics.circle("line", rx, ry, rr * i/3) end
    love.graphics.line(rx - rr, ry, rx + rr, ry)
    love.graphics.line(rx, ry - rr, rx, ry + rr)
    local sweep = (cockpit.t * 1.2) % (math.pi * 2)
    love.graphics.setColor(col[1], col[2], col[3], 0.4)
    love.graphics.line(rx, ry,
        rx + math.cos(sweep) * rr, ry + math.sin(sweep) * rr)
    D.corner_brackets(0, 0, w, h, {col[1], col[2], col[3], 0.35}, 24)
    D.vignette(w, h, 0.6)
end

-- ═══════════════════════════════════════════════════════════
-- DEADSPACE (ethostore)
-- ═══════════════════════════════════════════════════════════
local ds = { t = 0 }
function BG.draw_deadspace(w, h, dt, col)
    ds.t = ds.t + dt
    local wii = is_wii()

    if wii then
        love.graphics.clear(0.90, 0.94, 0.98)
        love.graphics.setColor(0.55, 0.70, 0.85, 0.35)
        for x = 0, w, 32 do
            love.graphics.line(x, 0, x, h)
            for y = 0, h, 32 do love.graphics.circle("fill", x, y, 0.9) end
        end
        local p = (ds.t * 0.5) % 1
        love.graphics.setColor(0.10, 0.55, 0.85, 0.55 * (1 - p))
        love.graphics.rectangle("fill", w * p - 1, 0, 2, h)

        for i = 1, 4 do
            love.graphics.setColor(0.55, 0.68, 0.82, 0.03 * i)
            love.graphics.rectangle("line", -i*4, -i*4, w + i*8, h + i*8)
        end
        return
    end

    love.graphics.clear(0.02, 0.03, 0.04)
    love.graphics.setColor(col[1], col[2], col[3], 0.08)
    for x = 0, w, 32 do
        love.graphics.line(x, 0, x, h)
        for y = 0, h, 32 do love.graphics.circle("fill", x, y, 0.8) end
    end
    local p = (ds.t * 0.5) % 1
    love.graphics.setColor(col[1], col[2], col[3], 0.5 * (1 - p))
    love.graphics.line(w * p, 0, w * p, h)
    D.vignette(w, h, 0.7)
end

-- ═══════════════════════════════════════════════════════════
-- CYBERPUNK (workshop, generic)
-- ═══════════════════════════════════════════════════════════
local cp = { t = 0, rng = 1 }
local cp_rand = make_lcg(1)
function BG.draw_cyberpunk(w, h, dt, col)
    cp.t = cp.t + dt
    local wii = is_wii()

    if wii then
        love.graphics.clear(0.92, 0.95, 0.98)
        love.graphics.setColor(0.75, 0.85, 0.94, 0.35)
        for i = -h, w, 24 do
            love.graphics.polygon("fill", i, 0, i + 6, 0,
                i + 6 + h, h, i + h, h)
        end
        love.graphics.setColor(0.00, 0.63, 0.91, 0.55)
        love.graphics.rectangle("fill", 0, 0, w, 3)
        love.graphics.rectangle("fill", 0, h - 3, w, 3)
        if cp_rand() < 0.02 then
            love.graphics.setColor(0.10, 0.55, 0.85, 0.05)
            love.graphics.rectangle("fill", 0, cp_rand() * h, w, 1)
        end
        for i = 1, 4 do
            love.graphics.setColor(0.55, 0.68, 0.82, 0.03 * i)
            love.graphics.rectangle("line", -i*4, -i*4, w + i*8, h + i*8)
        end
        return
    end

    love.graphics.clear(0.06, 0.04, 0.08)
    love.graphics.setColor(0, 0, 0, 0.15)
    for i = -h, w, 16 do
        love.graphics.polygon("fill", i, 0, i + 8, 0, i + 8 + h, h, i + h, h)
    end
    love.graphics.setColor(col[1], col[2], col[3],
        0.06 + 0.03 * math.sin(cp.t * 3))
    love.graphics.rectangle("fill", 0, 0, w, 3)
    love.graphics.rectangle("fill", 0, h - 3, w, 3)
    if cp_rand() < 0.02 then
        love.graphics.setColor(1, 1, 1, 0.04)
        love.graphics.rectangle("fill", 0, cp_rand() * h, w, 1)
    end
    D.vignette(w, h, 0.7)
end

-- ═══════════════════════════════════════════════════════════
-- MATRIX (config editor)
-- ═══════════════════════════════════════════════════════════
-- Optimized: characters come from a pre-generated pool, rotated on a
-- slow tick (10 Hz). The previous version called math.random() per
-- character per frame (~550 calls/frame on this screen).
local matrix = {
    cols = nil, w = 0, h = 0, t = 0,
    pool = nil, tick = 0, tick_t = 0,
}
local _matrix_font = nil

local MATRIX_TICK_INTERVAL = 0.10   -- seconds between character changes

local function build_matrix_pool()
    -- 96 printable ASCII chars, stable per session.
    local pool = {}
    for i = 1, 96 do
        pool[i] = string.char(32 + i)
    end
    return pool
end

function BG.draw_matrix(w, h, dt, col)
    matrix.t = matrix.t + dt
    matrix.tick_t = matrix.tick_t + dt
    if matrix.tick_t >= MATRIX_TICK_INTERVAL then
        matrix.tick_t = 0
        matrix.tick = matrix.tick + 1
    end
    local wii = is_wii()

    if wii then
        love.graphics.clear(0.94, 0.97, 1.00)
        love.graphics.setColor(0.65, 0.78, 0.90, 0.35)
        for x = 0, w, 40 do love.graphics.line(x, 0, x, h) end
        for y = 0, h, 40 do love.graphics.line(0, y, w, y) end
        local p = ((matrix.t * 0.25) % 1)
        love.graphics.setColor(0.10, 0.55, 0.85, 0.15)
        love.graphics.rectangle("fill", w * p - 30, 0, 60, h)
        for i = 1, 4 do
            love.graphics.setColor(0.55, 0.68, 0.82, 0.03 * i)
            love.graphics.rectangle("line", -i*4, -i*4, w + i*8, h + i*8)
        end
        return
    end

    if not matrix.cols or matrix.w ~= w or matrix.h ~= h then
        matrix.w = w; matrix.h = h
        matrix.cols = {}
        local col_w = 12
        for x = 0, w, col_w do
            table.insert(matrix.cols, {
                x = x,
                head = math.random() * h,
                speed = 40 + math.random() * 80,
                len = 6 + math.random() * 12,
                seed = math.random(1, 96),
            })
        end
    end
    if not matrix.pool then
        matrix.pool = build_matrix_pool()
    end

    love.graphics.clear(0.01, 0.02, 0.01)
    if not _matrix_font then
        _matrix_font = love.graphics.newFont(11)
    end
    love.graphics.setFont(_matrix_font)

    local pool = matrix.pool
    local tick = matrix.tick
    local n = #pool

    for _, c in ipairs(matrix.cols) do
        c.head = c.head + c.speed * dt
        if c.head - c.len * 14 > h then c.head = -math.random() * 100 end
        for i = 0, c.len - 1 do
            local y = c.head - i * 14
            if y >= 0 and y <= h then
                local alpha = (1 - i / c.len)
                if i == 0 then
                    love.graphics.setColor(0.85, 1.0, 0.85, 0.95)
                else
                    love.graphics.setColor(col[1], col[2], col[3], alpha * 0.6)
                end
                -- Cheap deterministic "random" char: rotate through pool
                -- using a per-column phase and the global tick.
                local idx = ((c.seed + tick + i * 13) % n) + 1
                love.graphics.print(pool[idx], c.x, y)
            end
        end
    end
    D.vignette(w, h, 0.75)
end

-- ═══════════════════════════════════════════════════════════
-- HEXGRID (mods, homebrew hub)
-- ═══════════════════════════════════════════════════════════
local hexgrid = { t = 0 }
function BG.draw_hexgrid(w, h, dt, col)
    hexgrid.t = hexgrid.t + dt
    local wii = is_wii()

    local size = 24
    local dx = size * 1.732
    local dy = size * 1.5
    love.graphics.setLineWidth(1)

    -- Reuse one scratch table for the polygon points. Previously the
    -- code allocated a fresh table per hexagon per frame.
    local pts = {}

    local function draw_hex(cx, cy)
        for i = 0, 5 do
            local ang = math.pi / 3 * i
            pts[i * 2 + 1] = cx + math.cos(ang) * size
            pts[i * 2 + 2] = cy + math.sin(ang) * size
        end
        love.graphics.polygon("line", pts)
    end

    if wii then
        love.graphics.clear(0.92, 0.95, 0.99)
        for row = -1, math.ceil(h / dy) + 1 do
            for c = -1, math.ceil(w / dx) + 1 do
                local cx = c * dx + (row % 2 == 1 and dx/2 or 0)
                local cy = row * dy
                local pulse = 0.5 + 0.5 * math.sin(
                    hexgrid.t * 1.5 + (row + c) * 0.4)
                love.graphics.setColor(0.15, 0.55, 0.88, 0.12 + pulse * 0.10)
                draw_hex(cx, cy)
            end
        end
        love.graphics.setColor(0.10, 0.55, 0.85, 0.10)
        local bar_y = (math.sin(hexgrid.t * 0.5) * 0.5 + 0.5) * h
        love.graphics.rectangle("fill", 0, bar_y - 40, w, 80)
        for i = 1, 4 do
            love.graphics.setColor(0.55, 0.68, 0.82, 0.03 * i)
            love.graphics.rectangle("line", -i*4, -i*4, w + i*8, h + i*8)
        end
        return
    end

    love.graphics.clear(0.03, 0.04, 0.07)
    for row = -1, math.ceil(h / dy) + 1 do
        for c = -1, math.ceil(w / dx) + 1 do
            local cx = c * dx + (row % 2 == 1 and dx/2 or 0)
            local cy = row * dy
            local pulse = 0.5 + 0.5 * math.sin(
                hexgrid.t * 1.5 + (row + c) * 0.4)
            love.graphics.setColor(col[1], col[2], col[3],
                0.10 + pulse * 0.08)
            draw_hex(cx, cy)
        end
    end
    love.graphics.setColor(col[1], col[2], col[3], 0.06)
    local bar_y = (math.sin(hexgrid.t * 0.5) * 0.5 + 0.5) * h
    love.graphics.rectangle("fill", 0, bar_y - 40, w, 80)
    D.vignette(w, h, 0.65)
end

-- ═══════════════════════════════════════════════════════════
-- BOOK (manual)
-- ═══════════════════════════════════════════════════════════
local book = { t = 0, dots = nil, dw = 0, dh = 0 }
function BG.draw_book(w, h, dt, col)
    book.t = book.t + dt
    local wii = is_wii()

    -- Precompute the paper dots once per (w, h). Uses a local RNG so the
    -- global math.random state is not disturbed.
    if not book.dots or book.dw ~= w or book.dh ~= h then
        book.dw, book.dh = w, h
        book.dots = {}
        local lrand = make_lcg(42)
        for i = 1, 180 do
            table.insert(book.dots, {
                x = lrand() * w,
                y = lrand() * h,
                r = lrand() * 2 + 0.5,
            })
        end
    end

    if wii then
        love.graphics.clear(0.96, 0.94, 0.90)
        love.graphics.setColor(0.82, 0.76, 0.68, 0.10)
        for _, d in ipairs(book.dots) do
            love.graphics.circle("fill", d.x, d.y, d.r)
        end
        for i = 0, 8 do
            local a = 0.05 * (1 - i / 8)
            love.graphics.setColor(0.55, 0.45, 0.35, a)
            love.graphics.rectangle("line", i, i, w - i*2, h - i*2)
        end
        return
    end

    love.graphics.clear(0.14, 0.10, 0.06)
    love.graphics.setColor(0.20, 0.15, 0.10, 0.10)
    for _, d in ipairs(book.dots) do
        love.graphics.circle("fill", d.x, d.y, d.r)
    end
    for i = 0, 8 do
        local a = 0.10 * (1 - i / 8)
        love.graphics.setColor(0.08, 0.05, 0.02, a)
        love.graphics.rectangle("line", i, i, w - i*2, h - i*2)
    end
    D.vignette(w, h, 0.8)
end

return BG