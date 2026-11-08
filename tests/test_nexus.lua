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
local ok, value = Nexus.run_action("library.rescan", "deep")
eq(ok, true, "run action")
eq(value, "deep", "action return value")
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
print("NEXUS registry: all tests passed")
