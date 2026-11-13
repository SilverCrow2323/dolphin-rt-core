-- Exercise the live Controller Profiles -> controller_map input path.
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local path = "workshop/controller/GameCube/Default/GCPadNew.ini"
local files = {
    [path] = {
        "[GCPad1]",
        "Device = SDL/0/muOS-Keys",
        "Buttons/A = `Button 1`",
        "Buttons/B = `Button 0`",
        "Buttons/Z = `Button 11`",
    },
}
local fail_write = false
local notices = {}
local function copy(lines)
    local out = {}
    for i, line in ipairs(lines or {}) do out[i] = line end
    return out
end
local Ini = {
    read_lines = function(file) return copy(files[file] or {}) end,
    set = function(lines, section, key, value)
        local current
        for i, line in ipairs(lines) do
            local sec = line:match("^%s*%[([^%]]+)%]")
            if sec then current = sec
            elseif current == section then
                local k = line:match("^%s*([^=]+)%s*=")
                if k and k:match("^%s*(.-)%s*$") == key then
                    lines[i] = key .. " = " .. tostring(value)
                    return
                end
            end
        end
        lines[#lines + 1] = key .. " = " .. tostring(value)
    end,
    write_lines = function(file, lines)
        if fail_write then return false, "read only" end
        files[file] = copy(lines)
        return true
    end,
}
package.preload["core.ini_edit"] = function() return Ini end
package.preload["ui.kit"] = function()
    return { set_accent = function() end }
end
package.preload["ui.sfx"] = function() return { play = function() end } end
package.preload["ui.notify"] = function()
    return { show = function(kind, message) notices[#notices + 1] = {kind, message} end }
end
package.loaded["ui"] = { back = function() end }
love = { graphics = { newImage = function() error("no image in input test") end } }

local Screen = require("ui.screens.controller_map")
Screen.enter({dir = "workshop/controller/GameCube/Default", name = "Default", system = "GameCube"})
local function select(key)
    for i, row in ipairs(Screen.rows) do
        if row.key == key then Screen.sel = i; return end
    end
    error("missing mapping row " .. key)
end
local function value(key)
    for _, row in ipairs(Screen.rows) do if row.key == key then return row.value end end
end

select("Buttons/A")
Screen.pad("A")
assert(Screen.remap and Screen.remap.phase == "wait")
assert(Screen.raw_pad("leftstick"), "SDL leftstick event must be captured")
assert(Screen.remap.captured == 11 and Screen.remap.new_value == "`Button 11`")
assert(Screen.remap.duplicate and Screen.remap.duplicate.key == "Buttons/Z")

-- A failed save must not claim success, discard the confirmation, or mutate the row.
fail_write = true
Screen.pad("A")
assert(Screen.remap and Screen.remap.phase == "confirm",
    "failed persistence must leave the remap confirmation open")
assert(value("Buttons/A") == "`Button 1`",
    "failed persistence must restore the previous in-memory value")
assert(notices[#notices][1] == "error", "failed persistence must notify an error")

-- Retry the same confirmation after storage becomes writable.
fail_write = false
Screen.pad("A")
assert(Screen.remap == nil, "successful retry must close confirmation")
assert(value("Buttons/A") == "`Button 11`")
assert(table.concat(files[path], "\n"):match("Buttons/A = `Button 11`"))
assert(notices[#notices][1] == "success")

-- Numeric raw events and the SDL alias both resolve to the same index.
select("Buttons/B")
Screen.pad("A")
assert(Screen.raw_pad(11))
assert(Screen.remap.new_value == "`Button 11`")
Screen.pad("B")

-- The Wii preset is read from WiimoteNew.ini and its Home key stays on Andromeda 8.
local wii_path = "workshop/controller/Wii/Default/WiimoteNew.ini"
files[wii_path] = {
    "[Wiimote1]", "Device = SDL/0/muOS-Keys",
    "Buttons/A = `Button 1`", "Buttons/B = `Button 0`",
    "Buttons/Home = `Button 8`", "Nunchuk/Buttons/C = `Button 4`",
    "Nunchuk/Buttons/Z = `Button 5`",
}
Screen.enter({dir = "workshop/controller/Wii/Default", name = "Default", system = "Wii"})
assert(value("Buttons/Home") == "`Button 8`")
assert(value("Nunchuk/Buttons/C") == "`Button 4`")
assert(value("Nunchuk/Buttons/Z") == "`Button 5`")

print("Controller Map Andromeda input/persistence: all tests passed")
