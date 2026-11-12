#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local now, mode, mascot_available = 0, "full", true
local navigations, entered = {}, 0
love = { timer = { getTime = function() return now end } }

package.preload["ui.kit"] = function()
    return { set_accent = function() end }
end
package.preload["ui.mascot"] = function()
    return {
        FRAMES = 120, FPS = 24, HIT = 48,
        load = function() return mascot_available end,
        release = function() end,
        draw = function() end,
    }
end
package.preload["core.settings"] = function()
    return { get = function(key)
        if key == "boot_anim" then return mode end
        if key == "rom_discovery_done" then return true end
        if key == "rom_paths" then return { { path = "/roms" } } end
    end }
end
package.preload["core.boot_initializer"] = function()
    return {
        step = function() return "scan_roms" end, -- deliberately not ready
        needs_rom_setup = function() return false end,
    }
end
package.preload["ui"] = function()
    return { go = function(name, params, opts)
        navigations[#navigations + 1] = { name = name, params = params, opts = opts }
    end }
end

local Boot = require("ui.screens.boot")

local function run_case(selected_mode, has_mascot, expected_limit)
    mode, mascot_available = selected_mode, has_mascot
    now, navigations = 0, {}
    Boot.enter()
    local elapsed = 0
    while #navigations == 0 and elapsed < 8 do
        now = now + 0.05
        elapsed = elapsed + 0.05
        Boot.update(0.05)
    end
    assert(#navigations == 1, selected_mode .. ": intro never navigated automatically")
    assert(navigations[1].name == "library", selected_mode .. ": wrong automatic destination")
    assert(navigations[1].opts and navigations[1].opts.no_push == true,
        selected_mode .. ": intro should replace itself without back-stack entry")
    assert(elapsed <= expected_limit + 0.06,
        selected_mode .. ": intro exceeded its strict wall-clock deadline")
    assert(elapsed >= expected_limit - 0.11,
        selected_mode .. ": intro ended unexpectedly early")
end

run_case("full", true, 5.5)
run_case("quick", true, 2.8)
run_case("off", true, 0.35)
run_case("full", false, 0.35)
print("Boot animation autonomous exit tests: OK")
