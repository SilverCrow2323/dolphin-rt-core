-- ui/assets.lua — wrapper LÖVE per caricamento immagini/font.
-- Sostituisce il vecchio modulo "assets" della vecchia codebase.

local M = {}
local img_cache  = {}
local font_cache = {}

function M.image(path)
    if not path or path == "" then return nil end
    if img_cache[path] ~= nil then return img_cache[path] or nil end
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then
        img:setFilter("linear", "linear")
        img_cache[path] = img
        return img
    end
    img_cache[path] = false
    return nil
end

function M.font(path, size)
    size = math.max(6, math.floor(size or 12))
    local key = tostring(path) .. "|" .. size
    if font_cache[key] then return font_cache[key] end
    local ok, f = pcall(love.graphics.newFont, path, size)
    if not ok or not f then f = love.graphics.newFont(size) end
    font_cache[key] = f
    return f
end

function M.title_font(_txt, size)
    return M.font("assets/fonts/Orbitron-Bold.ttf", size or 22)
end

function M.clear()
    img_cache, font_cache = {}, {}
end

return M
