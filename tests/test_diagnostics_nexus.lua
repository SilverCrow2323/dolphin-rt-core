-- Run with: luajit tests/test_diagnostics_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local setting_values = {
    log_level = "info", log_retention_days = 7, log_max_kb = 512, log_auto_clear = true,
}
local modal, deleted = nil, 0
love = { graphics = {}, timer = {} }

local old_popen, old_execute = io.popen, os.execute
io.popen = function()
    local handle = {}
    function handle:read() return "0\n" end
    function handle:lines() return function() return nil end end
    function handle:close() end
    return handle
end
os.execute = function(command)
    if command:match("^rm %-f") then deleted = deleted + 1 end
    return 0
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
        ACC = { gc = {}, wii = {}, boost = {} },
        C = { bad = {}, text = {}, dim = {}, faint = {}, line = {}, ok = {} },
        List = list,
        set_accent = function() end,
        color = function() end,
        text = function() end,
        width = function() return 0 end,
        panel = function() end,
        draw_tool_icon = function() end,
        bg_workshop = function() end,
        footer = function() end,
    }
end
package.preload["ui.sfx"] = function() return { play = function() end } end
package.preload["ui.notify"] = function()
    return { show = function() end }
end
package.preload["ui.modal"] = function()
    return { show = function(title, body, options)
        modal = { title = title, body = body, options = options }
    end }
end
package.preload["core.settings"] = function()
    return {
        get = function(key) return setting_values[key] end,
        set = function(key, value) setting_values[key] = value end,
    }
end
package.preload["core.sh"] = function()
    return { shq = function(value) return "'" .. value .. "'" end }
end

local Screen = require("ui.screens.diagnostics")
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
    "diagnostics.refresh",
    "diagnostics.select_category",
    "diagnostics.open_selected",
    "diagnostics.scroll_viewer",
    "diagnostics.close_viewer",
    "diagnostics.request_clear_selected",
    "diagnostics.request_clear_all",
    "diagnostics.switch_mode",
    "diagnostics.select_setting",
    "diagnostics.change_setting",
    "diagnostics.state",
}) do
    assert(actions[id], "missing action " .. id)
end

Screen.enter()
local state = actions["diagnostics.state"].run()
assert(state.mode == "list" and state.category_count == 4 and state.setting_count == 4)
assert(state.viewer_open == false and state.viewer_line_count == 0)
assert(state.viewer_path == nil and state.log_contents == nil, "state must not expose paths or log contents")

assert(actions["diagnostics.select_category"].run(2))
local empty_open, empty_err = actions["diagnostics.open_selected"].run()
assert(empty_open == false and tostring(empty_err):match("no log files"))

assert(actions["diagnostics.request_clear_selected"].run())
assert(modal and modal.title == "Clear Dolphin Log?" and deleted == 0,
    "selected cleanup must require confirmation")
modal.options.on_accept()
assert(deleted == 1, "confirmed selected cleanup should execute")

assert(actions["diagnostics.switch_mode"].run("settings"))
assert(actions["diagnostics.select_setting"].run(1))
assert(actions["diagnostics.change_setting"].run(1))
assert(setting_values.log_level == "verbose")

local invalid_mode, invalid_mode_err = actions["diagnostics.switch_mode"].run("danger")
assert(invalid_mode == false and tostring(invalid_mode_err):match("list or settings"))
local invalid_index = actions["diagnostics.select_setting"].run(99)
assert(invalid_index == false, "out-of-range setting selection must be rejected")

assert(actions["diagnostics.switch_mode"].run("list"))
assert(actions["diagnostics.request_clear_all"].run())
assert(modal and modal.title == "Clear all logs?" and deleted == 1,
    "all-log cleanup must require confirmation")
modal.options.on_accept()
assert(deleted == 2, "confirmed all-log cleanup should execute")

local no_view, no_view_err = actions["diagnostics.scroll_viewer"].run(1)
assert(no_view == false and tostring(no_view_err):match("not open"))
local no_close = actions["diagnostics.close_viewer"].run()
assert(no_close == false, "closing a viewer that is not open must be rejected")

io.popen, os.execute = old_popen, old_execute
print("Diagnostics NEXUS actions: all tests passed")
