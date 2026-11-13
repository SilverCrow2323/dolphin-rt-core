-- The boot intro must advance to Library even if optional startup tasks are still running.
package.preload["ui.kit"] = function()
    return { set_accent = function() end }
end
package.preload["ui.mascot"] = function()
    return {
        FPS = 24, HIT = 32, FRAMES = 100,
        load = function() return true end,
        release = function() end,
        draw = function() end,
    }
end
package.preload["core.settings"] = function()
    return { get = function(key) if key == "boot_anim" then return "full" end end }
end
package.preload["core.boot_initializer"] = function()
    return { is_done = function() return false end }
end
local transitions = {}
package.preload["ui"] = function()
    return { go = function(screen, params, opts)
        transitions[#transitions + 1] = {screen, params, opts}
        return true
    end }
end

local BootScreen = require("ui.screens.boot")
BootScreen.enter()
BootScreen.update(9.1)
assert(BootScreen.going == true)
assert(#transitions == 1 and transitions[1][1] == "library",
       "boot intro must not wait forever for optional boot jobs")
BootScreen.update(1)
assert(#transitions == 1, "boot transition must be emitted once")
print("Boot intro auto-proceeds: all tests passed")
