-- Run with: luajit tests/test_profile_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local profiles = {
    { name = "Default", dir = "workshop/rtcoreprofile/Default",
      meta = { Profile = { Name = "Default", Type = "Balanced" }, Runtime = {} } },
    { name = "Fast", dir = "workshop/rtcoreprofile/Fast",
      meta = { Profile = { Name = "Fast", Type = "Performance" }, Runtime = {} } },
}
package.preload["ui.kit"] = function()
    return { W = 640, H = 480, ACC = { gc = {} }, set_accent = function() end }
end
package.preload["ui.sfx"] = function() return { play = function() end } end
package.preload["ui.notify"] = function() return { show = function() end } end
package.preload["core.profile_manager"] = function()
    return { list = function() return profiles end }
end
package.preload["core.sh"] = function()
    return { is_dir = function() return false end }
end
package.loaded["ui"] = { go = function() end, back = function() end }

local Screen = require("ui.screens.rt_profiles")
local actions = {}
local UI = {
    register_action = function(id, callback, metadata)
        if actions[id] then return false, "duplicate action" end
        actions[id] = { run = callback, metadata = metadata }
        return true
    end,
}
local ok, err = Screen.register_actions(UI)
assert(ok, err)
for _, id in ipairs({
    "profiles.refresh", "profiles.create",
    "profiles.open_selected", "profiles.open",
}) do
    assert(actions[id], "missing action: " .. id)
end

Screen.enter({})
Screen.update(1)
assert(Screen.phase == "browse", "picker should be browsable after intro")
local selected = Screen.rows[Screen.sel]
assert(selected and selected.profile, "picker should select a profile")

local opened, open_err = actions["profiles.open_selected"].run()
assert(opened, open_err)
assert(Screen.phase == "pick", "open_selected should enter pick transition")
assert(Screen.picked.name == selected.profile.name, "open_selected should retain selection")

Screen.enter({})
Screen.update(1)
local fast_index
for i, row in ipairs(Screen.rows) do
    if row.profile and row.profile.name == "Fast" then fast_index = i end
end
assert(fast_index, "Fast profile fixture should exist")
Screen.sel = fast_index
local refreshed, refresh_err = actions["profiles.refresh"].run()
assert(refreshed, refresh_err)
assert(Screen.rows[Screen.sel].profile.name == "Fast", "refresh should preserve selected profile")

local opened_by_name, name_err = actions["profiles.open"].run("Default")
assert(opened_by_name, name_err)
assert(Screen.picked.name == "Default", "open should select exact profile name")

Screen.enter({})
Screen.update(1)
local missing, missing_err = actions["profiles.open"].run("does-not-exist")
assert(missing == false, "unknown profile should be rejected")
assert(tostring(missing_err):match("not found"), "unknown profile should explain failure")

local not_ready, not_ready_err
Screen.phase = "intro"
not_ready, not_ready_err = actions["profiles.open_selected"].run()
assert(not_ready == false, "actions should reject calls outside browse phase")
assert(tostring(not_ready_err):match("not ready"), "not-ready state should be explained")

print("Profile NEXUS actions: all tests passed")
