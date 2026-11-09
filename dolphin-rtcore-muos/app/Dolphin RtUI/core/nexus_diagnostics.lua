-- core/nexus_diagnostics.lua — read-only integrity checks for the NEXUS registry.
-- Consumes only the public catalog; never invokes callbacks or mutates registry state.

local M = {}

local function index_by_id(entries)
    local out, invalid = {}, 0
    for _, entry in ipairs(entries) do
        if type(entry) ~= "table" or type(entry.id) ~= "string" or entry.id == "" then
            invalid = invalid + 1
        elseif out[entry.id] then
            invalid = invalid + 1
        else
            out[entry.id] = entry
        end
    end
    return out, invalid
end

function M.inspect(catalog)
    local valid = type(catalog) == "table" and
        type(catalog.screens) == "table" and type(catalog.actions) == "table"
    if not valid then catalog = { screens = {}, actions = {} } end

    local screens, bad_screens = index_by_id(catalog.screens)
    local actions, bad_actions = index_by_id(catalog.actions)
    local report = {
        ok = true, screen_count = 0, action_count = 0, navigation_count = 0,
        issues = {}, screens = {}, actions = {},
    }
    local function issue(code, message, subject)
        report.ok = false
        report.issues[#report.issues + 1] = {
            code = code, message = message, subject = subject,
        }
    end

    if not valid then
        issue("invalid_catalog", "NEXUS catalog must provide screens and actions tables", "catalog")
    end
    if bad_screens > 0 then
        issue("invalid_screen_entries", "Screen catalog contains invalid or duplicate entries: " .. bad_screens, "screens")
    end
    if bad_actions > 0 then
        issue("invalid_action_entries", "Action catalog contains invalid or duplicate entries: " .. bad_actions, "actions")
    end

    for id, entry in pairs(screens) do
        report.screen_count = report.screen_count + 1
        local metadata = type(entry.metadata) == "table" and entry.metadata or {}
        local route_id = "navigation.go." .. id
        local route = actions[route_id]
        local route_meta = route and type(route.metadata) == "table" and route.metadata or {}
        local route_ok = route ~= nil and route_meta.screen == id and route_meta.group == "navigation"
        report.screens[#report.screens + 1] = {
            id = id, title = metadata.title or id, has_navigation_action = route ~= nil,
            navigation_action_valid = route_ok,
        }
        if not route then
            issue("missing_navigation_action", "Screen has no generated navigation action: " .. id, id)
        elseif not route_ok then
            issue("invalid_navigation_action", "Navigation action metadata does not match screen: " .. id, route_id)
        end
    end

    for id, entry in pairs(actions) do
        report.action_count = report.action_count + 1
        local metadata = type(entry.metadata) == "table" and entry.metadata or {}
        local target = metadata.screen
        local valid_target = target == nil or screens[target] ~= nil
        if metadata.group == "navigation" then report.navigation_count = report.navigation_count + 1 end
        report.actions[#report.actions + 1] = {
            id = id, title = metadata.title or id, group = metadata.group or "other",
            screen = target, valid_target = valid_target,
        }
        if not valid_target then
            issue("unknown_action_screen", "Action references an unregistered screen: " .. tostring(target), id)
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
    report = type(report) == "table" and report or M.inspect(nil)
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
