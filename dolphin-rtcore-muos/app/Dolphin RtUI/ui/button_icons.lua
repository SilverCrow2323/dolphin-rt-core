-- ui/button_icons.lua — footer with key "keycaps" used by the System drawer.
-- (ui.system_panel required this module, but it was never shipped: the MENU
-- drawer silently failed to load. Restored in 3.4.0.)
--
--   M.draw_metal_footer(theme, items, W, y, h, font)
--     items = { {key="a", label="Open"}, {key="dpad", label="Sel"}, ... }
--     theme = { accent = {r,g,b}, text = {r,g,b} }
local M = {}

local KEYCAP = { dpad = "D-PAD", a = "A", b = "B", x = "X", y = "Y",
                 l1 = "L1", r1 = "R1", l2 = "L2", r2 = "R2",
                 start = "START", select = "SELECT", menu = "MENU" }

function M.draw_metal_footer(theme, items, W, y, h, font)
    theme = theme or {}
    local acc = theme.accent or { 0.30, 0.85, 1.00 }
    local txt = theme.text   or { 0.90, 0.94, 1.00 }
    font = font or love.graphics.getFont()
    local kf = font
    local x = 14
    local ch = math.max(16, (h or 26) - 8)
    for _, it in ipairs(items or {}) do
        local cap = KEYCAP[tostring(it.key):lower()] or tostring(it.key):upper()
        local kw = kf:getWidth(cap) + 12
        love.graphics.setColor(acc[1], acc[2], acc[3], 0.20)
        love.graphics.rectangle("fill", x, y + 2, kw, ch, 5, 5)
        love.graphics.setColor(acc[1], acc[2], acc[3], 0.95)
        love.graphics.rectangle("line", x, y + 2, kw, ch, 5, 5)
        love.graphics.setFont(kf)
        love.graphics.setColor(txt[1], txt[2], txt[3], 1)
        love.graphics.print(cap, x + 6, y + 2 + (ch - kf:getHeight()) / 2)
        x = x + kw + 6
        local label = it.label or ""
        love.graphics.setColor(0.72, 0.78, 0.90, 1)
        love.graphics.print(label, x, y + 2 + (ch - kf:getHeight()) / 2)
        x = x + kf:getWidth(label) + 16
        if x > W - 20 then break end
    end
end

return M
