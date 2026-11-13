-- core/cheats_downloader.lua — async adapter for scripts/rtcheats_sync.sh.
local M = {}

local Shell = require("core.sh")
local SCRIPT = Shell.abs("scripts/rtcheats_sync.sh")
local STATUS = Shell.abs("data/rtcheats_sync.status")
local RUN_TIMEOUT = 75

local STATE = {
    running = false,
    started_at = 0,
    result = nil,
}

local function normalize_ids(ids)
    local out, seen = {}, {}
    for _, raw in ipairs(type(ids) == "table" and ids or {}) do
        local id = type(raw) == "table" and raw.id or raw
        if type(id) == "string" and id:match("^[A-Z0-9]+$") and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    return out
end

local function read_status()
    local f = io.open(STATUS, "r")
    if not f then return nil end
    local raw = f:read("*a") or ""
    f:close()
    local out = {}
    for line in raw:gmatch("[^\r\n]+") do
        local key, value = line:match("^([^=]+)=(.*)$")
        if key then out[key] = value end
    end
    return out
end

function M.start_for(ids)
    if STATE.running then return false, "cheat sync already running" end

    -- No argument delegates selection to rtcheats_sync.sh, which downloads
    -- only entries marked performance_boost in the bundled index. An
    -- explicit empty list means that there are no game-specific downloads.
    local all_boost = (ids == nil)
    local wanted = normalize_ids(ids)
    if not all_boost and #wanted == 0 then
        STATE.running = false
        STATE.result = { state = "ok", msg = "no games to sync", done = 0, total = 0 }
        return true
    end

    os.remove(STATUS)
    local command = "sh " .. Shell.shq(SCRIPT)
    if not all_boost then
        for _, id in ipairs(wanted) do
            command = command .. " " .. Shell.shq(id)
        end
    end

    local ok, result = pcall(Shell.run_async, command)
    if not ok or result ~= true then
        STATE.running = false
        STATE.result = {
            state = "fail",
            msg = "could not start cheat sync",
            done = 0,
            total = #wanted,
        }
        return false, STATE.result.msg
    end

    STATE.running = true
    STATE.started_at = os.time()
    STATE.result = { state = "running", msg = "starting", done = 0, total = #wanted }
    return true
end

function M.poll()
    if not STATE.running then return true, STATE.result or { state = "ok", done = 0, total = 0 } end

    local status = read_status()
    if status then
        local result = {
            state = status.state or "running",
            msg = status.msg or "",
            done = tonumber(status.done) or 0,
            total = tonumber(status.total) or 0,
            time = tonumber(status.time),
        }
        if result.state == "ok" or result.state == "fail" then
            STATE.running = false
            STATE.result = result
            return true, result
        end
        STATE.result = result
    end

    if os.time() - STATE.started_at > RUN_TIMEOUT then
        STATE.running = false
        STATE.result = {
            state = "fail",
            msg = "cheat sync timed out",
            done = status and tonumber(status.done) or 0,
            total = status and tonumber(status.total) or 0,
        }
        return true, STATE.result
    end

    return false, STATE.result
end

function M.status()
    return STATE.result
end

function M.reset()
    STATE = { running = false, started_at = 0, result = nil }
end

return M
