-- Run with: luajit tests/test_library_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local function eq(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " ..
        tostring(expected) .. ", got " .. tostring(actual))
end

local Library = { games = {}, scan_calls = 0 }
function Library.scan_begin() Library.scan_calls = Library.scan_calls + 1 end

local values = { favorites = {} }
local Settings = {
    get = function(key) return values[key] end,
    set = function(key, value) values[key] = value end,
}
local launch_calls = 0
local Util = {
    is_wii = function(game) return game.system == "WII" end,
    launch = function(game)
        launch_calls = launch_calls + 1
        return true
    end,
}
local sfx_calls = 0
local SFX = { play = function() sfx_calls = sfx_calls + 1 end }

package.preload["ui.kit"] = function()
    return {
        MARGIN = 0, BOT = 480,
        List = function()
            local list = { items = {}, sel = 1 }
            function list:set(items)
                self.items = items
                self.sel = 1
            end
            function list:cur() return self.items[self.sel] end
            function list:_aim() end
            function list:update() end
            return list
        end,
    }
end
package.preload["ui.sfx"] = function() return SFX end
package.preload["ui.util"] = function() return Util end
package.preload["ui.notify"] = function() return { show = function() end } end
package.preload["ui.modal"] = function() return {} end
package.preload["core.library"] = function() return Library end
package.preload["core.settings"] = function() return Settings end
package.preload["core.launcher"] = function() return {} end
package.preload["core.rtcheats"] = function() return {} end
package.preload["core.cover_loader"] = function() return {} end
package.preload["ui.mascot"] = function() return { release = function() end } end
package.preload["core.compatibility"] = function()
    return { load = function() end }
end

local Screen = require("ui.screens.library")
local actions, metadata = {}, {}
local go_result, go_detail = true, nil
local go_calls = {}
local UI = {
    register_action = function(id, callback, meta)
        if actions[id] then return false, "duplicate action" end
        actions[id], metadata[id] = callback, meta
        return true
    end,
    go = function(screen, params)
        go_calls[#go_calls + 1] = { screen = screen, params = params }
        return go_result, go_detail
    end,
}
local registered, register_error = Screen.register_actions(UI)
eq(registered, true, "register all library actions")
eq(register_error, nil, "no registration error")
eq(#(function()
    local ids = {}
    for id in pairs(actions) do ids[#ids + 1] = id end
    return ids
end)(), 5, "five library actions registered")

for _, id in ipairs({
    "library.rescan", "library.launch_selected", "library.open_selected_options",
    "library.toggle_selected_favorite", "library.set_filter",
}) do
    assert(type(actions[id]) == "function", "missing action " .. id)
    eq(metadata[id].group, "library", id .. " group")
end

local ok, reason = actions["library.launch_selected"]()
eq(ok, false, "launch rejects empty selection")
eq(reason, "no game selected", "launch empty-selection reason")
ok, reason = actions["library.open_selected_options"]()
eq(ok, false, "options rejects empty selection")
eq(reason, "no game selected", "options empty-selection reason")
ok, reason = actions["library.toggle_selected_favorite"]()
eq(ok, false, "favorite rejects empty selection")
eq(reason, "selected game has no valid ID", "favorite empty-selection reason")

ok, reason = actions["library.set_filter"](99)
eq(ok, false, "filter rejects out-of-range index")
eq(Screen.filter, 1, "invalid filter leaves state unchanged")
ok, reason = actions["library.set_filter"]("UNKNOWN")
eq(ok, false, "filter rejects unknown name")
eq(Screen.filter, 1, "unknown filter leaves state unchanged")

Screen.scanning = true
ok, reason = actions["library.rescan"]()
eq(ok, false, "rescan rejects concurrent scan")
eq(reason, "scan already in progress", "concurrent scan reason")
Screen.scanning = false
ok = actions["library.rescan"]()
eq(ok, true, "rescan starts when idle")
eq(Library.scan_calls, 1, "scan begins exactly once")
eq(Screen.scanning, true, "screen enters scanning state")

local gc = { id = "gc-001", title = "Alpha", system = "GC" }
local wii = { id = "wii-001", title = "Zelda", system = "WII" }
Library.games = { gc, wii }
values.favorites = {}
Screen.enter()
eq(Screen.list:cur().id, gc.id, "default GC filter selects first game")

ok = actions["library.launch_selected"]()
eq(ok, true, "launch selected game")
eq(launch_calls, 1, "launch delegate called once")

go_result, go_detail = false, "transition in progress"
ok, reason = actions["library.open_selected_options"]()
eq(ok, false, "options propagates navigation rejection")
eq(reason, "transition in progress", "options preserves navigation reason")
eq(Screen.keep_id, gc.id, "options remembers selected game")
eq(go_calls[#go_calls].screen, "game", "options targets game screen")
eq(go_calls[#go_calls].params.game.id, gc.id, "options passes selected game")

go_result, go_detail = true, nil
ok = actions["library.open_selected_options"]()
eq(ok, true, "options succeeds when navigation accepts")

ok = actions["library.toggle_selected_favorite"]()
eq(ok, true, "favorite toggles on")
eq(values.favorites[gc.id], true, "favorite persistence receives enabled state")
ok = actions["library.toggle_selected_favorite"]()
eq(ok, true, "favorite toggles off")
eq(values.favorites[gc.id], nil, "favorite persistence receives disabled state")
eq(sfx_calls, 2, "favorite changes play feedback")

Screen.list.sel = 2
ok = actions["library.set_filter"]("WII")
eq(ok, true, "filter accepts WII name")
eq(Screen.filter, 2, "WII filter selected")
eq(Screen.list:cur().id, wii.id, "WII filter selects matching system")
ok = actions["library.toggle_selected_favorite"]()
eq(values.favorites[wii.id], true, "WII favorite saved")
ok = actions["library.set_filter"]("FAV")
eq(ok, true, "filter accepts FAV name")
eq(Screen.filter, 3, "favorite filter selected")
eq(Screen.list:cur().id, wii.id, "filter rebuild preserves selected game")

ok = actions["library.set_filter"](1)
eq(ok, true, "filter accepts numeric index")
eq(Screen.filter, 1, "numeric filter applied")
eq(Screen.list:cur().id, gc.id, "GC filter rebuilds game list")

print("Library NEXUS actions: all tests passed")
