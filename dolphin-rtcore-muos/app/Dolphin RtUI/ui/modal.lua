-- ui/modal.lua — confirmation dialog con dimensioni dinamiche.
local K = require("ui.kit")

local M = { _open = false, _opts = {}, _title = "", _body = "", _t = 0 }

function M.show(title, body, opts)
    M._title = tostring(title or "")
    M._body  = tostring(body or "")
    M._opts  = opts or {}
    M._open  = true
    M._t     = 0
end

function M.is_open() return M._open end
function M.close() M._open = false end
function M.update(dt) M._t = (M._t or 0) + dt end

local function done(accept)
    local cb = accept and M._opts.on_accept or M._opts.on_cancel
    M.close()
    if cb then pcall(cb) end
end

function M.pad(b)
    if not M._open then return end
    if b == "A" or b == "START" then done(true)
    elseif b == "B" or b == "SELECT" then done(false) end
end

function M.key(k)
    if not M._open then return end
    if k == "return" or k == "space" then done(true)
    elseif k == "escape" then done(false) end
end

function M.draw(W, H)
    if not M._open then return end
    W, H = W or K.W or 640, H or K.H or 480
    local c = M._opts.color
    if type(c) ~= "table" or type(c[1]) ~= "number" then
        c = K.acc or K.ACC.gc or { 0.55, 0.47, 1.0 }
    end

    -- sfondo
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- calcola dimensioni in base al testo
    local bw = math.min(520, W - 40)
    local pad = 26
    local text_w = bw - pad * 2

    local title_f = K.font("h")
    local body_f  = K.font("body")
    local title_h = title_f:getHeight()

    -- wrap body per altezza
    local _, body_lines = body_f:getWrap(M._body, text_w)
    local body_h = #body_lines * body_f:getHeight()

    local button_h = 24
    local bh = pad + title_h + 14 + body_h + 22 + button_h + pad
    local bx = math.floor((W - bw) / 2)
    local by = math.floor((H - bh) / 2)

    -- pannello
    K.panel(bx, by, bw, bh, { cut = 12, accent = c, fill = { 0.055, 0.065, 0.10 } })

    -- titolo + underline
    K.text("h", M._title, bx + pad, by + pad - 4, K.C.text)
    K.color(c, 1)
    love.graphics.rectangle("fill", bx + pad, by + pad + title_h - 2, 44, 3)

    -- body
    local by_body = by + pad + title_h + 18
    K.text("body", M._body, bx + pad, by_body, K.C.dim, 1, text_w)

    -- bottoni A / B
    local y_btn = by + bh - pad - button_h
    local ok_l     = M._opts.accept_label or "OK"
    local cancel_l = M._opts.cancel_label or "Cancel"

    -- badge A
    local ax = bx + pad
    K.color(K.C.ok, 0.22)
    love.graphics.circle("fill", ax + 9, y_btn + button_h / 2, 10)
    K.color(K.C.ok, 1)
    love.graphics.setLineWidth(1.4)
    love.graphics.circle("line", ax + 9, y_btn + button_h / 2, 10)
    love.graphics.setLineWidth(1)
    K.text("key", "A", ax + 5, y_btn + button_h / 2 - 7, K.C.ok)
    K.text("body", ok_l, ax + 26, y_btn + button_h / 2 - 9, K.C.ok)

    -- badge B (a destra)
    local cw = K.width("body", cancel_l)
    local bx2 = bx + bw - pad - cw - 28
    K.color(K.C.dim, 0.22)
    love.graphics.circle("fill", bx2 + 9, y_btn + button_h / 2, 10)
    K.color(K.C.dim, 1)
    love.graphics.setLineWidth(1.4)
    love.graphics.circle("line", bx2 + 9, y_btn + button_h / 2, 10)
    love.graphics.setLineWidth(1)
    K.text("key", "B", bx2 + 5, y_btn + button_h / 2 - 7, K.C.dim)
    K.text("body", cancel_l, bx2 + 26, y_btn + button_h / 2 - 9, K.C.dim)
end

return M
