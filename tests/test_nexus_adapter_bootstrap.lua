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
            if id == "rt_profiles" then return nil end -- legacy adapters may return nothing
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

eq(stats.attempted, 20, "every manifest adapter is attempted")
eq(stats.registered, 16, "successful adapters")
eq(stats.missing, 2, "missing adapters")
eq(stats.failed, 2, "failed adapters")
eq(#calls, 18, "later adapters continue after failures")
eq(calls[1], "library", "manifest order preserved")
eq(calls[#calls], "diagnostics", "last adapter still runs")
eq(#errors, 2, "both failures reported")
eq(errors[1].id, "rt_editor", "exception reported")
eq(errors[2].id, "settings", "explicit rejection reported")

-- Lookup failures count as failed attempts, and a broken diagnostic sink must
-- not interrupt the remaining manifest entries.
local lookup_stats = Bootstrap.register(function(id)
    if id == "library" then error("synthetic lookup crash") end
    return nil
end, "unused", function()
    error("synthetic diagnostic sink crash")
end)
eq(lookup_stats.attempted, 20, "lookup pass attempts every adapter")
eq(lookup_stats.failed, 1, "lookup exception counted as failure")
eq(lookup_stats.missing, 19, "remaining missing adapters counted")
eq(lookup_stats.registered, 0, "no adapters registered in lookup pass")

print("NEXUS adapter bootstrap: all tests passed")
