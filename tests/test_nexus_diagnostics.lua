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

local empty = Diagnostics.inspect(nil)
eq(empty.ok, true, "empty catalog is safe")
eq(empty.screen_count, 0, "empty screen count")
assert(Diagnostics.format(broken):match("ATTENTION REQUIRED"), "formatted report includes status")
assert(Diagnostics.format(broken):match("unknown_action_screen"), "formatted report includes issue")
print("NEXUS diagnostics: all tests passed")
