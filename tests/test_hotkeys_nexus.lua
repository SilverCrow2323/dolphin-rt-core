-- Run with: luajit tests/test_hotkeys_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local files = {
    ["workshop/hotkeys/Default/Hotkeys.ini"] =
        "[Hotkeys1]\nDevice = Keyboard\nKeys/Save State Slot 1 = \x60F1\x60\n",
    ["workshop/hotkeys/Default/ext-dolphin.gptk"] = "a = f1\n",
}
local modal, fail_write_path
local saved = {}
local old_io_open, old_execute = io.open, os.execute

love = { graphics = {}, timer = { getTime = function() return 0 end } }

local function file_lines(content)
    local lines = {}
    for line in (content .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    return lines
end
io.open = function(path, mode)
    if mode == "r" then
        local content = files[path]
        if content == nil then return nil end
        local lines, index = file_lines(content), 0
        return {
            lines = function()
                return function()
                    index = index + 1
                    return lines[index]
                end
            end,
            close = function() end,
        }
    end
    return nil
end

os.execute = function(command)
    local src, dst = command:match("^cp %-f '([^']+)' '([^']+)'")
    if src and dst then
        if files[src] == nil then return 1 end
        files[dst] = files[src]
        return 0
    end
    local dir = command:match("^mkdir %-p '([^']+)'")
    if dir then return 0 end
    local remove = command:match("^rm %-rf '([^']+)'")
    if remove then
        for path in pairs(files) do
            if path:sub(1, #remove + 1) == remove .. "/" then files[path] = nil end
        end
        return 0
    end
    return 0
end

package.preload["core.state"] = function() return { raw_input = false } end
package.preload["core.app_input"] = function()
    local map = { A=1, B=0, X=2, Y=3, L1=4, R1=5, SELECT=6, START=7, MENU=8, L2=9, L3=11, R2=12 }
    return { pad_map = function() return map end }
end
package.preload["ui.input"] = function()
    return { from_raw = function(index)
        return ({ [0]="B", [1]="A", [2]="X", [3]="Y", [4]="L1", [5]="R1", [6]="SELECT", [7]="START", [8]="MENU", [9]="L2", [11]="L3", [12]="R2" })[index]
    end }
end
package.preload["ui.sfx"] = function() return { play = function() end } end
package.preload["ui.notify"] = function() return { show = function() end } end
package.preload["ui.modal"] = function()
    return { show = function(title, body, options)
        modal = { title = title, body = body, options = options }
    end }
end
package.preload["core.shell"] = function()
    return {
        shq = function(value) return "'" .. tostring(value) .. "'" end,
        atomic_write = function(path, content)
            if path == fail_write_path then return false end
            files[path] = content
            saved[path] = content
            return true
        end,
    }
end
package.preload["ui.util"] = function()
    return {
        exists = function(path) return files[path] ~= nil end,
        ls = function(path)
            if path ~= "workshop/hotkeys/" then return {} end
            local names, seen = {}, {}
            for file in pairs(files) do
                local name = file:match("^workshop/hotkeys/([^/]+)/Hotkeys%.ini$")
                if name and not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
            table.sort(names)
            return names
        end,
    }
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
        W = 640, H = 480, MARGIN = 20, BOT = 460, ACC = { sys = {} }, C = {},
        List = list, set_accent = function() end,
    }
end
package.loaded["ui"] = { back = function() end }

local Screen = require("ui.screens.hotkeys")
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
    "hotkeys.refresh_profiles", "hotkeys.select_profile", "hotkeys.open_profile",
    "hotkeys.open_selected_profile", "hotkeys.select_action", "hotkeys.set_device",
    "hotkeys.change_key", "hotkeys.clear_selected", "hotkeys.start_capture",
    "hotkeys.capture_input", "hotkeys.finish_capture", "hotkeys.duplicate_profile",
    "hotkeys.reload", "hotkeys.save", "hotkeys.request_back", "hotkeys.state",
}) do
    assert(actions[id], "missing action " .. id)
end

Screen.enter()
local state = actions["hotkeys.state"].run()
assert(state.mode == "profiles" and state.profile_count == 1)
assert(actions["hotkeys.refresh_profiles"].run())
assert(actions["hotkeys.select_profile"].run(1))
local bad_profile, bad_profile_err = actions["hotkeys.open_profile"].run("../Default")
assert(bad_profile == false and tostring(bad_profile_err):match("invalid"))
local missing_profile, missing_profile_err = actions["hotkeys.open_profile"].run("Missing")
assert(missing_profile == false and tostring(missing_profile_err):match("not found"))
assert(actions["hotkeys.open_selected_profile"].run())

