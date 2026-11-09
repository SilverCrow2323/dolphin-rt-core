-- Run with: luajit tests/test_nexus_diagnostics.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local Diagnostics = require("core.nexus_diagnostics")

local function eq(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " ..
        tostring(expected) .. ", got " .. tostring(actual))
end

local clean = Diagnostics.inspect({
    screens = {
        { id = "library", metadata = { title = "Library" } },
        { id = "settings", metadata = { title = "Settings" } },
    },
    actions = {
        { id = "navigation.go.library", metadata = { group = "navigation", screen = "library" } },
        { id = "navigation.go.settings", metadata = { group = "navigation", screen = "settings" } },
        { id = "library.rescan", metadata = { group = "library" } },
    },
})
eq(clean.ok, true, "valid registry passes")
eq(clean.screen_count, 2, "screen count")
eq(clean.action_count, 3, "action count")
eq(clean.navigation_count, 2, "navigation count")
eq(#clean.issues, 0, "no issues")
eq(clean.screens[1].navigation_action_valid, true, "navigation metadata valid")
eq(Diagnostics.format(clean):find("\nStatus:", 1, true) ~= nil, true, "formatted report uses real line breaks")

local broken = Diagnostics.inspect({
    screens = {
        { id = "library", metadata = {} },
        { id = "orphan", metadata = {} },
    },
    actions = {
        { id = "navigation.go.library", metadata = { group = "navigation", screen = "library" } },
        { id = "shortcut.bad", metadata = { group = "shortcut", screen = "missing" } },
    },
})
eq(broken.ok, false, "broken registry fails")
eq(#broken.issues, 2, "both defects detected")
eq(broken.issues[1].code, "missing_navigation_action", "missing route classified")
eq(broken.issues[2].code, "unknown_action_screen", "unknown target classified")

local wrong_route = Diagnostics.inspect({
    screens = { { id = "library", metadata = {} } },
    actions = { { id = "navigation.go.library", metadata = { group = "shortcut", screen = "elsewhere" } } },
})
eq(wrong_route.ok, false, "misdirected navigation fails")
eq(wrong_route.issues[1].code, "invalid_navigation_action", "misdirected route classified")
eq(wrong_route.screens[1].navigation_action_valid, false, "invalid route is not marked healthy")

local invalid_entries = Diagnostics.inspect({
    screens = { false, { id = "" }, { id = "library" }, { id = "library" } },
    actions = {},
})
eq(invalid_entries.ok, false, "invalid registry entries fail")
eq(invalid_entries.issues[1].code, "invalid_screen_entries", "invalid screen entries classified")
eq(invalid_entries.issues[1].message:match(": 3$") ~= nil, true, "empty, malformed, and duplicate IDs are all rejected")

local sparse = Diagnostics.inspect({
    screens = {
        [1] = { id = "library" },
        [3] = { id = "orphan" },
        unexpected = { id = "hidden" },
    },
    actions = {},
})
eq(sparse.ok, false, "sparse and keyed catalogs fail closed")
eq(sparse.issues[1].code, "invalid_screen_entries", "sparse screen array classified")
eq(sparse.issues[1].message:match(": 2$") ~= nil, true, "array hole and non-array key detected")

local invalid_actions = Diagnostics.inspect({
    screens = { { id = "library" } },
    actions = {
        { id = "navigation.go.library", metadata = { group = "navigation", screen = "library" } },
        { id = "" },
        { id = "not valid" },
        { id = "shortcut.valid" },
        { id = "shortcut.valid" },
    },
})
eq(invalid_actions.ok, false, "invalid action identifiers fail closed")
eq(invalid_actions.issues[1].code, "invalid_action_entries", "invalid action entries classified")
eq(invalid_actions.issues[1].message:match(": 3$") ~= nil, true, "empty, malformed, and duplicate action IDs rejected")

local empty = Diagnostics.inspect({ screens = {}, actions = {} })
eq(empty.ok, false, "empty registry fails closed")
eq(empty.screen_count, 0, "empty screen count")
eq(empty.issues[1].code, "empty_catalog", "empty registry classified")

local missing = Diagnostics.inspect(nil)
eq(missing.ok, false, "missing catalog fails closed")
eq(#missing.issues, 1, "missing catalog reports one issue")
eq(missing.issues[1].code, "invalid_catalog", "missing catalog classified")

local malformed = Diagnostics.inspect({ screens = {}, actions = false })
eq(malformed.ok, false, "malformed catalog fails closed")
eq(malformed.issues[1].code, "invalid_catalog", "malformed catalog classified")
assert(Diagnostics.format(broken):match("ATTENTION REQUIRED"), "formatted report includes status")
assert(Diagnostics.format(broken):match("unknown_action_screen"), "formatted report includes issue")
print("NEXUS diagnostics: all tests passed")
