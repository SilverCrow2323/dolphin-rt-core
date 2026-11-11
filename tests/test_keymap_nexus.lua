-- Run with: luajit tests/test_keymap_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local files = {
    ["workshop/controller/GameCube/Default/GCPadNew.ini"] = {
        "[GCPad1]", "Buttons/A = Button 1", "Buttons/B = Button 2", "Triggers/L = Button 3",
    },
    ["workshop/controller/Wii/Default/WiimoteNew.ini"] = {
        "[Wiimote1]", "Buttons/A = Button 4", "Buttons/B = Button 5", "Buttons/1 = Button 6",
    },
}
local fail_write, throw_write = false, false
local notices = {}
love = { graphics = { newImage = function() error("spritesheet should not load in action tests") end } }

local function copy_lines(lines)
    local out = {}
    for i, line in ipairs(lines or {}) do out[i] = line end
    return out
end
local Ini = {
    read_lines = function(path) return copy_lines(files[path] or {}) end,
    get = function(lines, section, key)
        local current
        for _, line in ipairs(lines) do
            local found = line:match("^%s*%[([^%]]+)%]")
            if found then current = found
            elseif current == section then
                local k, value = line:match("^%s*([^=]+)%s*=%s*(.*)$")
                if k and k:match("^%s*(.-)%s*$") == key then return value end
            end
        end
        return nil
    end,
    set = function(lines, section, key, value)
        local current, found = nil, false
        for i, line in ipairs(lines) do
            local name = line:match("^%s*%[([^%]]+)%]")
            if name then current = name
            elseif current == section then
                local k = line:match("^%s*([^=]+)%s*=")
                if k and k:match("^%s*(.-)%s*$") == key then
                    lines[i] = key .. " = " .. tostring(value)
                    found = true
                    break
                end
            end
        end
        if not found then lines[#lines + 1] = key .. " = " .. tostring(value) end
    end,
    write_lines = function(path, lines)
        if throw_write then error("disk exception") end
        if fail_write then return false, "read only" end
        files[path] = copy_lines(lines)
        return true
    end,
}
package.preload["core.ini_edit"] = function() return Ini end
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
        List = list, set_accent = function() end,
    }
end
package.preload["ui.sfx"] = function() return { play = function() end } end
package.preload["ui.notify"] = function()
    return { show = function(kind, message) notices[#notices + 1] = { kind, message } end }
end
package.preload["ui.modal"] = function() return { show = function() end } end
package.loaded["ui"] = { back = function() end }

local Screen = require("ui.screens.keymap")
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
    "keymap.switch_system", "keymap.select", "keymap.start_remap",
    "keymap.capture_input", "keymap.confirm_remap", "keymap.cancel_remap",
    "keymap.state",
}) do
    assert(actions[id], "missing action " .. id)
end

Screen.enter({ system = "GameCube", profile = "Default" })
local state = actions["keymap.state"].run()
assert(state.system == "GameCube" and state.profile == "Default")
assert(state.mapping_count == 3 and state.remap_phase == nil)
assert(state.selected_key == "Buttons/A")

local bad_index, bad_index_err = actions["keymap.select"].run(99)
assert(bad_index == false and tostring(bad_index_err):match("index out of range"))
assert(actions["keymap.select"].run(2))
assert(actions["keymap.state"].run().selected_key == "Buttons/B")

assert(actions["keymap.start_remap"].run())
assert(actions["keymap.state"].run().remap_phase == "wait")
local duplicate_start, duplicate_err = actions["keymap.start_remap"].run()
assert(duplicate_start == false and tostring(duplicate_err):match("already active"))
assert(actions["keymap.select"].run(1) == false, "selection is blocked during capture")
assert(actions["keymap.switch_system"].run() == false, "system switching is blocked during capture")

local bad_string, bad_string_err = actions["keymap.capture_input"].run("7")
assert(bad_string == false and tostring(bad_string_err):match("integer"))
local bad_range, bad_range_err = actions["keymap.capture_input"].run(256)
assert(bad_range == false and tostring(bad_range_err):match("0 to 255"))
assert(actions["keymap.capture_input"].run(7))
state = actions["keymap.state"].run()
assert(state.remap_phase == "confirm" and state.captured_button == 7)
assert(state.proposed_value == "`Button 7`")

-- A failed write rolls back the in-memory INI and keeps the pending confirmation.
fail_write = true
local failed, failed_err = actions["keymap.confirm_remap"].run()
assert(failed == false and tostring(failed_err):match("read only"))
assert(actions["keymap.state"].run().remap_phase == "confirm")
assert(not table.concat(Screen.lines, "\n"):match("Buttons/B = `Button 7`"))
assert(not table.concat(files["workshop/controller/GameCube/Default/GCPadNew.ini"], "\n"):match("Buttons/B = `Button 7`"))

-- An exception during persistence is handled with the same rollback guarantee.
fail_write, throw_write = false, true
local thrown, thrown_err = actions["keymap.confirm_remap"].run()
assert(thrown == false and tostring(thrown_err):match("disk exception"))
assert(actions["keymap.state"].run().remap_phase == "confirm")
assert(not table.concat(Screen.lines, "\n"):match("Buttons/B = `Button 7`"))

throw_write = false
assert(actions["keymap.confirm_remap"].run())
state = actions["keymap.state"].run()
assert(state.remap_phase == nil and state.mapping_count == 3)
assert(table.concat(files["workshop/controller/GameCube/Default/GCPadNew.ini"], "\n"):match("Buttons/B = `Button 7`"))
assert(#notices > 0 and notices[#notices][1] == "success")

local no_cancel, no_cancel_err = actions["keymap.cancel_remap"].run()
assert(no_cancel == false and tostring(no_cancel_err):match("no controller remap"))

assert(actions["keymap.start_remap"].run())
assert(actions["keymap.capture_input"].run(8))
assert(actions["keymap.cancel_remap"].run())
assert(actions["keymap.state"].run().remap_phase == nil)
assert(actions["keymap.switch_system"].run())
state = actions["keymap.state"].run()
assert(state.system == "Wii" and state.profile == "Default" and state.mapping_count == 3)
assert(actions["keymap.select"].run(3))
assert(actions["keymap.state"].run().selected_key == "Buttons/1")

-- Entry parameters cannot be used to inject a filesystem path.
Screen.enter({ system = "Bad", profile = "../escape" })
state = actions["keymap.state"].run()
assert(state.system == "GameCube" and state.profile == "Default")
assert(Screen.path == "workshop/controller/GameCube/Default/GCPadNew.ini")

print("Controller Keymap NEXUS actions: all tests passed")
