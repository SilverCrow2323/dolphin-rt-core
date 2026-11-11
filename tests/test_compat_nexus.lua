-- Run with: luajit tests/test_compat_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local games = {
    { id = "GAME01", title = "Alpha Racer", playable_rank = 3, system = "GC", entries = {} },
    { id = "GAME02", title = "Beta Quest", playable_rank = 2, system = "Wii", entries = {} },
    { id = "GAME03", title = "Delta Arena", playable_rank = 1, system = "GC", entries = {} },
    { id = "GAME04", title = "Gamma World", playable_rank = 3, system = "Wii", entries = {} },
}
local library = {
    { id = "GAME01", title = "Alpha Racer", path = "/roms/alpha.iso" },
    { id = "GAME03", title = "Delta Arena", path = "/roms/delta.rvz" },
}
local load_count, opened, sounds = 0, {}, 0
local fail_load, replace_on_force = false, false
love = { graphics = {} }

local Compat
Compat = {
    games = games,
    count = #games,
    error = nil,
    load = function(force)
        load_count = load_count + 1
        assert(force == true or force == nil)
        if fail_load then error("database unavailable") end
        if force and replace_on_force then
            local fresh = {}
            for i, game in ipairs(Compat.games) do
                fresh[i] = {
                    id = game.id, title = game.title, playable_rank = game.playable_rank,
                    system = game.system, entries = {},
                }
            end
            Compat.games = fresh
            Compat.count = #fresh
            replace_on_force = false
        end
        return Compat
    end,
    summary = function(game)
        return {
            play_label = game.playable_rank == 3 and "Playable" or
                (game.playable_rank == 2 and "Playable (issues)" or "Not playable"),
        }
    end,
}
local Library = { games = library }
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
        function value:page(direction)
            return self:move(direction * 5)
        end
        function value:_aim() end
        return value
    end
    return {
        MARGIN = 20, BOT = 460, W = 640,
        C = { sys = {}, lime = {}, boost = {}, hot = {}, ok = {}, dim = {} },
        ACC = { gc = {}, wii = {} }, List = list,
        set_accent = function() end,
    }
end
package.preload["ui.sfx"] = function() return { play = function() sounds = sounds + 1 end } end
package.preload["ui.util"] = function() return {} end
package.preload["core.compatibility"] = function() return Compat end
package.preload["core.library"] = function() return Library end
package.loaded["ui"] = { back = function() end }

local Screen = require("ui.screens.compat_list")
local actions = {}
local UI = {
    register_action = function(id, run, metadata)
        if actions[id] then return false, "duplicate action" end
        actions[id] = { run = run, metadata = metadata }
        return true
    end,
    go = function(screen, params)
        opened[#opened + 1] = { screen = screen, params = params }
        return true
    end,
}
local registered, register_err = Screen.register_actions(UI)
assert(registered, register_err)
for _, id in ipairs({
    "compat.refresh", "compat.set_filter", "compat.set_mine_only",
    "compat.jump_letter", "compat.open_selected", "compat.state",
}) do
    assert(actions[id], "missing action " .. id)
end

Screen.enter()
local state = actions["compat.state"].run()
assert(state.filter == "all" and state.result_count == 4 and state.database_count == 4)
assert(state.selected_id == "Alpha" or state.selected_id == nil or state.selected_id == "GAME01")
assert(state.mine_only == false)
assert(state.selected_owned, "alphabetically first game belongs to local library")

assert(actions["compat.set_filter"].run("playable"))
state = actions["compat.state"].run()
assert(state.filter == "playable" and state.result_count == 2)
assert(actions["compat.set_filter"].run("issues"))
assert(actions["compat.state"].run().selected_id == "GAME02")
assert(actions["compat.set_filter"].run("not_playable"))
assert(actions["compat.state"].run().selected_id == "GAME03")
local bad_filter, bad_filter_err = actions["compat.set_filter"].run("unknown")
assert(bad_filter == false and tostring(bad_filter_err):match("unknown"))

assert(actions["compat.set_filter"].run("all"))
assert(actions["compat.set_mine_only"].run(true))
state = actions["compat.state"].run()
assert(state.mine_only and state.result_count == 2)
assert(actions["compat.state"].run().selected_owned)
assert(actions["compat.set_mine_only"].run(false))
assert(actions["compat.state"].run().result_count == 4)
local bad_toggle, bad_toggle_err = actions["compat.set_mine_only"].run("yes")
assert(bad_toggle == false and tostring(bad_toggle_err):match("boolean"))

-- Letter navigation moves between title initials, not individual rows.
assert(actions["compat.set_filter"].run("all"))
assert(actions["compat.jump_letter"].run(1))
assert(actions["compat.state"].run().selected_id == "GAME04")
local bad_jump, bad_jump_err = actions["compat.jump_letter"].run(0)
assert(bad_jump == false and tostring(bad_jump_err):match("-1 or 1"))

-- An unowned compatibility entry must never be opened as a game screen.
assert(actions["compat.set_filter"].run("issues"))
local unowned, unowned_err = actions["compat.open_selected"].run()
assert(unowned == false and tostring(unowned_err):match("not in the local library"))
assert(#opened == 0)

-- An owned entry opens using the local Library object, not the compatibility object.
assert(actions["compat.set_filter"].run("all"))
assert(actions["compat.set_mine_only"].run(true))
assert(actions["compat.state"].run().selected_id == "GAME01")
assert(actions["compat.open_selected"].run())
assert(opened[1].screen == "game")
assert(opened[1].params.game == library[1])
assert(opened[1].params.game.path == "/roms/alpha.iso")

local selected_before = actions["compat.state"].run().selected_id
local previous_object = Screen.list:cur()
replace_on_force = true
assert(actions["compat.refresh"].run())
state = actions["compat.state"].run()
assert(state.selected_id == selected_before, "refresh should preserve current game selection")
assert(Screen.list:cur() ~= previous_object, "test must replace database objects during refresh")
assert(load_count == 2, "refresh must force a database reload")

fail_load = true
local failed_refresh, refresh_err = actions["compat.refresh"].run()
assert(failed_refresh == false and tostring(refresh_err):match("database unavailable"))
fail_load = false

print("Compatibility Browser NEXUS actions: all tests passed")
