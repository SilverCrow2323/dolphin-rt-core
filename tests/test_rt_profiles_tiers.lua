#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;dolphin-rtcore-muos/app/Dolphin RtUI/?/init.lua;" .. package.path

local tmp = os.tmpname()
os.remove(tmp)
local family_dir = tmp .. "/RtPrime"
for _, tier in ipairs({ "lite", "std", "max" }) do
    local dir = family_dir .. "/" .. tier
    os.execute("mkdir -p " .. string.format("%q", dir))
    local f = assert(io.open(dir .. "/rtprofile_data.ini", "w"))
    f:write("[Profile]\nName = RtPrime " .. tier .. "\n\n[Runtime]\nLocked = False\n")
    f:close()
end

local entered
package.preload["ui.kit"] = function()
    return {
        W = 640, H = 480, ACC = { sys = {}, gc = {}, wii = {} },
        C = { text = {}, dim = {}, faint = {}, line = {}, ok = {}, bad = {}, sys = {} },
        set_accent = function() end,
    }
end
package.preload["ui.sfx"] = function() return { play = function() end } end
package.preload["ui.notify"] = function() return { show = function() end } end
package.preload["core.shell"] = function() return { is_dir = function() return true end } end
package.preload["core.profile_manager"] = function()
    return {
        list = function()
            return {
                {
                    name = "RtPrime",
                    dir = family_dir,
                    meta = {
                        Profile = { Name = "RtPrime", Type = "Rt:CORE" },
                        Runtime = { Locked = "True" },
                    },
                },
            }
        end,
        meta = function(_, name)
            local tier = name:match("RtPrime/(.+)$")
            if tier then return { Runtime = { Locked = "False" } } end
            return { Runtime = { Locked = "True" } }
        end,
    }
end
package.loaded["ui"] = {
    go = function(screen, params) entered = { screen = screen, params = params } end,
    back = function() end,
}

local Screen = require("ui.screens.rt_profiles")
Screen.enter({ focus = "RtPrime/std" })
Screen.update(1.0) -- finish the intro transition into browse mode

local found = {}
for i, row in ipairs(Screen.rows) do
    if row.tier then found[row.tier] = i end
end
assert(found.lite and found.std and found.max, "all three family tiers must be editable rows")

Screen.sel = found.std
Screen.pad("A")
Screen.update(1.0) -- finish the drawer transition and open rt_editor

assert(entered and entered.screen == "rt_editor", "tier row must open the common profile editor")
assert(entered.params.profile == "RtPrime/std", "editor must receive the family/tier path")
assert(entered.params.dir == family_dir .. "/std", "editor must write only the selected tier overlay")
assert(entered.params.locked == false, "tier lock metadata must be read from the tier, not its locked parent")

os.execute("rm -rf " .. string.format("%q", tmp))
print("Rt:Core tier editor picker tests: OK")