state = actions["hotkeys.state"].run()
assert(state.mode == "designer" and state.profile == "Default")
assert(state.action_count == 16 and state.dirty == false and state.device == "keyboard")
assert(actions["hotkeys.select_action"].run(1))
assert(actions["hotkeys.start_capture"].run())
local unknown, unknown_err = actions["hotkeys.capture_input"].run("definitely-not-a-button")
assert(unknown == false and tostring(unknown_err):match("not recognised"))
assert(actions["hotkeys.capture_input"].run("A"))
assert(actions["hotkeys.capture_input"].run(1))
local bad_commit, bad_commit_err = actions["hotkeys.finish_capture"].run("yes")
assert(bad_commit == false and tostring(bad_commit_err):match("boolean"))
assert(actions["hotkeys.finish_capture"].run(true))
state = actions["hotkeys.state"].run()
assert(state.dirty and state.selected_combo == "a" and state.emitted_key == "F1")

assert(actions["hotkeys.change_key"].run(1))
assert(actions["hotkeys.state"].run().emitted_key == "F2")
assert(actions["hotkeys.save"].run())
state = actions["hotkeys.state"].run()
assert(state.dirty == false and files["workshop/hotkeys/Default/Hotkeys.ini"]:match("\x60F2\x60"))
assert(files["workshop/hotkeys/Default/ext-dolphin.gptk"]:match("a%s+=%s+F2"))

-- Keyboard mode must also preserve Andromeda's L3 token in gptokeyb2.
assert(actions["hotkeys.select_action"].run(3))
assert(actions["hotkeys.start_capture"].run())
assert(actions["hotkeys.capture_input"].run(11))
assert(actions["hotkeys.finish_capture"].run(true))
assert(actions["hotkeys.save"].run())
assert(files["workshop/hotkeys/Default/ext-dolphin.gptk"]:match("l3%s+=%s+F%d+"),
       "L3 keyboard hotkeys must serialize with the supported gptokeyb2 l3 token")

assert(actions["hotkeys.set_device"].run("pad"))
assert(actions["hotkeys.state"].run().device == "pad")
-- muOS Andromeda raw Button 11 is the left-stick click (L3).
assert(actions["hotkeys.select_action"].run(2))
assert(actions["hotkeys.start_capture"].run())
assert(actions["hotkeys.capture_input"].run(11))
assert(actions["hotkeys.finish_capture"].run(true))
assert(actions["hotkeys.save"].run())
assert(files["workshop/hotkeys/Default/Hotkeys.ini"]:match("Device%s*=%s*SDL/0/muOS%-Keys"),
       "switching from Keyboard to Pad must retain the Andromeda SDL device")
assert(files["workshop/hotkeys/Default/Hotkeys.ini"]:match("Button 11"),
       "L3 hotkeys must serialize to the Andromeda Button 11 index")
local wrong_device, wrong_device_err = actions["hotkeys.change_key"].run(1)
assert(wrong_device == false and tostring(wrong_device_err):match("keyboard mode"))
local invalid_device, invalid_device_err = actions["hotkeys.set_device"].run("touch")
assert(invalid_device == false and tostring(invalid_device_err):match("keyboard or pad"))

assert(actions["hotkeys.start_capture"].run())
assert(actions["hotkeys.capture_input"].run("UP"))
local dpad_only, dpad_err = actions["hotkeys.finish_capture"].run(true)
assert(dpad_only == false and tostring(dpad_err):match("non%-D%-pad"))
assert(actions["hotkeys.state"].run().capturing == true)
assert(actions["hotkeys.capture_input"].run("A"))
assert(actions["hotkeys.finish_capture"].run(true))
assert(actions["hotkeys.save"].run())

assert(actions["hotkeys.duplicate_profile"].run())
state = actions["hotkeys.state"].run()
assert(state.profile == "Default_copy" and state.dirty == false)
assert(files["workshop/hotkeys/Default_copy/Hotkeys.ini"])

-- A partial duplicate whose gptk write fails must be rejected and cleaned up.
assert(actions["hotkeys.set_device"].run("keyboard"))
fail_write_path = "workshop/hotkeys/Default_copy_copy/ext-dolphin.gptk"
local duplicate_failed, duplicate_err = actions["hotkeys.duplicate_profile"].run()
assert(duplicate_failed == false and tostring(duplicate_err):match("save duplicate"))
assert(actions["hotkeys.state"].run().profile == "Default_copy")
assert(files["workshop/hotkeys/Default_copy_copy/Hotkeys.ini"] == nil)

assert(actions["hotkeys.set_device"].run("keyboard"))
assert(actions["hotkeys.request_back"].run())
assert(modal and modal.title == "Unsaved changes")
assert(actions["hotkeys.state"].run().mode == "designer")
modal.options.on_accept()
assert(actions["hotkeys.state"].run().mode == "profiles")
assert(actions["hotkeys.state"].run().dirty == false)

local reopen, reopen_err = actions["hotkeys.open_profile"].run("Default_copy")
assert(reopen, reopen_err)
assert(actions["hotkeys.start_capture"].run())
local blocked_back, blocked_back_err = actions["hotkeys.request_back"].run()
assert(blocked_back == false and tostring(blocked_back_err):match("capture"))
assert(actions["hotkeys.finish_capture"].run(false))

io.open, os.execute = old_io_open, old_execute
print("Hotkey Designer NEXUS actions: all tests passed")
