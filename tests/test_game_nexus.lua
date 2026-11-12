-- Run with: luajit tests/test_game_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local modal, opened, launches = nil, {}, 0
local launch_ok, launch_error = true, nil
local game = {
    id = "GAME-1", title = "Test Game", system = "GC", path = "/roms/test.iso",
    launch = { RtProfile = "Default", Controller = "Default", Hotkeys = "Default", GameSettings = "Disabled" },
}
local old_launch
love = { graphics = {}, timer = { getTime = function() return 0 end } }

local function ls(path)
    if path == "workshop/rtcoreprofile" then return { "Default", "Family" } end
    if path == "workshop/controller/GameCube" then return { "Default", "PadAlt" } end
    if path == "workshop/controller/Wii" then return { "Default", "WiiAlt" } end
    if path == "workshop/hotkeys" then return { "Default", "AltKeys" } end
    return {}
end
local U = {
    card_get = function(g, section, key)
        return g and g[section:lower()] and g[section:lower()][key] or nil
    end,
    card_set = function(g, section, key, value)
        g[section:lower()] = g[section:lower()] or {}
        g[section:lower()][key] = value
        return true
    end,
    is_wii = function(g) return g and g.system == "Wii" end,
    is_family = function(profile) return profile == "Family" end,
    ls = ls,
    clean_title = function(value) return value end,
    memo = function(_, _, fn) return fn() end,
    vault_counts = function() return 0, 0 end,
    yes = function(value) return value == "yes" or value == "true" or value == "1" end,
    mods_save = function() return true end,
    vault_set_off = function() return true end,
    launch = function()
        launches = launches + 1
        return launch_ok, launch_error
    end,
}
package.preload["ui.util"] = function() return U end
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
        ACC = { gc = {}, wii = {}, boost = {}, hot = {} }, C = { warn = {} },
        List = list, set_accent = function() end,
    }
end
package.preload["ui.sfx"] = function() return { play = function() end } end
package.preload["ui.notify"] = function() return { show = function() end } end
package.preload["ui.modal"] = function()
    return { show = function(title, body, options)
        modal = { title = title, body = body, options = options }
    end }
end
package.preload["core.rtcheats"] = function()
    return { load_for = function() return {} end }
end
local active_gamesettings = {}
package.preload["core.gameset_manager"] = function()
    return {
        list_for = function() return { { file = "CustomConfig" } } end,
        active_for = function(game_id) return active_gamesettings[game_id] end,
        set_active = function(game_id, filename)
            active_gamesettings[game_id] = filename
            return true
        end,
        clear_active = function(game_id)
            active_gamesettings[game_id] = nil
            return true
        end,
    }
end
package.preload["core.gameset_loader"] = function()
    return { for_game = function() return { configs = { { filename = "BundledConfig" } } } end }
end
package.preload["core.mods"] = function() return { CATS = {} } end
package.loaded["ui"] = {
    go = function(screen, params) opened[#opened + 1] = { screen = screen, params = params } end,
    go_instant = function(screen) opened[#opened + 1] = { screen = screen } end,
    back = function() end,
}

local Screen = require("ui.screens.game")
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
    "game.launch", "game.select_row", "game.change_selected", "game.set_choice",
    "game.set_overlay", "game.run_selected", "game.open_editor", "game.request_reset",
    "game.state",
}) do
    assert(actions[id], "missing action " .. id)
end

Screen.enter({})
local no_game = actions["game.state"].run()
assert(no_game.game_id == nil and no_game.title == nil)
for _, id in ipairs({
    "game.launch", "game.select_row", "game.change_selected", "game.set_choice",
    "game.set_overlay", "game.run_selected", "game.open_editor", "game.request_reset",
}) do
    local ok = actions[id].run(id == "game.set_choice" and "RtProfile" or 1, "Default")
    assert(ok == false, id .. " must reject calls without an active game")
end
assert(launches == 0)

