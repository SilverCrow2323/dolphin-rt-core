-- core/nexus_adapters.lua — ordered, fault-isolated NEXUS screen adapters.
--
-- Keep adapter ownership explicit: this manifest is the source of truth for
-- which screens publish actions during UI bootstrap. A broken adapter must
-- never prevent later screens or core navigation actions from registering.

local M = {}

local ADAPTERS = {
    "library",
    "rt_profiles",
    "rt_editor",
    "gameset_browser",
    "gameset_explorer",
    "settings",
    "mods",
    "folders",
    "compat_list",
    "triage",
    "controller_profiles",
    "controller_map",
    "cheatdb",
    "stream_library",
    "stream_settings",
    "keymap",
    "game",
    "cheats",
    "hotkeys",
    "diagnostics",
}

function M.list()
    local out = {}
    for i, id in ipairs(ADAPTERS) do out[i] = id end
    return out
end

-- get_screen(id) returns the registered screen module. report(id, reason)
-- receives missing/failed adapter diagnostics. The UI object is passed as the
-- sole argument, preserving the existing screen.register_actions(UI) API.
function M.register(get_screen, ui, report)
    assert(type(get_screen) == "function", "get_screen must be a function")
    local stats = { attempted = 0, registered = 0, missing = 0, failed = 0 }

    for _, screen_id in ipairs(ADAPTERS) do
        stats.attempted = stats.attempted + 1
        local ok_get, screen = pcall(get_screen, screen_id)
        if not ok_get then
            stats.failed = stats.failed + 1
            if report then pcall(report, screen_id, screen) end
        elseif type(screen) ~= "table" or type(screen.register_actions) ~= "function" then
            stats.missing = stats.missing + 1
            if report then pcall(report, screen_id, "adapter unavailable") end
        else
            local staged, staged_ids, stage_error = {}, {}, nil
            local adapter_ui = setmetatable({
                register_action = function(id, callback, metadata)
                    if staged_ids[id] then
                        stage_error = "action already staged: " .. tostring(id)
                        return false, stage_error
                    end
                    staged_ids[id] = true
                    staged[#staged + 1] = {
                        id = id, callback = callback, metadata = metadata,
                    }
                    return true
                end,
            }, { __index = ui })

            local ok, result, detail = pcall(screen.register_actions, adapter_ui)
            local committed, commit_result, commit_detail = false, false, nil
            if ok and result ~= false and not stage_error then
                if type(ui.register_actions) == "function" then
                    committed, commit_result, commit_detail = pcall(ui.register_actions, staged)
                    committed = committed and commit_result ~= false
                else
                    commit_detail = "atomic action batch registrar unavailable"
                end
            end

            if not ok or result == false or stage_error or not committed then
                stats.failed = stats.failed + 1
                if report then
                    local reason
                    if not ok then reason = result
                    elseif stage_error then reason = stage_error
                    elseif result == false then reason = detail or "adapter rejected registration"
                    else reason = commit_detail or "adapter action batch rejected" end
                    pcall(report, screen_id, reason)
                end
            else
                stats.registered = stats.registered + 1
            end
        end
    end

    return stats
end

return M
