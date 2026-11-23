#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local commands = {}
package.preload["core.paths"] = function() return { root_emu = "/emu" } end
package.preload["core.shell"] = function()
    return {
        shq = function(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end,
        exec = function(command) commands[#commands + 1] = command; return 0 end,
        popen = function(command)
            if command:find("Textures%.off") then return "Parked Mod/\n" end
            if command:find("Textures") then return "Active Mod/\n" end
            if command:find("GraphicMods%.off") then return "Parked Gfx/\n" end
            if command:find("GraphicMods") then return "Active Gfx/\n" end
            return ""
        end,
    }
end

local Mods = require("core.mods")
local cat = Mods.CATS[1]
local applicable = Mods.for_game(cat, { id = "GZLE01" }, { "Active Mod", "Parked Mod" }, "/fake/Load")
assert(#applicable == 1 and applicable[1].name == "Active Mod" and not applicable[1].parked,
    "per-game launch plans must not expose a globally parked mod")
local graphic_cat
for _, item in ipairs(Mods.CATS) do if item.id == "GraphicMods" then graphic_cat = item end end
assert(graphic_cat and graphic_cat.legacy, "GraphicMods should be recognized as global-only")
local graphic_entries = Mods.for_game(graphic_cat, { id = "GZLE01" }, {}, "/fake/Load")
assert(#graphic_entries == 2, "global-only GraphicMods must remain available for toggling from a per-game Mod Vault view")
local entry = { name = "Bloom Removal", parked = false, is_dir = true }
local ok, err = Mods.set_enabled(cat, entry, false, "/fake/Load")
assert(ok, err or "global disable should succeed")
assert(entry.parked == true, "disabled mod must move to the parked shelf")
assert(commands[#commands]:find("/fake/Load/Textures/Bloom Removal", 1, true),
    "source path must stay inside the active category")
assert(commands[#commands]:find("/fake/Load/Textures.off/Bloom Removal", 1, true),
    "destination must be the category .off shelf")

local count = #commands
assert(Mods.set_enabled(cat, entry, false, "/fake/Load") == true,
    "setting an already-disabled mod to disabled is idempotent")
assert(#commands == count, "idempotent operation must not spawn a move")

ok, err = Mods.set_enabled(cat, entry, true, "/fake/Load")
assert(ok, err or "global enable should succeed")
assert(entry.parked == false, "enabled mod must return to the active Load tree")

local before = #commands
local unsafe = Mods.set_enabled(cat, { name = "../escape", parked = false }, false, "/fake/Load")
assert(unsafe == false, "path traversal must be rejected")
assert(#commands == before, "unsafe name must never reach the shell")

local changed, errors = Mods.set_all_enabled(cat, false, "/fake/Load")
assert(changed == 1, "bulk disable should move the active entry only")
assert(#errors == 0, "bulk disable should report no errors")
print("Mod Vault reversible global toggles: OK")
