-- Run with: luajit tests/test_nexus_adapter_integration.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local function eq(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " ..
        tostring(expected) .. ", got " .. tostring(actual))
end

love = { fps_cap = 60 }

package.preload["core.state"] = function() return {} end
package.preload["ui.input"] = function()
    return { from_raw = function(value) return value end,
             from_gamepad = function(value) return value end }
end
package.preload["ui.kit"] = function()
    return { W = 640, H = 480, update = function() end,
             set_palette = function() end }
end
package.preload["ui.modal"] = function()
    return { update = function() end, is_open = function() return false end }
end
package.preload["ui.notify"] = function()
    return { show = function() end }
end
package.preload["core.settings"] = function()
    return { get = function() return nil end }
end
package.preload["ui.system_panel"] = function()
    return { init = function() end, open = function() end,
             is_open = function() return false end, update = function() end }
end
package.preload["ui.sfx"] = function()
    return { set_enabled = function() end }
end
package.preload["core.cover_loader"] = function()
    return { update = function() end }
end
package.preload["ui.statusbar"] = function()
    return { update = function() end }
end

local screen_ids = {
    "boot", "library", "mods", "cheatdb", "game", "cheats", "hotkeys",
    "settings", "rt_editor", "folders", "about", "diagnostics",
    "controller_map", "controller_profiles", "triage", "rt_profiles",
    "gameset_browser", "keymap", "gameset_explorer", "compat_list",
    "stream_library", "stream_settings",
}

local adapter_ids = {
    "library", "rt_profiles", "rt_editor", "gameset_browser",
    "gameset_explorer", "settings", "mods", "folders", "compat_list",
    "triage", "controller_profiles", "controller_map", "cheatdb",
    "stream_library", "stream_settings", "keymap", "game", "cheats",
    "hotkeys", "diagnostics",
}

local adapter_set = {}
for _, id in ipairs(adapter_ids) do adapter_set[id] = true end

for _, id in ipairs(screen_ids) do
    local screen_id = id
    package.preload["ui.screens." .. screen_id] = function()
        local screen = {}
        if adapter_set[screen_id] then
            screen.register_actions = function(ui)
                return ui.register_action(
                    "integration." .. screen_id,
                    function() return true end,
                    { title = screen_id, group = "integration", screen = screen_id }
                )
            end
        end
        return screen
    end
end

local UI = require("ui.init")
local Nexus = require("core.nexus")
local Bootstrap = require("core.nexus_adapters")

UI.init()

local manifest = Bootstrap.list()
eq(#manifest, 20, "manifest contains twenty adapters")
local registered = 0
for _, id in ipairs(manifest) do
    eq(adapter_set[id], true, "manifest entry has an integration fixture")
    eq(Nexus.has_action("integration." .. id), true,
       "adapter action registered for " .. id)
    registered = registered + 1
end
eq(registered, 20, "all adapter actions registered")

for _, id in ipairs(screen_ids) do
    eq(Nexus.has_action("navigation.go." .. id), true,
       "navigation action retained for " .. id)
end
eq(Nexus.has_action("navigation.back"), true, "Back action retained")
eq(Nexus.has_action("navigation.open_library"), true, "Open Library action retained")
eq(Nexus.has_action("system.open_drawer"), true, "system drawer action retained")

local catalog = UI.catalog()
local action_ids = {}
for _, entry in ipairs(catalog.actions) do
    assert(not action_ids[entry.id], "duplicate action in catalog: " .. tostring(entry.id))
    action_ids[entry.id] = true
end

print("NEXUS adapter integration: all tests passed")
