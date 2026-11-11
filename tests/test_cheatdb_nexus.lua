-- Run with: luajit tests/test_cheatdb_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local index = {
    ABCD01 = { boost = true },
    EFGH01 = { boost = false },
    IJKL01 = { boost = true },
    ["BAD/ID"] = { boost = true },
}
local refresh_count, opened, sounds = 0, {}, 0
local titles = {
    ABCD01 = "Alpha Racer",
    EFGH01 = "Beta Quest",
    IJKL01 = "Gamma World",
    MNOP01 = "Omega Circuit",
}
local Cheats
Cheats = {
    index = function() return index end,
    refresh_index = function()
        refresh_count = refresh_count + 1
        index = {
            ABCD01 = { boost = true },
            EFGH01 = { boost = false },
            IJKL01 = { boost = false },
            MNOP01 = { boost = true },
            ["../escape"] = { boost = true },
        }
        return index
    end,
}
local Library = {
    games = {
        { id = "ABCD01", title = "Alpha Racer" },
        { id = "ZZZZ01", title = "Installed Other Game" },
    },
}
local U = {
    title_for = function(id) return titles[id], true end,
    clean_title = function(value) return value end,
}
love = { graphics = {} }

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
        ACC = { lime = {}, boost = {}, hot = {} },
        C = { text = {}, surf = {}, line = {}, dim = {}, faint = {} },
        List = list, set_accent = function() end,
        width = function(_, value) return #tostring(value) * 8 end,
        color = function() end, text = function() end, clip = function(_, value) return value end,
        panel = function() end, pill = function() return 20 end, bolt = function() end,
        header = function() end, footer = function() end,
    }
end
package.preload["ui.sfx"] = function() return { play = function() sounds = sounds + 1 end } end
package.preload["ui.util"] = function() return U end
package.preload["core.rtcheats"] = function() return Cheats end
package.preload["core.library"] = function() return Library end
package.loaded["ui"] = { back = function() end }

local Screen = require("ui.screens.cheatdb")
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
    "cheatdb.refresh", "cheatdb.set_filter", "cheatdb.jump_letter",
    "cheatdb.open_selected", "cheatdb.state",
}) do
    assert(actions[id], "missing action " .. id)
end

Screen.enter()
local state = actions["cheatdb.state"].run()
assert(state.filter == "all" and state.database_count == 3 and state.result_count == 3)
assert(state.boost_count == 2 and state.owned_count == 1)
assert(state.selected_id == "ABCD01" and state.selected_owned and state.selected_boost)
assert(state.file_path == nil and state.rom_path == nil)

assert(actions["cheatdb.set_filter"].run("boost"))
state = actions["cheatdb.state"].run()
assert(state.filter == "boost" and state.result_count == 2)
assert(actions["cheatdb.set_filter"].run("mine"))
state = actions["cheatdb.state"].run()
assert(state.filter == "mine" and state.result_count == 1 and state.selected_id == "ABCD01")
local bad_filter, bad_filter_err = actions["cheatdb.set_filter"].run("owned")
assert(bad_filter == false and tostring(bad_filter_err):match("all, boost or mine"))

assert(actions["cheatdb.set_filter"].run("all"))
assert(actions["cheatdb.jump_letter"].run(1))
assert(actions["cheatdb.state"].run().selected_id == "EFGH01")
local bad_direction, bad_direction_err = actions["cheatdb.jump_letter"].run(0)
assert(bad_direction == false and tostring(bad_direction_err):match("-1 or 1"))
assert(actions["cheatdb.open_selected"].run())
assert(opened[1].screen == "cheats")
assert(opened[1].params.game_id == "EFGH01")
assert(opened[1].params.title == "Beta Quest")

local keep_id = actions["cheatdb.state"].run().selected_id
assert(actions["cheatdb.refresh"].run())
state = actions["cheatdb.state"].run()
assert(state.selected_id == keep_id, "refresh should preserve selected database entry")
assert(state.database_count == 4 and state.boost_count == 2)
assert(refresh_count == 1, "refresh must invalidate the cached cheat database index")

local empty_filter, empty_err = actions["cheatdb.set_filter"].run("mine")
assert(empty_filter, empty_err)
assert(actions["cheatdb.state"].run().result_count == 1)

print("Cheat Database NEXUS actions: all tests passed")
