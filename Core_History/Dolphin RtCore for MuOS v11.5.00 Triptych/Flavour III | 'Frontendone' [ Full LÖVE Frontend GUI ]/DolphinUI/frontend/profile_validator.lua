local PM = require("profile_merger")
local V = {}

local function exists(p)
    local f = io.open(p, "r")
    if f then f:close(); return true end
    return false
end

local function dir_exists(p)
    local h = io.popen('[ -d "' .. p .. '" ] && echo 1')
    if not h then return false end
    local r = h:read("*a")
    h:close()
    return r:match("1") ~= nil
end

function V.validate(kind, name, base_workshop)
    base_workshop = base_workshop or "workshop"
    local res = { ok = true, errors = {}, warnings = {} }

    local prefix = ({
        rtcoreprofile = "rtprofile",
        controller    = "rtcontroller",
        hotkeys       = "rthotkey",
        logging       = "rtlog",
        debug         = "rtdebug",
        gamesettings  = "rtgameset",
    })[kind] or kind

    local prof_dir = base_workshop .. "/" .. kind .. "/" .. name
    if not dir_exists(prof_dir) then
        table.insert(res.errors, "Profile directory not found: " .. prof_dir)
        res.ok = false
        return res
    end

    local meta_path = prof_dir .. "/" .. prefix .. "_data.ini"
    if not exists(meta_path) then
        table.insert(res.warnings, "Missing metadata file: " .. meta_path)
    end

    local base_path = base_workshop .. "/base/Dolphin.ini"
    if not exists(base_path) then
        table.insert(res.errors, "Base Dolphin.ini missing")
        res.ok = false
    end

    return res
end

return V