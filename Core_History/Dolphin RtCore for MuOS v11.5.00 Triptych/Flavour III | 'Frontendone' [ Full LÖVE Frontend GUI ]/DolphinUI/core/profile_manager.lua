-- frontend/profile_manager.lua
-- Apply/list/drift-detect profile sets. All shell args go through shq().
--
-- Paths are relative to CWD (frontend/). workshop/ and dolphin-emu/ are
-- both physically inside frontend/.

local PMerger = require("core.profile_merger")
local PV      = require("core.profile_validator")
local BM      = require("core.backup_manager")
local Notify  = require("ui.notify")
local sh      = require("core.shell")

local M = {}

local TARGETS = {
    rtcoreprofile = { dir = "/opt/muos/share/emulator/dolphin/Config", files = { "Dolphin.ini", "GFX.ini" } },
    controller    = { dir = "/opt/muos/share/emulator/dolphin/Config", files = { "GCPadNew.ini", "WiimoteNew.ini" } },
    hotkeys       = { dir = "/opt/muos/share/emulator/dolphin/Config", files = { "Hotkeys.ini" } },
    logging       = { dir = "/opt/muos/share/emulator/dolphin/Config", files = { "Logger.ini" } },
    gamesettings  = { dir = "/opt/muos/share/emulator/dolphin/Config/GameSettings", files = {} },
}

local PREFIX = {
    rtcoreprofile = "rtprofile",
    controller    = "rtcontroller",
    hotkeys       = "rthotkey",
    logging       = "rtlog",
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
    local base = sh.workshop(kind)
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
    local path = sh.workshop(kind) .. "/" .. name .. "/" .. prefix .. "_data.ini"
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

    local ok = true
    if kind == "gamesettings" then
        local id = name
        local src_ini = "workshop/gamesettings/" .. id .. "/" .. id .. ".ini"
        local f = io.open(src_ini, "r")
        if f then
            f:close()
            os.execute("mkdir -p " .. shq(target.dir))
            local rc = os.execute("cp " .. shq(src_ini) .. " " ..
                       shq(target.dir .. "/" .. id .. ".ini"))
            ok = (rc == true or rc == 0)
        else
            ok = false
        end
    else
        ok = PMerger.apply_profile(kind, name, target.dir,
                                   target.files, "workshop")
    end

    if ok then
        Notify.show("success", "Applied: " .. name)
    else
        Notify.show("error", "Apply failed: " .. name)
    end
    return ok
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
    local State = require("core.state")
    return (State.active_profiles or {})[kind]
end

function M.set_active(kind, name)
    local State = require("core.state")
    State.active_profiles = State.active_profiles or {}
    State.active_profiles[kind] = name
end


-- ── VARIANT-PATCH-V1 ────────────────────────────────────────
-- Scansiona anche le sottocartelle di ogni profilo top-level.
-- Una variante è una subdir che contiene rtprofile_data.ini.
-- Viene esposta come "Parent/variant". Tutto il resto (meta,
-- apply, validate, merge_chain) già usa il nome come path, quindi
-- questo è l'unico punto da toccare.
do
    local _base_list = M.list
    function M.list(kind)
        local out = _base_list(kind)
        local seen = {}
        for _, q in ipairs(out) do seen[q.name] = true end
        local n = #out
        for i = 1, n do
            local q = out[i]
            if q.dir then
                local h = io.popen('ls -1 ' .. shq(q.dir) .. ' 2>/dev/null')
                if h then
                    for sub in h:lines() do
                        if sub ~= "" and sub:sub(1,1) ~= "." then
                            local sub_dir  = q.dir .. "/" .. sub
                            local sub_name = q.name .. "/" .. sub
                            if not seen[sub_name] and dir_exists(sub_dir) then
                                local sub_meta = M.meta(kind, sub_name)
                                if next(sub_meta) ~= nil then
                                    table.insert(out, {
                                        name = sub_name,
                                        dir  = sub_dir,
                                        meta = sub_meta,
                                    })
                                    seen[sub_name] = true
                                end
                            end
                        end
                    end
                    h:close()
                end
            end
        end
        table.sort(out, function(a, b)
            local oa = tonumber(a.meta.UI and a.meta.UI.Order or 99) or 99
            local ob = tonumber(b.meta.UI and b.meta.UI.Order or 99) or 99
            if oa ~= ob then return oa < ob end
            return a.name:lower() < b.name:lower()
        end)
        return out
    end
end

return M