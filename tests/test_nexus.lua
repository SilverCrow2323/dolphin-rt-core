-- Run with: luajit tests/test_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local Nexus = require("core.nexus")
local function eq(a, b, label)
    assert(a == b, (label or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

Nexus.clear()
local library = { enter = function() end, draw = function() end }
eq(Nexus.register_screen("library", library, { title = "Game Library", order = 10 }), true, "register screen")
eq(Nexus.get_screen("library"), library, "resolve screen")
eq(Nexus.has_screen("library"), true, "has screen")
local duplicate, duplicate_err = Nexus.register_screen("library", {}, {})
eq(duplicate, false, "reject duplicate screen")
assert(duplicate_err:match("already registered"), "duplicate screen explains conflict")
local invalid = Nexus.register_screen("../library", library, {})
eq(invalid, false, "reject invalid screen id")
eq(Nexus.get_screen("missing"), nil, "missing screen")

Nexus.register_screen("settings", {}, { title = "Settings", order = 20 })
local screens = Nexus.list_screens()
eq(#screens, 2, "screen catalog size")
eq(screens[1].id, "library", "screen order")
eq(screens[1].metadata.title, "Game Library", "screen metadata")

local called = 0
eq(Nexus.register_action("library.rescan", function(force)
    called = called + 1
    return true, force
end, { title = "Rescan library", group = "library" }), true, "register action")
eq(Nexus.has_action("library.rescan"), true, "has action")
local ok, value, detail = Nexus.run_action("library.rescan", "deep")
eq(ok, true, "run action")
eq(value, true, "action result")
eq(detail, "deep", "action detail")
eq(called, 1, "action called once")

local bad = Nexus.register_action("library.rescan", function() end, {})
eq(bad, false, "reject duplicate action")
Nexus.register_action("test.failure", function() error("expected failure") end, {})
local failed, reason = Nexus.run_action("test.failure")
eq(failed, false, "catch action error")
assert(tostring(reason):match("expected failure"), "action error is preserved")

local missing, missing_reason = Nexus.run_action("does.not.exist")
eq(missing, false, "unknown action")
assert(tostring(missing_reason):match("unknown action"), "unknown action is explained")

local actions = Nexus.list_actions()
eq(#actions, 2, "action catalog size")
eq(actions[1].id, "library.rescan", "action catalog sorted")

// Explicit rejection must remain distinguishable from a successful action.
Nexus.register_action("test.rejected", function(value)
    eq(value, "invalid", "rejection argument")
    return false, "input rejected"
end, { title = "Reject invalid input", order = 5 })
local rejected, rejection_reason = Nexus.run_action("test.rejected", "invalid")
eq(rejected, false, "explicit action rejection")
eq(rejection_reason, "input rejected", "explicit rejection reason")

-- Catalog metadata is scalar-only and each returned snapshot is isolated.
Nexus.register_screen("test.metadata", {}, {
    title = "Metadata screen",
    order = 7,
    enabled = true,
    nested = { private = "must not escape" },
    callback = function() end,
})
local info = Nexus.screen_info("test.metadata")
eq(info.title, "Metadata screen", "screen metadata title")
eq(info.order, 7, "screen metadata order")
eq(info.enabled, true, "screen metadata boolean")
eq(info.nested, nil, "screen metadata rejects nested tables")
eq(info.callback, nil, "screen metadata rejects functions")
info.title = "tampered"
eq(Nexus.screen_info("test.metadata").title, "Metadata screen", "screen metadata snapshot isolation")

Nexus.register_action("test.metadata", function() return true end, {
    title = "Metadata action",
    order = 8,
    enabled = false,
    nested = { private = "must not escape" },
    callback = function() end,
})
local catalog
for _, entry in ipairs(Nexus.list_actions()) do
    if entry.id == "test.metadata" then catalog = entry.metadata; break end
end
assert(catalog, "metadata action is present in the catalog")
eq(catalog.title, "Metadata action", "action metadata title")
eq(catalog.order, 8, "action metadata order")
eq(catalog.enabled, false, "action metadata boolean")
eq(catalog.nested, nil, "action metadata rejects nested tables")
eq(catalog.callback, nil, "action metadata rejects functions")
catalog.title = "tampered"
local fresh_catalog
for _, entry in ipairs(Nexus.list_actions()) do
    if entry.id == "test.metadata" then fresh_catalog = entry.metadata; break end
end
eq(fresh_catalog.title, "Metadata action", "action metadata snapshot isolation")

print("NEXUS registry: all tests passed")