Screen.enter({ game = game })
local state = actions["game.state"].run()
assert(state.game_id == "GAME-1" and state.title == "Test Game")
assert(state.profile == "Default" and state.controller == "Default")
assert(state.selected_index == 1 and state.selected_label == "PLAY")
assert(state.rows[2].kind == "section" and state.rows[2].skip)

assert(actions["game.select_row"].run(2) == false, "section header must not be selectable")
assert(actions["game.select_row"].run(3))
assert(actions["game.set_choice"].run("RtProfile", "Family"))
state = actions["game.state"].run()
assert(state.profile == "Family", "profile choice must update the game card")
assert(state.rows[4].label == "Tier", "family profile must expose tier row")

assert(actions["game.select_row"].run(4))
assert(actions["game.set_choice"].run("RtProfileVariant", "max"))
assert(actions["game.state"].run().profile_variant == "max")
local bad_tier, bad_tier_err = actions["game.set_choice"].run("RtProfileVariant", "turbo")
assert(bad_tier == false and tostring(bad_tier_err):match("not available"))

assert(actions["game.set_choice"].run("GameSettings", "CustomConfig"))
assert(actions["game.state"].run().game_settings == "CustomConfig")
local bad_choice, bad_choice_err = actions["game.set_choice"].run("GameSettings", "../../bad.ini")
assert(bad_choice == false and tostring(bad_choice_err):match("not available"))

assert(actions["game.set_choice"].run("Controller", "PadAlt"))
assert(actions["game.set_choice"].run("Hotkeys", "AltKeys"))
state = actions["game.state"].run()
assert(state.controller == "PadAlt" and state.hotkeys == "AltKeys")

assert(actions["game.select_row"].run(7))
assert(actions["game.open_editor"].run())
assert(opened[#opened].screen == "controller_map")
assert(opened[#opened].params.system == "GameCube")
assert(opened[#opened].params.name == "PadAlt")

assert(actions["game.select_row"].run(3))
assert(actions["game.open_editor"].run())
assert(opened[#opened].screen == "rt_profiles")
assert(opened[#opened].params.focus == "Family")

assert(actions["game.set_overlay"].run("OverlayFPS", true))
assert(actions["game.set_overlay"].run("OverlayOSD", false))
state = actions["game.state"].run()
assert(state.overlays.fps and not state.overlays.osd)
local bad_overlay, bad_overlay_err = actions["game.set_overlay"].run("OverlaySecret", true)
assert(bad_overlay == false and tostring(bad_overlay_err):match("unknown"))

-- Existing Safe Exit warning is preserved when changing the toggle.
assert(actions["game.select_row"].run(9))
assert(actions["game.change_selected"].run(-1))
assert(modal and modal.title == "Safe Exit off")
assert(game.launch.SafeExit == "no")
modal.options.on_cancel()
assert(game.launch.SafeExit == "yes")

-- Launch reports the underlying launcher result instead of masking failures.
launch_ok, launch_error = false, "launch.sh missing"
local failed_launch, failed_launch_err = actions["game.launch"].run()
assert(failed_launch == false and tostring(failed_launch_err):match("launch.sh missing"))
launch_ok, launch_error = true, nil
assert(actions["game.launch"].run())
assert(launches == 2)

-- Reset is confirmation-gated and reuses the existing reset callback.
assert(actions["game.request_reset"].run())
assert(modal and modal.title == "Reset options")
assert(game.launch.RtProfile == "Family", "reset must not run before confirmation")
modal.options.on_accept()
assert(game.launch.RtProfile == "Default")
assert(game.launch.Controller == "Default")
assert(game.launch.OverlayFPS == "no")

-- The PLAY row is also a runnable action, not a generic editable row.
assert(actions["game.select_row"].run(1))
assert(actions["game.run_selected"].run())
assert(launches == 3)
local invalid_index, invalid_index_err = actions["game.select_row"].run(999)
assert(invalid_index == false and tostring(invalid_index_err):match("index out of range"))

print("Per-game launch NEXUS actions: all tests passed")
