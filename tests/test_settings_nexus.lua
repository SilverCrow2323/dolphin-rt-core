-- Run with: luajit tests/test_settings_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path
local profile_mode, ensure_calls = 1, 0
local apply_calls = {}
package.preload["ui.kit"] = function()
    return { List = function() return { items = {}, set = function(self, items) self.items = items end } end,
        ACC = {}, C = {}, W = 640, BOT = 440, MARGIN = 20 }
end
package.preload["ui.sfx"] = function() return {} end
package.preload["ui.util"] = function() return {} end
package.preload["ui.notify"] = function() return { show = function() end } end
package.preload["core.settings"] = function() return { get = function() end, set = function() return true end } end
package.preload["core.library"] = function() return { games = {} } end
package.preload["core.rtcheats"] = function() return {} end
package.preload["core.rtcore_triage"] = function() return { scan = function() return {} end } end
package.preload["core.updater"] = function()
    return { latest = function() end, poll = function() end, check_async = function() end }
end
package.preload["core.muos"] = function()
    return {
        ensure = function() ensure_calls = ensure_calls + 1; return true, "registration is consistent" end,
        profile_mode_id = function() return profile_mode end,
        profile_mode = function() return profile_mode == 2 and "All Tiers" or "Standard Only" end,
        apply_profile_mode = function(mode)
            local value = tonumber(mode)
            if value ~= 1 and value ~= 2 then return false, "profile mode must be 1 or 2" end
            profile_mode = value; apply_calls[#apply_calls + 1] = value
            return true, "profile visibility updated"
        end,
    }
end
local Screen = require("ui.screens.settings")
local actions = {}
local UI = {
    register_action = function(id, run, metadata)
        if actions[id] then return false, "duplicate action: " .. id end
        actions[id] = { run = run, metadata = metadata }; return true
    end,
    go = function() return true end,
}
local ok, err = Screen.register_actions(UI)
assert(ok, err)
for _, id in ipairs({ "muos.registration.ensure", "muos.profiles.mode", "muos.profiles.set_mode" }) do
    assert(actions[id], "missing NEXUS action: " .. id)
end
assert(actions["muos.registration.ensure"].metadata.group == "system")
assert(actions["muos.registration.ensure"].run() and ensure_calls == 1)
local mode = actions["muos.profiles.mode"].run()
assert(mode.mode == 1 and mode.label == "Standard Only")
assert(actions["muos.profiles.set_mode"].run(2))
assert(profile_mode == 2 and apply_calls[1] == 2)
mode = actions["muos.profiles.mode"].run()
assert(mode.mode == 2 and mode.label == "All Tiers")
local bad, reason = actions["muos.profiles.set_mode"].run(3)
assert(bad == false and tostring(reason):match("1 or 2") and profile_mode == 2)
print("Settings NEXUS action contract: all tests passed")
