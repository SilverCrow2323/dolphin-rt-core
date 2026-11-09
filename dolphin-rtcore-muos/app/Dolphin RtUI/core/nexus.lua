-- core/nexus.lua — central screen and action registry for Rt:UI.
--
-- NEXUS is deliberately UI-toolkit agnostic. It owns stable identifiers and
-- metadata; ui/init.lua remains responsible for transitions, input and draw.
-- Actions are explicit callbacks so screens can expose capabilities without
-- duplicating navigation policy or inventing string-based dispatch.

local M = {}
local screens, actions = {}, {}

local function valid_id(id)
    return type(id) == "string" and id:match("^[%w_%-%.]+$") ~= nil
end

local function copy_meta(meta)
    local out = {}
    if type(meta) == "table" then
        for k, v in pairs(meta) do
            if type(k) == "string" and
               (type(v) == "string" or type(v) == "number" or type(v) == "boolean") then
                out[k] = v
            end
        end
    end
    return out
end

function M.register_screen(id, screen, metadata)
    if not valid_id(id) then return false, "invalid screen id" end
    if type(screen) ~= "table" then return false, "screen module must be a table" end
    if screens[id] then return false, "screen already registered: " .. id end
    screens[id] = { id = id, module = screen, metadata = copy_meta(metadata) }
    screens[id].metadata.id = id
    return true
end

function M.get_screen(id)
    local entry = screens[id]
    return entry and entry.module or nil
end

function M.has_screen(id)
    return screens[id] ~= nil
end

function M.screen_info(id)
    local entry = screens[id]
    if not entry then return nil end
    local out = copy_meta(entry.metadata)
    out.id = entry.id
    return out
end

function M.list_screens()
    local out = {}
    for id, entry in pairs(screens) do
        out[#out + 1] = { id = id, metadata = copy_meta(entry.metadata) }
    end
    table.sort(out, function(a, b)
        local ao, bo = tonumber(a.metadata.order) or 1000, tonumber(b.metadata.order) or 1000
        if ao == bo then return a.id < b.id end
        return ao < bo
    end)
    return out
end

function M.register_actions(entries)
    if type(entries) ~= "table" then return false, "action batch must be a table" end
    local pending, seen = {}, {}
    for index = 1, #entries do
        local entry = entries[index]
        if type(entry) ~= "table" then
            return false, "action batch entry must be a table"
        end
        local id, callback = entry.id, entry.callback
        if not valid_id(id) then return false, "invalid action id" end
        if type(callback) ~= "function" then
            return false, "action callback must be a function"
        end
        if actions[id] or seen[id] then
            return false, "action already registered: " .. id
        end
        seen[id] = true
        pending[#pending + 1] = {
            id = id, run = callback, metadata = copy_meta(entry.metadata),
        }
    end

    -- Validate the complete batch before mutating the registry. A failed
    -- adapter can never leave a partially registered action set behind.
    for _, entry in ipairs(pending) do
        entry.metadata.id = entry.id
        actions[entry.id] = entry
    end
    return true, #pending
end

function M.register_action(id, callback, metadata)
    return M.register_actions({ {
        id = id, callback = callback, metadata = metadata,
    } })
end

function M.has_action(id)
    return actions[id] ~= nil
end

function M.run_action(id, ...)
    local entry = actions[id]
    if not entry then return false, "unknown action: " .. tostring(id) end
    local ok, result, detail = pcall(entry.run, ...)
    if not ok then return false, tostring(result) end
    if result == false then return false, detail or "action rejected" end
    return true, result, detail
end

function M.list_actions()
    local out = {}
    for id, entry in pairs(actions) do
        out[#out + 1] = { id = id, metadata = copy_meta(entry.metadata) }
    end
    table.sort(out, function(a, b)
        local ao, bo = tonumber(a.metadata.order) or 1000, tonumber(b.metadata.order) or 1000
        if ao == bo then return a.id < b.id end
        return ao < bo
    end)
    return out
end

function M.clear()
    screens, actions = {}, {}
end

return M
