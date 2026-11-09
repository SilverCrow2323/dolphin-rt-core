-- core/nexus_diagnostics.lua — read-only integrity checks for the NEXUS registry.
--
-- The module deliberately consumes the public NEXUS catalog instead of
-- reaching into registry internals. It can therefore be used by the UI,
-- automated tests and future support bundles without mutating application state.

local M = {}

local function index_by_id(entries)
    local out = {}
    for _, entry in ipairs(type(entries) == "table" and entries or {}) do
        if type(entry) == "table" and type(entry.id) == "string" then
            out[entry.id] = entry
        end
    end
    return out
end

function M.inspect(catalog)
    catalog = type(catalog) == "table" and catalog or {}
    local screens = index_by_id(catalog.screens)
    local actions = index_by_id(catalog.actions)
    local report = {
        ok = true,
        screen_count = 0,
        action_count = 0,
        navigation_count = 0,
        issues = {},
        screens = {},
        actions = {},
    }

    local function issue(code, message, subject)
        report.ok = false
        report.issues[#report.issues + 1] = {
            code = code,
            message = message,
            subject = subject,
        }
    end

    for id, entry in pairs(screens) do
        report.screen_count = report.screen_count + 1
        local metadata = type(entry.metadata) == "table" and entry.metadata or {}
        local route_id = "navigation.go." .. id
        local has_route = actions[route_id] ~= nil
        report.screens[#report.screens + 1] = {
            id = id,
            title = metadata.title or id,
            has_navigation_action = has_route,
        }
        if not has_route then
            issue("missing_navigation_action",
                "Screen has no generated navigation action: " .. id, id)
        end
    end

    for id, entry in pairs(actions) do
        report.action_count = report.action_count + 1
        local metadata = type(entry.metadata) == "table" and entry.metadata or {}
        local target = metadata.screen
        local valid_target = target == nil or screens[target] ~= nil
        if metadata.group == "navigation" then
            report.navigation_count = report.navigation_count + 1
        end
        report.actions[#report.actions + 1] = {
            id = id,
            title = metadata.title or id,
            group = metadata.group or "other",
            screen = target,
            valid_target = valid_target,
        }
        if not valid_target then
            issue("unknown_action_screen",
                "Action references an unregistered screen: " .. tostring(target), id)
        end
    end

    table.sort(report.screens, function(a, b) return a.id < b.id end)
    table.sort(report.actions, function(a, b) return a.id < b.id end)
    table.sort(report.issues, function(a, b)
        if a.code == b.code then return tostring(a.subject) < tostring(b.subject) end
        return a.code < b.code
    end)
    return report
end

function M.format(report)
    report = type(report) == "table" and report or M.inspect({})
    local lines = {
        "Dolphin Rt:UI — NEXUS integrity report",
        "Status: " .. (report.ok and "PASS" or "ATTENTION REQUIRED"),
        "Screens: " .. tostring(report.screen_count or 0),
        "Actions: " .. tostring(report.action_count or 0),
        "Navigation actions: " .. tostring(report.navigation_count or 0),
        "Issues: " .. tostring(#(report.issues or {})),
    }
    for _, item in ipairs(report.issues or {}) do
        lines[#lines + 1] = "[" .. tostring(item.code) .. "] " ..
            tostring(item.subject or "-") .. ": " .. tostring(item.message)
    end
    return table.concat(lines, "\n")
end

return M
