-- Run with: luajit tests/test_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local Nexus = require("core.nexus")
local function eq(a, b, label)
    assert(a == b, (label or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

Nexus.clear()
local library = { enter = function() end, draw = function() end }
eq(Nexus.register_screen("library", library, {
    title = "Game Library", order = 10, private = { should_not_leak = true },
}), true, "register screen")
eq(Nexus.get_screen("library"), library, "resolve screen")
eq(Nexus.has_screen("library"), true, "has screen")
local duplicate, duplicate_err = Nexus.register_screen("library", {}, {})
eq(duplicate, false, "reject duplicate screen")
assert(duplicate_err:match("already registered"), "duplicate screen explains conflict")
local invalid = Nexus.register_screen("../library", library, {})
eq(invalid, false, "reject invalid screen id")
local invalid_module = Nexus.register_screen("invalid_module", "not a screen", {})
eq(invalid_module, false, "reject non-table screen module")
eq(Nexus.get_screen("missing"), nil, "missing screen")

Nexus.register_screen("settings", {}, { title = "Settings", order = 20 })
local screens = Nexus.list_screens()
eq(#screens, 2, "screen catalog size")
eq(screens[1].id, "library", "screen order")
eq(screens[1].metadata.title, "Game Library", "screen metadata")
eq(screens[1].metadata.private, nil, "screen metadata excludes nested values")
eq(Nexus.screen_info("library").title, "Game Library", "screen info")
screens[1].metadata.title = "Tampered catalog"
eq(Nexus.list_screens()[1].metadata.title, "Game Library", "screen catalog is defensive")
local screen_info = Nexus.screen_info("library")
screen_info.title = "Tampered info"
eq(Nexus.screen_info("library").title, "Game Library", "screen info is defensive")

local called = 0
eq(Nexus.register_action("library.rescan", function(force)
    called = called + 1
    return true, force
end, { title = "Rescan library", group = "library", private = { token = "hidden" } }),
    true, "register action")
eq(Nexus.has_action("library.rescan"), true, "has action")
local ok, value, detail = Nexus.run_action("library.rescan", "deep")
eq(ok, true, "run action")
eq(value, true, "action result")
eq(detail, "deep", "action detail")
eq(called, 1, "action called once")

local bad = Nexus.register_action("library.rescan", function() end, {})
eq(bad, false, "reject duplicate action")
local invalid_action_id = Nexus.register_action("bad/action", function() end, {})
eq(invalid_action_id, false, "reject invalid action id")
local invalid_callback = Nexus.register_action("test.invalid_callback", "not a callback", {})
eq(invalid_callback, false, "reject non-function callback")

local batch_ok, batch_count = Nexus.register_actions({
    { id = "batch.first", callback = function() return true end,
      metadata = { group = "batch", order = 10000 } },
    { id = "batch.second", callback = function() return true end,
      metadata = { group = "batch" } },
})
eq(batch_ok, true, "register valid action batch")
eq(batch_count, 2, "batch registration count")
eq(Nexus.has_action("batch.first"), true, "first batch action committed")
eq(Nexus.has_action("batch.second"), true, "second batch action committed")

local collision_ok = Nexus.register_actions({
    { id = "batch.third", callback = function() return true end },
    { id = "library.rescan", callback = function() return true end },
})
eq(collision_ok, false, "batch rejects existing registry collision")
eq(Nexus.has_action("batch.third"), false, "failed batch commits no earlier actions")

local duplicate_batch = Nexus.register_actions({
    { id = "batch.duplicate", callback = function() return true end },
    { id = "batch.duplicate", callback = function() return true end },
})
eq(duplicate_batch, false, "batch rejects duplicate IDs")
eq(Nexus.has_action("batch.duplicate"), false, "duplicate batch is atomic")

local invalid_batch = Nexus.register_actions({
    { id = "batch.never", callback = function() return true end },
    { id = "batch.invalid", callback = false },
})
eq(invalid_batch, false, "batch rejects invalid callback")
eq(Nexus.has_action("batch.never"), false, "invalid callback leaves batch uncommitted")

Nexus.register_action("test.failure", function() error("expected failure") end, {})
local failed, reason = Nexus.run_action("test.failure")
eq(failed, false, "catch action error")
assert(tostring(reason):match("expected failure"), "action error is preserved")

local rejected = Nexus.register_action("test.rejected", function()
    return false, "rejected by test"
end, { title = "Rejected action", private = { token = "hidden" } })
eq(rejected, true, "register rejecting action")
local rejected_ok, rejected_reason = Nexus.run_action("test.rejected")
eq(rejected_ok, false, "false callback result rejects action")
eq(rejected_reason, "rejected by test", "rejection detail is preserved")

local missing, missing_reason = Nexus.run_action("does.not.exist")
eq(missing, false, "unknown action")
assert(tostring(missing_reason):match("unknown action"), "unknown action is explained")

local actions = Nexus.list_actions()
eq(#actions, 5, "action catalog size")
eq(actions[1].id, "batch.second", "action catalog sorts by metadata order then action ID")
eq(actions[2].id, "library.rescan", "default-order action follows alphabetically")
eq(actions[5].id, "batch.first", "explicit high-order action sorts last")
local library_action
for _, entry in ipairs(actions) do
    if entry.id == "library.rescan" then library_action = entry end
end
assert(library_action, "library action remains in the catalog")
eq(library_action.metadata.private, nil, "action metadata excludes nested values")
library_action.metadata.title = "Tampered action"
local library_again
for _, entry in ipairs(Nexus.list_actions()) do
    if entry.id == "library.rescan" then library_again = entry end
end
eq(library_again.metadata.title, "Rescan library", "action catalog is defensive")

Nexus.clear()
eq(#Nexus.list_screens(), 0, "clear removes screens")
eq(#Nexus.list_actions(), 0, "clear removes actions")
eq(Nexus.has_screen("library"), false, "cleared screen is absent")
eq(Nexus.has_action("library.rescan"), false, "cleared action is absent")

print("NEXUS registry: all tests passed")
