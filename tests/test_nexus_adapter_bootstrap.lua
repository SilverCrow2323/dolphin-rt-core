-- Run with: luajit tests/test_nexus_adapter_bootstrap.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local Bootstrap = require("core.nexus_adapters")

local function eq(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " ..
        tostring(expected) .. ", got " .. tostring(actual))
end

local manifest = Bootstrap.list()
eq(#manifest, 20, "adapter manifest size")
eq(manifest[1], "library", "first adapter")
eq(manifest[#manifest], "diagnostics", "last adapter")
manifest[1] = "tampered"
eq(Bootstrap.list()[1], "library", "manifest is defensive")

local calls, errors = {}, {}
local screens = {}
for _, id in ipairs(Bootstrap.list()) do
    screens[id] = {
        register_actions = function(ui)
            eq(ui, "ui-context", id .. " receives UI context")
            calls[#calls + 1] = id
            if id == "rt_editor" then error("synthetic adapter crash") end
            if id == "settings" then return false, "synthetic rejection" end
            return true
        end,
    }
end
screens.mods = nil
screens.folders = nil
local stats = Bootstrap.register(function(id)
    return screens[id]
end, "ui-context", function(id, reason)
    errors[#errors + 1] = { id = id, reason = tostring(reason) }
end)

eq(stats.attempted, 18, "available adapters attempted")
eq(stats.registered, 16, "successful adapters")
eq(stats.missing, 2, "missing adapters")
eq(stats.failed, 2, "failed adapters")
eq(#calls, 18, "later adapters continue after failures")
eq(calls[1], "library", "manifest order preserved")
eq(calls[#calls], "diagnostics", "last adapter still runs")
eq(#errors, 2, "both failures reported")
eq(errors[1].id, "rt_editor", "exception reported")
eq(errors[2].id, "settings", "explicit rejection reported")

print("NEXUS adapter bootstrap: all tests passed")
