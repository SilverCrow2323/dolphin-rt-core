package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path
local invalidations, deployments, polls = 0, 0, 0
local function make_list()
    return {
        items = {}, sel = 1,
        set = function(self, items) self.items = items or {}; self.sel = 1 end,
        cur = function(self) return self.items[self.sel] end,
        _aim = function() end,
        update = function() end,
    }
end
package.preload["ui.kit"] = function()
    return {
        List = make_list,
        ACC = { gc = {}, wii = {}, boost = {} },
        C = {},
        W = 640, H = 480, MARGIN = 20, BOT = 440,
        set_accent = function() end,
    }
end
package.preload["ui.sfx"] = function() return { play = function() end } end
package.preload["ui.util"] = function() return { clean_title = function(s) return s end } end
package.preload["core.gameset_loader"] = function()
    return {
        generation = 0,
        invalidate = function()
            invalidations = invalidations + 1
        end,
        load = function()
            return {
                games = {{
                    game = "Game",
                    ids = { "GZLE01" },
                    configs = {{
                        title = "Community preset",
                        author = "SPDW Factory",
                        description = "A test preset",
                        filename = "Default.ini",
                        raw_content = "[Core]\r\nCPUThread = True\r\n\r\n[Video]\r\nBackend = Vulkan",
                    }},
                }},
            }
        end,
    }
end
package.preload["core.gameset_manager"] = function() return { list_for = function() return {} end } end
package.preload["core.library"] = function() return { games = { { id = "GZLE01", title = "Game" } } } end
package.preload["core.gamesettings_deployer"] = function()
    return {
        start = function(games)
            deployments = deployments + #games
            return #games
        end,
        poll = function()
            polls = polls + 1
            if polls == 2 then
                return true, { deployed = 2, matched = 1, processed = 1 }
            end
            return false, { deployed = 0, matched = 1, processed = 0 }
        end,
    }
end

local Screen = require("ui.screens.gameset_browser")
local actions = {}
local UI = {
    register_action = function(id, run, meta)
        actions[id] = { run = run, meta = meta }
        return true
    end,
}
local ok, err = Screen.register_actions(UI)
assert(ok, err)
for _, id in ipairs({
    "gamesettings.open_library",
    "gamesettings.open_storage",
    "gamesettings.open_database",
    "gamesettings.refresh_database",
    "gamesettings.select_row",
    "gamesettings.preview_selected",
    "gamesettings.sync_library",
    "gamesettings.state",
}) do
    assert(actions[id], "missing NEXUS action: " .. id)
end
assert(actions["gamesettings.open_database"].run())
local state = actions["gamesettings.state"].run()
assert(state.tab == "database", "database tab should be active")
Screen.pad("A")
assert(actions["gamesettings.select_row"].run(3), "database preset row should be selectable")
assert(actions["gamesettings.preview_selected"].run(), "database preset should open in preview")
local preview_state = actions["gamesettings.state"].run()
assert(preview_state.preview_open and preview_state.preview_line_count == 5,
       "preview must split embedded INI text on line boundaries")
Screen.pad("B")
assert(not actions["gamesettings.state"].run().preview_open, "B should close the preview")
assert(actions["gamesettings.refresh_database"].run())
assert(invalidations == 1, "refresh should invalidate database cache")
local synced, result = actions["gamesettings.sync_library"].run()
assert(synced and result.queued == 1 and deployments == 1, "library presets should enter the incremental queue")
local busy, busy_reason = actions["gamesettings.sync_library"].run()
assert(busy == false and busy_reason == "GameSettings sync is already running",
       "a second sync must not replace the active queue")
Screen.update(0)
local pending_state = actions["gamesettings.state"].run()
assert(pending_state.deployment_pending and pending_state.deployment.processed == 0,
       "the incremental queue must remain pending between polls")
Screen.update(0)
local deployment_state = actions["gamesettings.state"].run()
assert(deployment_state.deployment.deployed == 2 and not deployment_state.deployment_pending,
       "the incremental queue should publish its completed deployment result")
assert(actions["gamesettings.open_storage"].run())
assert(actions["gamesettings.state"].run().tab == "storage")
assert(actions["gamesettings.select_row"].run(999) == false, "invalid row must be rejected")
assert(actions["gamesettings.preview_selected"].run() == false, "only database presets can be previewed")
print("GameSettings NEXUS actions: OK")
