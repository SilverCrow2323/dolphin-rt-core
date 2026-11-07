-- ui/sfx.lua — real sound loader. Silent if files missing.
local M = {}
local _cache, _enabled, _volume = {}, true, 0.7

local MAP = {
    menu_move         = "assets/sfx/menu_move.ogg",
    menu_select       = "assets/sfx/menu_select.ogg",
    menu_back         = "assets/sfx/menu_back.ogg",
    menu_flip         = "assets/sfx/menu_flip.ogg",
    menu_pagescroll   = "assets/sfx/menu_pagescroll.ogg",
    menu_toggleoption = "assets/sfx/menu_toggleoption.ogg",
    error             = "assets/sfx/error.ogg",
    newupdate         = "assets/sfx/newupdate.ogg",
    notif_general     = "assets/sfx/notif_general.ogg",
    livemenu_open     = "assets/sfx/livemenu_open.ogg",
}

local function load(name)
    if _cache[name] ~= nil then return _cache[name] end
    local path = MAP[name]
    if not path then _cache[name] = false; return false end
    local ok, src = pcall(love.audio.newSource, path, "static")
    if not ok or not src then _cache[name] = false; return false end
    pcall(function() src:setVolume(_volume) end)
    _cache[name] = src
    return src
end

function M.play(name)
    if not _enabled then return end
    local src = load(name)
    if not src then return end
    local ok, clone = pcall(function() return src:clone() end)
    if ok and clone then
        pcall(function() clone:setVolume(_volume); clone:play() end)
    else
        pcall(function() src:stop(); src:play() end)
    end
end

function M.preload(name) return load(name) end
function M.set_enabled(v) _enabled = (v == true) end
function M.set_volume(v) _volume = math.max(0, math.min(1, tonumber(v) or 0.7)) end
function M.is_enabled() return _enabled end
return M
