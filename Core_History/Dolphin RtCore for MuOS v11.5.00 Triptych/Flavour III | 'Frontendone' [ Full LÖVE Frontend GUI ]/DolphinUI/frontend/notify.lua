local A = require("assets")
local State = require("state")
local D = require("ui.draw")

local N = { items = {} }
local COLORS = {
    info={0.30,0.60,0.95}, success={0.30,0.80,0.40},
    warning={0.96,0.77,0.26}, error={0.90,0.25,0.25},
}

function N.show(kind, message, ttl)
    table.insert(N.items, { kind=kind or "info", message=message or "", t=0, ttl=ttl or 2.5 })
end

function N.update(dt)
    for i = #N.items, 1, -1 do
        local it = N.items[i]
        it.t = it.t + dt
        if it.t > it.ttl then table.remove(N.items, i) end
    end
end

function N.draw(w, h)
    local th = State.theme
    w = w or 640
    h = h or 480
    local base_y = h - 100
    for i, it in ipairs(N.items) do
        local p = it.t / it.ttl
        local alpha = 1
        if p > 0.85 then alpha = (1 - p) / 0.15 end
        if p < 0.10 then alpha = p / 0.10 end
        alpha = math.max(0, math.min(1, alpha))
        local c = COLORS[it.kind] or COLORS.info
        local font = A.font(th.font_body_bold, 11)

        -- Clamp the box to the available width, then wrap the text
        -- to fit inside the box's internal padding. Previously the
        -- box was clamped but the text was printed raw, so a long
        -- message (e.g. "Report saved: <game_id>") overflowed past
        -- the right edge of the panel.
        local max_bw = w - 40
        local text_w = font:getWidth(it.message)
        local bw = math.min(max_bw, text_w + 32)
        local bx = w - bw - 20
        local by = base_y - (i - 1) * 34

        love.graphics.setColor(0, 0, 0, 0.75 * alpha)
        love.graphics.rectangle("fill", bx, by, bw, 28, 4, 4)
        love.graphics.setColor(c[1], c[2], c[3], 0.9 * alpha)
        love.graphics.setLineWidth(2)
        D.rough_rect(bx, by, bw, 28, { jitter=0.8, thickness=1.5, seed=i*7 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("fill", bx, by, 4, 28, 2, 2)

        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.setFont(font)
        love.graphics.printf(it.message, bx + 14, by + 8, bw - 28, "left")
    end
end

return N