-- frontend/assets.lua — font & image registry (lazy, theme-aware).
--
-- v0.6.0
--   * A.title_font(text, size) — picks the theme's title font for
--     ASCII-only text and silently falls back to Oxanium-Bold when
--     the text contains non-ASCII bytes. This is the fix for the
--     "white square instead of a letter" bug: GameCube.ttf (and
--     Wii.ttf) cover basic ASCII only, so any accented char, arrow,
--     bullet or star rendered with the title font ends up as a
--     missing-glyph box.
--   * The small-text boost is unchanged from v0.5.1 (floor 14, curve
--     9..13 -> 14, JetBrains Mono floor 13).

local M = { fonts = {}, images = {} }

local _state = nil
local function get_state()
    if not _state then
        local ok, s = pcall(require, "state")
        if ok then _state = s end
    end
    return _state
end

-- ── Boost curve ─────────────────────────────────────────────
local function small_boost(sz)
    if not sz then return 0 end
    if sz <= 13 then return 14 - sz end
    return 0
end

local function font_size_offset(path, theme, sz)
    if not theme then return small_boost(sz) end
    if theme.font_title and path == theme.font_title then
        return theme.font_offset_title or 0
    end
    if path:match("JetBrainsMono") then
        if sz < 13 then return 13 - sz end
        return 0
    end
    local b = small_boost(sz)
    if b > 0 then return b end
    return theme.font_offset_body or 0
end

-- ── Loaders ─────────────────────────────────────────────────
local function try_new_image(path)
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then return img end
    local f = io.open(path, "rb")
    if not f then return nil end
    local bytes = f:read("*a"); f:close()
    if not bytes or #bytes == 0 then return nil end
    local ok2, fd = pcall(love.filesystem.newFileData, bytes, "img")
    if not ok2 or not fd then return nil end
    local ok3, img2 = pcall(love.graphics.newImage, fd)
    if ok3 and img2 then return img2 end
    return nil
end

local function try_new_font(path, size)
    local ok, fnt = pcall(love.graphics.newFont, path, size)
    if ok and fnt then return fnt end
    local f = io.open(path, "rb")
    if not f then return nil end
    local bytes = f:read("*a"); f:close()
    if not bytes or #bytes == 0 then return nil end
    local ok2, fd = pcall(love.filesystem.newFileData, bytes, "font")
    if not ok2 or not fd then return nil end
    local ok3, fnt2 = pcall(love.graphics.newFont, fd, size)
    if ok3 and fnt2 then return fnt2 end
    return nil
end

function M.font(path, size)
    local s = get_state()
    local theme = s and s.theme or nil
    local offset = font_size_offset(path, theme, size)
    local floor = path:match("JetBrainsMono") and 13 or 14
    local final_size = math.max(floor, size + offset)

    local key = path .. "@" .. tostring(final_size)

    if M.fonts[key] == nil then
        local fnt = try_new_font(path, final_size)
        if not fnt then
            fnt = try_new_font("assets/fonts/Oxanium-Regular.ttf", final_size)
        end
        if not fnt then
            local ok, def = pcall(love.graphics.newFont, final_size)
            fnt = ok and def or nil
        end
        if fnt then fnt:setFilter("linear", "linear") end
        M.fonts[key] = fnt or false
    end
    return M.fonts[key] or love.graphics.getFont()
end

-- ── Non-ASCII detection ─────────────────────────────────────
-- Bytes >= 128 mean the string contains a UTF-8 encoded multi-byte
-- character. We do not need to decode the whole thing: if ANY byte
-- is >= 128, we assume the title font will not have it and use
-- Oxanium instead.
local function has_non_ascii(s)
    if not s then return false end
    for i = 1, #s do
        if s:byte(i) >= 128 then return true end
    end
    return false
end

-- Title-font resolver. Use this EVERYWHERE a title would previously
-- have been drawn with A.font(th.font_title, size) on user content
-- (game names, ROM titles, device names, ...). Screens that draw a
-- hardcoded English literal (e.g. "DolphinUI", "SETTINGS") can keep
-- calling A.font(th.font_title, size) directly — this helper only
-- matters when the string is dynamic.
function M.title_font(text, size)
    local s = get_state()
    local theme = s and s.theme or nil
    local path = (theme and theme.font_title)
              or "assets/fonts/Oxanium-Bold.ttf"
    if has_non_ascii(text) then
        path = "assets/fonts/Oxanium-Bold.ttf"
    end
    return M.font(path, size)
end

function M.image(path)
    if not path or path == "" then return nil end
    if M.images[path] == nil then
        local img = try_new_image(path)
        if img then img:setFilter("linear", "linear") end
        M.images[path] = img or false
    end
    return M.images[path] or nil
end

function M.drawImage(path, x, y, w, h)
    local img = M.image(path)
    if not img then return end
    local sx = w and (w / img:getWidth()) or 1
    local sy = h and (h / img:getHeight()) or 1
    love.graphics.draw(img, x, y, 0, sx, sy)
end

function M.invalidate_image(path)
    if path then M.images[path] = nil end
end

function M.invalidate_fonts()
    M.fonts = {}
end

return M