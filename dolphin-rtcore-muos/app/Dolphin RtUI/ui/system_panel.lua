-- ui/system_panel.lua — v2.0 "Workshop Drawer"
-- Slide-down panel: operations + notification history. MENU toggles.

local SFX = require("ui.sfx")
local BI = require("ui.button_icons")
local Icons = require("ui.icons")
local Fonts = require("ui.theme.fonts")
local Hub = require("core.notification_hub")

local M = {}
local W, H = 640, 480
M._open = false; M._progress = 0; M._t = 0; M._sel = 1; M._scroll = 0
local _ops, _op_order = {}, {}

function M.init() M._open = false; M._progress = 0; M._t = 0; M._sel = 1; M._scroll = 0; _ops = {}; _op_order = {} end
function M.is_open() return M._open end
function M.open() if M._open then return end; M._open = true; M._sel = 1; M._scroll = 0; SFX.play("menu_flip") end
function M.close() if not M._open then return end; M._open = false; SFX.play("menu_back") end
function M.toggle() if M._open then M.close() else M.open() end end

function M.operation_start(id, name, opts)
    opts = opts or {}
    if not _ops[id] then table.insert(_op_order, id) end
    _ops[id] = { id = id, name = name or id,
        progress = math.max(0, math.min(1, tonumber(opts.progress) or 0)),
        status = "running", detail = opts.detail or "",
        ttl_done = opts.ttl_done or 4,
        started = os.time(), updated = os.time() }
end
function M.operation_progress(id, p, detail)
    local o = _ops[id]; if not o then return end
    if p then o.progress = math.max(0, math.min(1, tonumber(p) or o.progress)) end
    if detail then o.detail = detail end
    o.updated = os.time()
end
function M.operation_done(id, status)
    local o = _ops[id]; if not o then return end
    o.status = status or "done"; o.progress = 1; o.updated = os.time()
end
function M.operation_remove(id)
    if _ops[id] then
        _ops[id] = nil
        for i, k in ipairs(_op_order) do if k == id then table.remove(_op_order, i); break end end
    end
end

function M.update(dt)
    M._t = M._t + dt
    local target = M._open and 1 or 0
    M._progress = M._progress + (target - M._progress) * math.min(1, dt * 10)
    if math.abs(M._progress - target) < 0.005 then M._progress = target end
    local now = os.time()
    for id, o in pairs(_ops) do
        if o.status ~= "running" and now - (o.updated or now) > (o.ttl_done or 4) then
            M.operation_remove(id)
        end
    end
end

local TYPE_COLORS = {
    info = {0.20, 0.72, 0.98}, success = {0.30, 0.85, 0.40},
    warning = {0.96, 0.77, 0.26}, error = {0.90, 0.30, 0.30},
    update = {0.62, 0.35, 0.98}, download = {0.20, 0.65, 0.95},
    scan = {0.96, 0.62, 0.20},
}
local TYPE_ICON = {
    info = "info", success = "check", warning = "warning",
    error = "error", update = "update", download = "save", scan = "library",
}

local function chamfer(mode, x, y, w, h, cut)
    cut = cut or 4
    love.graphics.polygon(mode, x+cut, y, x+w-cut, y, x+w, y+cut, x+w, y+h-cut, x+w-cut, y+h, x+cut, y+h, x, y+h-cut, x, y+cut)
end

local function draw_op_row(o, x, y, w, h)
    local c = (o.status == "error" and TYPE_COLORS.error)
           or (o.status == "done" and TYPE_COLORS.success) or TYPE_COLORS.info
    love.graphics.setColor(0.06, 0.07, 0.11, 0.98); chamfer("fill", x, y, w, h, 5)
    love.graphics.setColor(c); love.graphics.setLineWidth(1.4); chamfer("line", x, y, w, h, 5); love.graphics.setLineWidth(1)
    love.graphics.setFont(Fonts.get("assets/fonts/Orbitron-Bold.ttf", 12)); love.graphics.setColor(0.94, 0.97, 1.0)
    love.graphics.print(o.name, x + 10, y + 6)
    love.graphics.setFont(Fonts.get("assets/fonts/JetBrainsMono-Regular.ttf", 10)); love.graphics.setColor(0.68, 0.74, 0.86)
    love.graphics.printf((o.detail ~= "" and o.detail) or o.status:upper(), x + 10, y + 6, w - 20, "right")
    local px, py, pw, ph = x + 10, y + h - 14, w - 20, 6
    love.graphics.setColor(0.12, 0.14, 0.20, 1); love.graphics.rectangle("fill", px, py, pw, ph, 3, 3)
    love.graphics.setColor(c); love.graphics.rectangle("fill", px, py, pw * (o.progress or 0), ph, 3, 3)
end

