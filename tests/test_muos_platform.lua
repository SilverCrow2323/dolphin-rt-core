#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local settings = { muos_profile = "auto" }
package.preload["core.settings"] = function()
    return { get = function(key) return settings[key] end }
end
package.preload["core.shell"] = function()
    return {
        shq = function(value) return "'" .. tostring(value):gsub("'", "'\\''") .. "'" end,
        first = function() return "muOS Jacaranda 2601.1" end,
    }
end

local Platform = require("core.muos_platform")
local function expect(value, message)
    if not value then error(message or "assertion failed", 2) end
end

expect(Platform.resolve("muOS 2601.1 Jacaranda") == "not_andromeda",
    "Jacaranda must resolve to the initial/non-Andromeda profile")
expect(Platform.resolve("muOS 2606.0 Andromeda") == "andromeda",
    "Andromeda must resolve to the alternative profile")
expect(Platform.resolve("unknown firmware") == "not_andromeda",
    "non-Andromeda versions must remain in the != Andromeda branch")

settings.muos_profile = "andromeda"
expect(Platform.profile() == "andromeda", "manual Andromeda override must win")
expect(Platform.label() == "FORCE = ANDROMEDA", "manual Andromeda label must be explicit")

settings.muos_profile = "not_andromeda"
expect(Platform.profile() == "not_andromeda", "manual != Andromeda override must win")
expect(Platform.label() == "FORCE != ANDROMEDA", "manual non-Andromeda label must be explicit")

print("muOS firmware profile tests: PASS")
