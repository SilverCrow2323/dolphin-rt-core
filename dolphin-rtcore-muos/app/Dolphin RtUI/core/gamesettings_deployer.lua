-- core/gamesettings_deployer.lua — incremental deployment of bundled GameSettings.
local M = {}

local Loader = require("core.gameset_loader")
local STATE = {
    running = false, queue = {}, index = 1,
    total = 0, processed = 0, deployed = 0, failed = 0,
}

local function normalize_id(value)
    local id = type(value) == "table" and value.id or value
    if type(id) ~= "string" or not id:match("^[A-Z0-9]+$") then return nil end
    return id
end

function M.start()
    STATE = {
        running = true, queue = {}, index = 1,
        total = 0, processed = 0, deployed = 0, failed = 0,
    }

    local ok, data = pcall(Loader.load)
    if not ok or type(data) ~= "table" or type(data.games) ~= "table" then
        STATE.running = false
        STATE.failed = 1
        return false, "GameSettings database unavailable"
    end

    local seen = {}
    for _, entry in ipairs(data.games) do
        if type(entry) == "table" and type(entry.configs) == "table" then
            for _, raw_id in ipairs(entry.ids or {}) do
                local id = normalize_id(raw_id)
                if id and not seen[id] then
                    seen[id] = true
                    STATE.queue[#STATE.queue + 1] = { entry = entry, id = id }
                end
            end
        end
    end
    STATE.total = #STATE.queue
    if STATE.total == 0 then STATE.running = false end
    return true
end

function M.poll()
    if STATE.running then
        local item = STATE.queue[STATE.index]
        if item then
            local ok, written, failed = pcall(Loader.deploy, item.entry, item.id)
            STATE.processed = STATE.processed + 1
            if ok then
                STATE.deployed = STATE.deployed + (tonumber(written) or 0)
                STATE.failed = STATE.failed + (tonumber(failed) or 0)
            else
                STATE.failed = STATE.failed + 1
            end
            STATE.index = STATE.index + 1
        end
        if STATE.index > #STATE.queue then STATE.running = false end
    end

    return not STATE.running, {
        deployed = STATE.deployed,
        processed = STATE.processed,
        total = STATE.total,
        failed = STATE.failed,
        status = STATE.running and "running" or (STATE.failed > 0 and "partial" or "complete"),
    }
end

function M.reset()
    STATE = {
        running = false, queue = {}, index = 1,
        total = 0, processed = 0, deployed = 0, failed = 0,
    }
end

return M