local function draw_notif_row(entry, x, y, w, h, focused)
    local c = TYPE_COLORS[entry.kind] or TYPE_COLORS.info
    love.graphics.setColor(focused and c[1]*0.22 or 0.045, focused and c[2]*0.22 or 0.055, focused and c[3]*0.22 or 0.080, 0.97)
    chamfer("fill", x, y, w, h, 5)
    love.graphics.setColor(c[1], c[2], c[3], focused and 0.95 or 0.35)
    love.graphics.setLineWidth(focused and 1.6 or 1.0); chamfer("line", x, y, w, h, 5); love.graphics.setLineWidth(1)
    if focused then love.graphics.setColor(c); love.graphics.rectangle("fill", x, y, 3, h, 1, 1) end
    Icons.draw(TYPE_ICON[entry.kind] or "info", x + 10, y + (h-18)/2, 18, focused and {1,1,1} or c)
    love.graphics.setFont(Fonts.get("assets/fonts/Orbitron-Bold.ttf", 11))
    love.graphics.setColor(focused and {1,1,1} or {0.94,0.96,1})
    local title = entry.title or ""; if #title > 34 then title = title:sub(1, 32) .. ".." end
    love.graphics.print(title, x + 38, y + 4)
    love.graphics.setFont(Fonts.get("assets/fonts/ChakraPetch-Italic.ttf", 9))
    love.graphics.setColor(0.72, 0.78, 0.90)
    local sub = entry.subtitle or ""; if #sub > 60 then sub = sub:sub(1, 58) .. ".." end
    love.graphics.print(sub, x + 38, y + 20)
    love.graphics.setFont(Fonts.get("assets/fonts/JetBrainsMono-Regular.ttf", 8))
    love.graphics.setColor(0.55, 0.62, 0.74)
    love.graphics.printf(os.date("%H:%M", entry.ts or os.time()), x + 38, y + h - 12, w - 50, "right")
end

function M.draw(W_, H_)
    W, H = W_ or W, H_ or H
    if M._progress < 0.005 then return end
    local p = M._progress
    local panel_h = math.min(420, H - 40)
    local py = -panel_h + panel_h * p
    love.graphics.setColor(0, 0, 0, 0.55 * p); love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setColor(0.045, 0.055, 0.080, 0.98 * p); love.graphics.rectangle("fill", 0, py, W, panel_h)
    local accent = {0.30, 0.85, 1.00}
    love.graphics.setColor(accent); love.graphics.rectangle("fill", 0, py + panel_h - 2, W, 2)
    love.graphics.setColor(0, 0, 0, 0.35 * p); love.graphics.rectangle("fill", 0, py, W, 26)
    love.graphics.setFont(Fonts.get("assets/fonts/Orbitron-Bold.ttf", 14)); love.graphics.setColor(accent)
    love.graphics.print("SYSTEM", 14, py + 6)
    love.graphics.setFont(Fonts.get("assets/fonts/JetBrainsMono-Regular.ttf", 11))
    love.graphics.setColor(0.72, 0.78, 0.90)
    love.graphics.printf(string.format("%d op  ·  %d notice", #_op_order, #Hub.history()), 0, py + 8, W - 14, "right")
    local list_x, list_w = 10, W - 20
    local list_top, list_bot = py + 32, py + panel_h - 30
    local row_h, gap = 48, 4
    love.graphics.setScissor(0, list_top, W, list_bot - list_top)
    local y = list_top
    if #_op_order > 0 then
        love.graphics.setFont(Fonts.get("assets/fonts/JetBrainsMono-Bold.ttf", 10))
        love.graphics.setColor(0.55, 0.62, 0.78); love.graphics.print("OPERATIONS", list_x, y)
        y = y + 14
        for _, id in ipairs(_op_order) do
            local o = _ops[id]
            if o then draw_op_row(o, list_x, y, list_w, 44); y = y + 44 + gap end
        end
        y = y + 4
    end
    local hist = Hub.history()
    if #hist > 0 then
        love.graphics.setFont(Fonts.get("assets/fonts/JetBrainsMono-Bold.ttf", 10))
        love.graphics.setColor(0.55, 0.62, 0.78); love.graphics.print("NOTIFICATIONS", list_x, y)
        y = y + 14
        if M._sel > #hist then M._sel = #hist end
        if M._sel < 1 then M._sel = 1 end
        for i = 1, #hist do
            local yy = y + (i - 1) * (row_h + gap) - M._scroll
            if yy + row_h > list_top - row_h and yy < list_bot + row_h then
                draw_notif_row(hist[i], list_x, yy, list_w, row_h, i == M._sel)
            end
        end
    end
    love.graphics.setScissor()
    local fake_th = { text = accent, accent = accent, focus = accent }
    BI.draw_metal_footer(fake_th,
        { {key="dpad", label="Sel"}, {key="a", label="Open"}, {key="x", label="Clear"},
          {key="b", label="Close"} },
        W, py + panel_h - 28, 26, Fonts.get("assets/fonts/Oxanium-Regular.ttf", 12))
end

function M.pad(b)
    if not M._open then return end
    if b == "UP" then M._sel = math.max(1, M._sel - 1); SFX.play("menu_move")
    elseif b == "DOWN" then M._sel = math.min(math.max(1, #Hub.history()), M._sel + 1); SFX.play("menu_move")
    elseif b == "A" then
        local hist = Hub.history(); local entry = hist[M._sel]
        if entry then
            Hub.dismiss(entry.id)
            local meta = entry.meta or {}
            if meta.url and meta.url ~= "" then
                os.execute("xdg-open " .. string.format("%q", meta.url) .. " 2>/dev/null &")
            end
            SFX.play("menu_select")
        end
    elseif b == "X" then
        Hub.clear_active(); Hub.clear_history(); M._sel = 1; M._scroll = 0; SFX.play("menu_flip")
    elseif b == "MENU" or b == "B" then M.close() end
end

function M.key(k)
    if not M._open then return end
    if k == "up" then M.pad("UP")
    elseif k == "down" then M.pad("DOWN")
    elseif k == "return" or k == "space" then M.pad("A")
    elseif k == "x" then M.pad("X")
    elseif k == "y" then M.pad("Y")
    elseif k == "escape" or k == "m" then M.close() end
end

function M.notify(kind, text)
    Hub.push(kind or "info", kind or "Info", text or "", { ttl = 4 })
end

return M
