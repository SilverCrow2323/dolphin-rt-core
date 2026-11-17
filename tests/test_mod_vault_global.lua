#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local commands = {}
package.preload["core.paths"] = function()
    return { root_emu = "/emu" }
end
package.preload["core.shell"] = function()
    return {
        shq = function(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end,
        exec = function(command) commands[#commands + 1] = command; return 0 end,
        popen = function(command)
            if command:find("Textures%.off") then return "Parked Mod/\n" end
            if command:find("Textures") then return "Active Mod/\nAll/\n" end
            return ""
        end,
    }
end

local Mods = require("core.mods")
local cat = Mods.CATS[1]
local function expect(value, message)
    if not value then error(message or "assertion failed", 2) end
end

local entries = Mods.entries(cat, "/fake/Load")
expect(#entries == 3, "global catalogue should include active and parked entries")
local parked
for _, entry in ipairs(entries) do if entry.parked then parked = entry end end
expect(parked and parked.name == "Parked Mod", "parked entry must be marked")

local global_rows = Mods.for_game(cat, nil, nil, "/fake/Load")
expect(#global_rows == 3, "global view must include active and parked items")
local game_rows = Mods.for_game(cat, { id = "GZLE01" }, { "Game" }, "/fake/Load")
expect(#game_rows == 1 and game_rows[1].name == "All",
    "globally parked mods must not re-enter per-game launch selection")

local active = { name = "Active Mod", parked = false, is_dir = true }
local ok, err = Mods.set_enabled(cat, active, false, "/fake/Load")
expect(ok, err or "global disable should succeed")
expect(active.parked == true, "disabled mod must move to the parked state")
expect(commands[#commands]:find("/fake/Load/Textures/Active Mod", 1, true),
    "source path must remain inside the selected Load category")
expect(commands[#commands]:find("/fake/Load/Textures.off/Active Mod", 1, true),
    "destination must be the reversible category .off shelf")

local before = #commands
local unchanged, state = Mods.set_enabled(cat, active, false, "/fake/Load")
expect(unchanged and state == "unchanged", "repeated disable should be idempotent")
expect(#commands == before, "idempotent disable must not invoke the shell")

ok, err = Mods.set_enabled(cat, active, true, "/fake/Load")
expect(ok, err or "global re-enable should succeed")
expect(active.parked == false, "re-enabled mod must return to Load/")

before = #commands
local unsafe = Mods.set_enabled(cat, { name = "../escape", parked = false }, false, "/fake/Load")
expect(unsafe == false, "path traversal must be rejected")
expect(#commands == before, "unsafe names must never reach the shell")
local unknown = Mods.set_enabled({ id = "../outside" }, { name = "x" }, false, "/fake/Load")
expect(unknown == false, "unknown categories must be rejected")
local control_name = "bad\nname"
local control_entry = Mods.set_enabled(cat, { name = control_name }, false, "/fake/Load")
expect(control_entry == false, "control characters in mod names must be rejected")
local native = Mods.set_enabled(Mods.CATS[5], { name = "Graphic" }, false, "/fake/Load")
expect(native == false, "native Graphics Mods stay on their per-game manager")

local changed, errors = Mods.set_all_enabled(cat, false, "/fake/Load")
expect(changed == 2, "bulk disable should move the two active entries only")
expect(#errors == 0, "bulk disable should report no errors")


local plan_path = os.tmpname()
local plan_count, plan_err = Mods.write_plan({ id = "GZLE01" }, { "Game" }, nil, "/fake/Load", plan_path)
expect(plan_count and not plan_err, "per-game launch plan should be generated")
local plan_file = assert(io.open(plan_path, "r"))
local plan = plan_file:read("*a")
plan_file:close()
os.remove(plan_path)
expect(not plan:find("ON|Textures|GZLE01", 1, true),
    "globally parked folders must never be added to the per-game launch plan")
expect(plan:find("LINK|Textures|All|GZLE01", 1, true),
    "active global All mod should retain its existing per-game link behavior")

package.preload["core.graphics_mods"] = function()
    return { list_for = function(game) return { { name = "Native Graphics", enabled = true, game = game } } end }
end
local native_rows = Mods.for_game(Mods.CATS[5], { id = "GZLE01" }, { "Game" }, "/fake/Load")
expect(#native_rows == 1 and native_rows[1].name == "Native Graphics",
    "native Graphics Mods must continue to use their existing per-game manager")

print("Mod Vault reversible global toggles: PASS")
