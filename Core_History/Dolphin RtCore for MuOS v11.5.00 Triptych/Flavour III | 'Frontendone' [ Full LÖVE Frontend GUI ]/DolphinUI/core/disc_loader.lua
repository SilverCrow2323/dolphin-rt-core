local FS = require("core.fs")
local sh = require("core.shell")

local M = {}
local DISC_DIR = "data/covers/disc"
local _cache = {}

local function exists(p)
    local f = io.open(p, "rb")
    if f then f:close(); return true end
    return false
end

local function url_for(id)
    if not id or #id ~= 6 then return nil end
    local reg = "EN"
    local r = id:sub(4,4)
    if r == "P" or r == "D" or r == "F" or r == "I" or r == "S" or r == "X" or r == "H" then reg = "EN"
    elseif r == "J" or r == "K" or r == "W" then reg = "JA"
    end
    return string.format("https://art.gametdb.com/wii/disc/%s/%s.png", reg, id)
end

local function process_image(path)
    local ok, data = pcall(love.image.newImageData, path)
    if not ok or not data then return false end
    local w, h = data:getDimensions()
    local cx, cy = w/2, h/2
    for y = 0, h-1 do
        for x = 0, w-1 do
            local r, g, b, a = data:getPixel(x, y)
            if r > 0.92 and g > 0.92 and b > 0.92 then
                data:setPixel(x, y, r, g, b, 0)
            else
                local dist = math.sqrt((x-cx)^2 + (y-cy)^2)
                local hole_r = w * 0.08
                if dist < hole_r then
                    data:setPixel(x, y, r, g, b, 0)
                end
            end
        end
    end
    local ok2, filedata = pcall(function() return data:encode("png") end)
    if not ok2 or not filedata then return false end
    local f = io.open(path, "wb")
    if f then
        f:write(filedata:getString())
        f:close()
        return true
    end
    return false
end

function M.get(game)
    if not game or not game.id then return nil end
    local id = game.id
    if _cache[id] ~= nil then
        local c = _cache[id]
        if c == "loading" or c == "failed" then return nil end
        return c
    end
    local final_path = DISC_DIR .. "/" .. id .. ".png"
    if exists(final_path) then
        local ok, img = pcall(love.graphics.newImage, final_path)
        if ok and img then
            img:setFilter("linear", "linear")
            _cache[id] = img
            return img
        end
    end
    if not exists(DISC_DIR) then sh.mkdir_p(DISC_DIR) end
    local url = url_for(id)
    if not url then _cache[id] = "failed"; return nil end
    
    _cache[id] = "loading"
    local inner = string.format(
        "if command -v curl >/dev/null 2>&1; then curl -fsSL --max-time 30 --retry 2 --retry-delay 1 -o %s %s; " ..
        "elif command -v wget >/dev/null 2>&1; then wget -q -T 30 --tries=2 -O %s %s; fi",
        sh.shq(final_path), sh.shq(url), sh.shq(final_path), sh.shq(url))
    os.execute("setsid sh -c " .. sh.shq(inner) .. " </dev/null >/dev/null 2>&1 &")
    return nil
end

function M.update()
    for id, val in pairs(_cache) do
        if val == "loading" then
            local final_path = DISC_DIR .. "/" .. id .. ".png"
            if exists(final_path) then
                if process_image(final_path) then
                    local ok, img = pcall(love.graphics.newImage, final_path)
                    if ok and img then
                        img:setFilter("linear", "linear")
                        _cache[id] = img
                    else
                        _cache[id] = "failed"
                    end
                else
                    _cache[id] = "failed"
                end
            end
        end
    end
end

return M
