-- frontend/profile_manager.lua
-- Apply/list/drift-detect profile sets. All shell args go through shq().
--
-- Paths are relative to CWD (frontend/). workshop/ and dolphin-emu/ are
-- both physically inside frontend/.

local PMerger = require("profile_merger")
local PV      = require("profile_validator")
local BM      = require("backup_manager")
local Notify  = require("notify")

local M = {}

local TARGETS = {
    rtcoreprofile = { dir = "dolphin-emu/Config", files = { "Dolphin.ini", "GFX.ini" } },
    controller    = { dir = "dolphin-emu/Config", files = { "GCPadNew.ini", "WiimoteNew.ini" } },
    hotkeys       = { dir = "dolphin-emu/Config", files = { "Hotkeys.ini" } },
    logging       = { dir = "dolphin-emu/Config", files = { "Logger.ini" } },
    debug         = { dir = "dolphin-emu/Config", files = { "Logger.ini" } },
    gamesettings  = { dir = "dolphin-emu/Config/GameSettings", files = {} },
}

local PREFIX = {
    rtcoreprofile = "rtprofile",
    controller    = "rtcontroller",
    hotkeys       = "rthotkey",
    logging       = "rtlog",
    debug         = "rtdebug",
    gamesettings  = "rtgameset",
}

-- POSIX single-quote
local function shq(s)
    if s == nil then return "''" end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function dir_exists(p)
    local h = io.popen('[ -d ' .. shq(p) .. ' ] && echo 1 2>/dev/null')
    if not h then return false end
    local r = h:read("*a"); h:close()
    return r:match("1") ~= nil
end

function M.list(kind)
    local out = {}
    local base = "workshop/" .. kind
    local h = io.popen('ls -1 ' .. shq(base) .. ' 2>/dev/null')
    if not h then return out end
    for name in h:lines() do
        if name ~= "" and name:sub(1, 1) ~= "." then
            local prof_dir = base .. "/" .. name
            if dir_exists(prof_dir) then
                local meta = M.meta(kind, name)
                table.insert(out, { name = name, dir = prof_dir, meta = meta })
            end
        end
    end
    h:close()
    table.sort(out, function(a, b)
        local oa = tonumber(a.meta.UI and a.meta.UI.Order or 99) or 99
        local ob = tonumber(b.meta.UI and b.meta.UI.Order or 99) or 99
        return oa < ob
    end)
    return out
end

function M.meta(kind, name)
    local prefix = PREFIX[kind] or kind
    local path = "workshop/" .. kind .. "/" .. name .. "/" .. prefix .. "_data.ini"
    local parsed = PMerger.parse_ini(path)
    if not parsed then return {} end
    return parsed.data
end

function M.apply(kind, name)
    local target = TARGETS[kind]
    if not target then
        Notify.show("error", "Unknown profile kind: " .. kind)
        return false
    end

    local valid = PV.validate(kind, name)
    if not valid.ok then
        Notify.show("error", "Validation failed: " .. (valid.errors[1] or "?"))
        return false
    end

    for _, file in ipairs(target.files) do
        BM.backup(file)
    end

    if kind == "gamesettings" then
        local id = name
        local src_ini = "workshop/gamesettings/" .. id .. "/" .. id .. ".ini"
        local f = io.open(src_ini, "r")
        if f then
            f:close()
            os.execute("mkdir -p " .. shq(target.dir))
            os.execute("cp " .. shq(src_ini) .. " " ..
                       shq(target.dir .. "/" .. id .. ".ini"))
        end
    else
        PMerger.apply_profile(kind, name, target.dir, target.files, "workshop")
    end

    Notify.show("success", "Applied: " .. name)
    return true
end

function M.detect_drift(kind)
    kind = kind or "rtcoreprofile"
    local target = TARGETS[kind]
    if not target then return { saved = false } end

    local files_to_check = target.files
    if kind == "rtcoreprofile" then
        files_to_check = { "Dolphin.ini", "GFX.ini" }
    end

    local profiles = M.list(kind)
    for _, p in ipairs(profiles) do
        local all_match = true
        for _, file in ipairs(files_to_check) do
            local active = PMerger.parse_ini(target.dir .. "/" .. file)
            local merged = PMerger.merge_chain(kind, p.name, file, "workshop")
            if not active or not merged or not PMerger.deep_equal(active, merged) then
                all_match = false
                break
            end
        end
        if all_match then
            return { saved = true, profile = p.name }
        end
    end

    return { saved = false, profile = nil }
end

function M.active_profile(kind)
    kind = kind or "rtcoreprofile"
    local State = require("state")
    return (State.active_profiles or {})[kind]
end

function M.set_active(kind, name)
    local State = require("state")
    State.active_profiles = State.active_profiles or {}
    State.active_profiles[kind] = name
end

return M