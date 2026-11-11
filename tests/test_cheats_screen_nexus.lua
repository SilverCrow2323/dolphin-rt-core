-- Run with: luajit tests/test_cheats_screen_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local entries = {
    { slug = "boost-a", name = "Boost A", group = "perf", pclass = "speed", enabled = false, codes = { "A" }, notes = {} },
    { slug = "fps-a", name = "FPS A", group = "fps", enabled = false, codes = { "B" }, notes = {} },
    { slug = "cheat-a", name = "Cheat A", group = "cheat", enabled = false, codes = { "C" }, notes = {} },
}
local applied, sync_calls = 0, 0
local missing_ids = {}
local apply_failure, set_failure, bulk_failure = false, false, false
love = { graphics = {}, timer = {} }

package.preload["ui.kit"] = function()
    local function list()
        local value = { items = {}, sel = 1, y = 180 }
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
        ACC = { boost = {}, wii = {}, hot = {} }, C = {},
        List = list, set_accent = function() end,
        text = function() end, color = function() end, panel = function() end,
        width = function() return 10 end, clip = function(_, value) return value end,
        switch = function() end, pill = function() end, header = function() end,
        footer = function() end,
    }
end
package.preload["ui.sfx"] = function() return { play = function() end } end
package.preload["ui.notify"] = function() return { show = function() end } end
package.preload["core.rtcheats"] = function()
    return {
        PCLASS_LABEL = { speed = "Speed hacks" },
        load_for = function() return entries end,
        missing = function() return missing_ids end,
        sync = function(ids)
            sync_calls = sync_calls + 1
            return #ids > 0
        end,
        sync_status = function()
            return { state = sync_calls > 0 and "running" or "idle", done = 0, total = #missing_ids }
        end,
        reload = function() end,
        in_index = function() return true end,
        set_enabled = function(_, slug, enabled)
            if set_failure then return false end
            for _, entry in ipairs(entries) do
                if entry.slug == slug then entry.enabled = enabled; return true end
            end
            return false
        end,
        set_many = function(_, batch)
            if bulk_failure then return false end
            for _, change in ipairs(batch) do
                for _, entry in ipairs(entries) do
                    if entry.slug == change.slug then entry.enabled = change.on end
                end
            end
            return true
        end,
        apply = function()
            if apply_failure then return nil, "disk full" end
            applied = applied + 1
            return true, 2
        end,
    }
end
package.loaded["ui"] = { back = function() end }

local Screen = require("ui.screens.cheats")
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
    "cheats.refresh", "cheats.switch_tab", "cheats.select",
    "cheats.toggle_selected", "cheats.bulk_toggle", "cheats.apply", "cheats.state",
}) do
    assert(actions[id], "missing action " .. id)
end

-- The screen's fallback game id is "?", not an active game identifier.
Screen.enter({})
local state = actions["cheats.state"].run()
assert(state.game_id == nil and state.title == nil)
for _, id in ipairs({
    "cheats.refresh", "cheats.switch_tab", "cheats.select",
    "cheats.toggle_selected", "cheats.bulk_toggle", "cheats.apply",
}) do
    local ok = actions[id].run(id == "cheats.switch_tab" and "fps" or 1)
    assert(ok == false, id .. " must reject a missing game")
end
assert(applied == 0, "missing game must never be applied")

Screen.enter({ game_id = "GAME-1", title = "Test Game" })
state = actions["cheats.state"].run()
assert(state.game_id == "GAME-1" and state.title == "Test Game")
assert(state.tab == "perf")
assert(state.boost_count == 1 and state.fps_count == 1 and state.cheat_count == 1)
assert(state.boost_enabled == 0 and state.fps_enabled == 0 and state.cheat_enabled == 0)

-- Boost has a category header at index 1; it cannot be selected or toggled.
assert(Screen.list.items[1].skip == true)
assert(actions["cheats.select"].run(1) == false, "category header must not be selectable")
assert(actions["cheats.state"].run().selected_slug == "boost-a", "rejected selection preserves current entry")
Screen.list.sel = 1
local header_toggle, header_err = actions["cheats.toggle_selected"].run()
assert(header_toggle == false and tostring(header_err):match("no cheat entry"))
assert(entries[1].enabled == false, "category header must not toggle a cheat")

assert(actions["cheats.select"].run(2))
assert(actions["cheats.toggle_selected"].run())
state = actions["cheats.state"].run()
assert(state.selected_slug == "boost-a" and state.selected_enabled and state.changed)
assert(applied == 0, "per-game toggle must not apply codes to Dolphin")

assert(actions["cheats.apply"].run())
assert(applied == 1, "explicit apply action must write to Dolphin")
assert(actions["cheats.state"].run().changed == false)

-- A failed Dolphin write must be surfaced as a failed NEXUS action.
set_failure = true
local toggle_failed, toggle_err = actions["cheats.toggle_selected"].run()
assert(toggle_failed == false and tostring(toggle_err):match("rtcheats_data"))
set_failure = false
apply_failure = true
local apply_failed, apply_err = actions["cheats.apply"].run()
assert(apply_failed == false and tostring(apply_err):match("disk full"))
apply_failure = false
assert(applied == 1, "failed apply must not count as a successful write")

assert(actions["cheats.switch_tab"].run("fps"))
assert(actions["cheats.state"].run().tab == "fps")
assert(actions["cheats.select"].run(1))
assert(actions["cheats.toggle_selected"].run())
state = actions["cheats.state"].run()
assert(state.selected_slug == "fps-a" and state.selected_enabled)
assert(actions["cheats.switch_tab"].run("cheats"))
assert(actions["cheats.state"].run().tab == "cheat")
assert(actions["cheats.select"].run(1))
assert(actions["cheats.toggle_selected"].run())
assert(actions["cheats.state"].run().selected_slug == "cheat-a")

local bad_tab, bad_tab_err = actions["cheats.switch_tab"].run("unknown")
assert(bad_tab == false and tostring(bad_tab_err):match("boost, fps or cheats"))
local bad_index, bad_index_err = actions["cheats.select"].run(99)
assert(bad_index == false and tostring(bad_index_err):match("index out of range"))

-- Bulk operations alter only the current tab's per-game toggles.
assert(actions["cheats.switch_tab"].run("boost"))
assert(actions["cheats.bulk_toggle"].run())
state = actions["cheats.state"].run()
assert(state.boost_enabled == 1 and state.fps_enabled == 1 and state.cheat_enabled == 1)
bulk_failure = true
local bulk_failed, bulk_err = actions["cheats.bulk_toggle"].run()
assert(bulk_failed == false and tostring(bulk_err):match("update cheat settings"))
bulk_failure = false

-- Refresh reloads the per-game model and starts a missing-data sync.
missing_ids = { "GAME-1" }
local before_sync = sync_calls
assert(actions["cheats.refresh"].run())
state = actions["cheats.state"].run()
assert(state.downloading and state.download_state == "running")
assert(sync_calls == before_sync + 1)

print("Per-game Cheats NEXUS actions: all tests passed")
