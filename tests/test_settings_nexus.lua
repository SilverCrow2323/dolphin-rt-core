package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path
local values = { core_profile_mode = 1 }
local applied, navigated, notices = {}, {}, {}
package.preload["ui.kit"] = function()
    return { List = function() return { items = {}, set = function(self, items) self.items = items end } end,
             ACC = {}, C = {}, W = 640, BOT = 440, MARGIN = 20 }
end
package.preload["ui.sfx"] = function() return {} end
package.preload["ui.util"] = function() return {} end
package.preload["ui.notify"] = function()
    return { show = function(...) notices[#notices + 1] = { ... } end }
end
package.preload["core.settings"] = function()
    return { get = function(k) return values[k] end,
             set = function(k, v) values[k] = v; return true end }
end
package.preload["core.library"] = function() return { games = {} } end
package.preload["core.rtcheats"] = function() return {} end
package.preload["core.rtcore_triage"] = function() return { scan = function() return {} end } end
package.preload["core.updater"] = function()
    return { latest = function() end, poll = function() end, check_async = function() end }
end
package.preload["core.muos_tools"] = function()
    return { apply = function(mode) applied[#applied + 1] = mode; return true, "OK" end }
end

local Screen = require("ui.screens.settings")
local actions = {}
local UI = {
    register_action = function(id, run, meta)
        actions[id] = { run = run, meta = meta }
        return true
    end,
    go = function(screen, params)
        navigated[#navigated + 1] = { screen, params }
        return true
    end,
}
local ok, err = Screen.register_actions(UI)
assert(ok, err)
for _, id in ipairs({
    "settings.set_profile_catalogue_mode",
    "settings.apply_profile_catalogue",
    "settings.register_muos_cores",
    "settings.open_folder_registration",
    "settings.open_z_folder_audit",
    "settings.open_gamesettings_database",
    "settings.open_assign_audit",
}) do
    assert(actions[id], "missing NEXUS action: " .. id)
end
assert(actions["settings.set_profile_catalogue_mode"].run(2))
assert(values.core_profile_mode == 2, "catalogue mode must persist")
assert(actions["settings.apply_profile_catalogue"].run())
assert(applied[1] == 2, "profile apply must use selected mode")
assert(actions["settings.register_muos_cores"].run())
assert(applied[2] == nil, "core registration uses default manifest apply")
assert(actions["settings.open_z_folder_audit"].run())
assert(navigated[#navigated][1] == "folders" and navigated[#navigated][2].zscan == true)
assert(actions["settings.open_gamesettings_database"].run())
assert(navigated[#navigated][1] == "gameset_browser")
local bad = actions["settings.set_profile_catalogue_mode"].run(3)
assert(bad == false, "invalid profile mode must be rejected")
print("Settings NEXUS actions: OK")
