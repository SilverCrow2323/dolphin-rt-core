package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

-- The Library screen must adopt an active boot scan without restarting it.
package.preload["ui.kit"] = function()
    local K = { W = 640, H = 480, BOT = 460, MARGIN = 18, C = {dim = {1,1,1}}, ACC = {gc = {}, wii = {}} }
    K.List = function()
        local list = {items = {}, sel = 1}
        function list:set(items) self.items = items or {}; self.sel = math.min(self.sel, math.max(1, #self.items)) end
        function list:update() end
        function list:cur() return self.items[self.sel] end
        function list:_aim() end
        function list:move() return false end
        function list:page() end
        return list
    end
    K.set_accent = function() end
    return K
end
package.preload["ui.sfx"] = function() return {play = function() end} end
package.preload["ui.util"] = function()
    return {is_wii = function(g) return g and g.system == "Wii" end, launch = function() return true end}
end
package.preload["ui.notify"] = function() return {show = function() end} end
package.preload["ui.modal"] = function() return {show = function() end} end
package.preload["core.settings"] = function()
    return {get = function(key) if key == "favorites" then return {} end end, set = function() end}
end
package.preload["core.launcher"] = function() return {} end
package.preload["core.rtcheats"] = function() return {} end
package.preload["ui.mascot"] = function() return {release = function() end} end
package.preload["core.cover_loader"] = function() return {} end
package.preload["core.compatibility"] = function() return {load = function() end} end

local library = {games = {}, scanning = true, scan_owner = "boot", begin_calls = 0, step_calls = 0}
function library.scan_begin(owner)
    library.begin_calls = library.begin_calls + 1
    library.scanning, library.scan_owner = true, owner
end
function library.scan_step()
    library.step_calls = library.step_calls + 1
    return false
end
function library.scan_finish()
    library.scanning, library.scan_owner = false, nil
end
package.preload["core.library"] = function() return library end

local Screen = require("ui.screens.library")
Screen.enter()
assert(Screen.scanning == true and Screen.need_scan == false)
Screen.update(0.016)
assert(library.begin_calls == 0, "Library must not restart the boot scan")
assert(library.step_calls == 0, "Library must not double-drive the boot scan")

library.games = {{id = "GZLE01", title = "Test Game", system = "GC"}}
library.scanning, library.scan_owner = false, nil
Screen.update(0.016)
assert(Screen.scanning == false)
assert(#Screen.list.items == 1 and Screen.list.items[1].id == "GZLE01")
assert(library.begin_calls == 0 and library.step_calls == 0)

-- The globally registered NEXUS rescan action must not replace a scan owned by
-- boot, even when its local screen state is stale.
local actions = {}
local ui = {
    register_action = function(_, id, run)
        actions[id] = run
        return true
    end,
}
assert(Screen.register_actions(ui))
Screen.scanning = false
library.scanning, library.scan_owner = true, "boot"
local accepted, reason = actions["library.rescan"]()
assert(accepted == false and reason == "scan already in progress")
assert(library.begin_calls == 0 and library.scan_owner == "boot")
assert(Screen.scanning == true, "NEXUS rescan must synchronize local scan state")

-- With no other scan active, NEXUS may start its own UI-owned scan.
library.scanning, library.scan_owner = false, nil
Screen.scanning = false
accepted = actions["library.rescan"]()
assert(accepted == true)
assert(library.begin_calls == 1 and library.scan_owner == "ui")

print("Library boot-scan handoff and NEXUS rescan ownership: all tests passed")
