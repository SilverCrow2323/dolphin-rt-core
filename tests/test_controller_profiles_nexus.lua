-- Run with: luajit tests/test_controller_profiles_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local current_system = "GameCube"
local opened, accents, sounds = {}, {}, 0
local directories = {
    GameCube = {
        "workshop/controller/GameCube/Default/",
        "workshop/controller/GameCube/Arcade_2/",
        "workshop/controller/GameCube/Bad Profile/",
    },
    Wii = {
        "workshop/controller/Wii/Default/",
        "workshop/controller/Wii/Wii_Alt/",
    },
}
love = {
    graphics = {
        newImage = function() error("preview image is unavailable in this test") end,
    },
}

local old_popen = io.popen
io.popen = function(command)
    local system = command:match("workshop/controller/([^/]+)/")
    current_system = system
    local values = directories[system] or {}
    local index = 0
    local handle = {}
    function handle:lines()
        return function()
            index = index + 1
            return values[index]
        end
    end
    function handle:close() end
    return handle
end

package.preload["ui.kit"] = function()
    local function list()
        local value = { items = {}, sel = 1 }
        function value:set(items) self.items = items; self.sel = 1 end
        function value:cur() return self.items[self.sel] end
        function value:update() end
        function value:move(direction)
            self.sel = math.max(1, math.min(#self.items, self.sel + direction))
            return true
        end
        function value:_aim() end
        return value
    end
    return {
        W = 640, H = 480, MARGIN = 20, BOT = 460,
        ACC = { gc = {}, wii = {} }, C = {},
        List = list,
        set_accent = function(value) accents[#accents + 1] = value end,
        bg = function() end, header = function() end, text = function() end,
        panel = function() end, color = function() end, footer = function() end,
        width = function() return 10 end, clip = function(_, value) return value end,
        draw_tool_icon = function() end,
    }
end
package.preload["ui.sfx"] = function() return { play = function() sounds = sounds + 1 end } end
package.loaded["ui"] = {
    go = function(screen, params)
        opened[#opened + 1] = { screen = screen, params = params }
        return true
    end,
}

local Screen = require("ui.screens.controller_profiles")
local actions = {}
local UI = {
    register_action = function(id, run, metadata)
        if actions[id] then return false, "duplicate action" end
        actions[id] = { run = run, metadata = metadata }
        return true
    end,
}
local registered, register_err = Screen.register_actions(UI)
assert(registered, register_err)
for _, id in ipairs({
    "controller_profiles.refresh",
    "controller_profiles.switch_system",
    "controller_profiles.select",
    "controller_profiles.open_selected",
    "controller_profiles.state",
}) do
    assert(actions[id], "missing action " .. id)
end

Screen.enter()
local state = actions["controller_profiles.state"].run()
assert(state.system == "GameCube" and state.profile_count == 2)
assert(state.selected_profile == "Arcade_2" or state.selected_profile == "Default")
assert(state.selected_directory == nil, "state must not expose filesystem paths")

local selected_name = state.selected_profile
local bad_system, bad_system_err = actions["controller_profiles.switch_system"].run("../outside")
assert(bad_system == false and tostring(bad_system_err):match("GameCube or Wii"))
assert(actions["controller_profiles.select"].run(1))
assert(actions["controller_profiles.state"].run().selected_profile == "Arcade_2")
assert(actions["controller_profiles.refresh"].run())
state = actions["controller_profiles.state"].run()
assert(state.selected_profile == "Arcade_2", "refresh should preserve the selected profile")

assert(actions["controller_profiles.open_selected"].run())
assert(opened[#opened].screen == "controller_map")
assert(opened[#opened].params.system == "GameCube")
assert(opened[#opened].params.name == "Arcade_2")
assert(opened[#opened].params.dir == "workshop/controller/GameCube/Arcade_2")

local invalid_index, invalid_index_err = actions["controller_profiles.select"].run(99)
assert(invalid_index == false and tostring(invalid_index_err):match("index out of range"))

assert(actions["controller_profiles.switch_system"].run("Wii"))
state = actions["controller_profiles.state"].run()
assert(state.system == "Wii" and state.profile_count == 2)
assert(accents[#accents] == "wii" and sounds > 0)
assert(actions["controller_profiles.select"].run(2))
assert(actions["controller_profiles.open_selected"].run())
assert(opened[#opened].params.system == "Wii")
assert(opened[#opened].params.name == "Wii_Alt")

-- Switching back returns to the GameCube profile catalog without stale Wii paths.
assert(actions["controller_profiles.switch_system"].run("GameCube"))
state = actions["controller_profiles.state"].run()
assert(state.system == "GameCube" and state.profile_count == 2)
assert(actions["controller_profiles.refresh"].run())

io.popen = old_popen
print("Controller Profiles NEXUS actions: all tests passed")
