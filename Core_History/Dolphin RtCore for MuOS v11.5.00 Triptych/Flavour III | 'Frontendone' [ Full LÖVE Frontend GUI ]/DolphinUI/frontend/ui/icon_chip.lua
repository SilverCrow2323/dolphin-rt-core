-- frontend/ui/icon_chip.lua
-- Draws an icon inside a themed "chip" — small rounded square with a
-- tinted background, border, and optional gloss.
--
-- Why a chip and not just a border:
--   * Guarantees contrast regardless of the icon's own colors or alpha
--   * Creates consistent visual rhythm across rows of varying icons
--   * Matches the polished look of iOS Settings / macOS Preferences
--
-- Theme palettes:
--   GC (dark)  — dark purple chip, silver metallic border, white gloss
--   Wii (light)— white chip, soft blue border, subtle shadow
--
-- Usage:
--   local IC = require("ui.icon_chip")
--   IC.draw("assets/images/menu/about.png", x, y, size, focused, accent)

local A     = require("assets")
local State = require("state")

local M = {}

local function palette(focused)
    if State.theme_name == "wii" then
        return {
            bg_top    = {1.00, 1.00, 1.00},
            bg_bottom = {0.90, 0.94, 0.99},
            border    = focused and {0.00, 0.63, 0.91} or {0.58, 0.72, 0.90},
            highlight = {1.00, 1.00, 1.00, 0.95},
            shadow    = {0.55, 0.62, 0.72, 0.35},
        }
    end
    -- GC / default (dark)
    return {
        bg_top    = {0.24, 0.22, 0.34},
        bg_bottom = {0.11, 0.09, 0.19},
        border    = focused and {0.90, 0.82, 1.00} or {0.58, 0.55, 0.72},
        highlight = {0.90, 0.86, 0.98, 0.55},
        shadow    = {0.00, 0.00, 0.00, 0.55},
    }
end

local function draw_gradient_rounded(x, y, w, h, r, top, bottom)
    -- 3 horizontal bands, corners rounded only on the outer bands.
    -- Reads as a gradient at chip sizes (30-36 px).
    local bands = 3
    local bh = h / bands
    for i = 0, bands - 1 do
        local t = i / (bands - 1)
        local cr = top[1] + (bottom[1] - top[1]) * t
        local cg = top[2] + (bottom[2] - top[2]) * t
        local cb = top[3] + (bottom[3] - top[3]) * t
        love.graphics.setColor(cr, cg, cb, 1)
        if i == 0 then
            love.graphics.rectangle("fill", x, y, w, bh + 1, r, r)
        elseif i == bands - 1 then
            love.graphics.rectangle("fill", x, y + i * bh - 1, w, bh + 1, r, r)
        else
            love.graphics.rectangle("fill", x, y + i * bh - 1, w, bh + 2)
        end
    end
end

-- Main draw.
--   icon_path : full relative path to the PNG
--   x, y      : top-left of the chip
--   size      : chip width/height (square)
--   focused   : boolean, draws a pulsing outer ring + brighter border
--   accent    : optional {r,g,b}, overrides the border color
function M.draw(icon_path, x, y, size, focused, accent)
    local pal = palette(focused)
    local r = (State.theme_name == "wii") and 7 or 5

    -- Drop shadow
    love.graphics.setColor(pal.shadow)
    love.graphics.rectangle("fill", x + 1, y + 2, size, size, r, r)

    -- Background gradient
    draw_gradient_rounded(x, y, size, size, r, pal.bg_top, pal.bg_bottom)

    -- Border
    local border = accent or pal.border
    love.graphics.setColor(border[1], border[2], border[3], 1)
    love.graphics.setLineWidth(focused and 2 or 1.4)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, size - 1, size - 1, r, r)
    love.graphics.setLineWidth(1)

    -- Top gloss: thin arc along the top half
    love.graphics.setColor(pal.highlight)
    love.graphics.setLineWidth(1)
    love.graphics.arc("line", "open",
        x + size / 2, y + r,
        size / 2 - 1.5, math.pi + 0.3, math.pi * 2 - 0.3)
    love.graphics.setLineWidth(1)

    -- Icon, contain-fit with padding
    local pad = 4
    local box = size - pad * 2
    local img = A.image(icon_path)
    if img then
        local iw, ih = img:getWidth(), img:getHeight()
        local sc = math.min(box / iw, box / ih)
        local dw, dh = iw * sc, ih * sc
        local dx = x + (size - dw) / 2
        local dy = y + (size - dh) / 2
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, dx, dy, 0, sc, sc)
    else
        -- Fallback: first letter of the filename
        local name = icon_path:match("([^/]+)%.png$") or "?"
        local letter = name:sub(1, 1):upper()
        love.graphics.setColor(border)
        love.graphics.setFont(A.font("assets/fonts/Oxanium-Bold.ttf",
            math.floor(box * 0.75)))
        love.graphics.printf(letter, x, y + pad - 2, size, "center")
    end

    -- Focus ring
    if focused then
        local pulse = 0.5 + 0.5 * math.sin((State.t_ui or 0) * 4)
        love.graphics.setColor(border[1], border[2], border[3], 0.3 * pulse)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, size + 4, size + 4,
            r + 2, r + 2)
        love.graphics.setLineWidth(1)
    end
end

return M