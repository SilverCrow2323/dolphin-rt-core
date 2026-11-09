-- Run with: luajit tests/test_ui_navigation_contract.lua
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
             is_open = function() return false end,
             update = function() end }
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
for _, id in ipairs(screen_ids) do
    package.preload["ui.screens." .. id] = function() return {} end
end

local UI = require("ui.init")
local Nexus = require("core.nexus")
UI.init()
eq(Nexus.has_action("navigation.back"), true, "back action registered")
eq(Nexus.has_action("navigation.open_library"), true, "library action registered")

UI.go_instant("library", {})
eq(UI.current(), "library", "initial screen")
eq(UI.go("settings", {}), true, "start forward navigation")
eq(UI.is_root(), false, "forward navigation pushes history")
local instant_ok, instant_reason = UI.go_instant("missing", {})
eq(instant_ok, false, "instant navigation rejects unknown screen")
eq(instant_reason, "unknown screen", "instant navigation exposes rejection reason")
eq(UI.is_root(), false, "rejected instant navigation preserves history")

local back_ok, back_reason = Nexus.run_action("navigation.back")
eq(back_ok, false, "back action rejects during transition")
eq(back_reason, "transition in progress", "back action exposes transition reason")
eq(UI.is_root(), false, "rejected back preserves history")

local library_ok, library_reason = Nexus.run_action("navigation.open_library")
eq(library_ok, false, "open-library action rejects during transition")
eq(library_reason, "transition in progress", "open-library action exposes transition reason")
eq(UI.is_root(), false, "rejected open-library preserves history")

UI.update(0.11)
UI.update(0.16)
eq(UI.current(), "settings", "forward transition completes")
local idle_back_ok, idle_back_result = Nexus.run_action("navigation.back")
eq(idle_back_ok, true, "back action succeeds when idle")
eq(idle_back_result, true, "back callback success is propagated")
eq(UI.is_root(), true, "successful back consumes history")

print("UI navigation contract: all tests passed")
