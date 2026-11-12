-- Native Dolphin Graphics Mods: catalog matching and per-game profile contract.
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local Paths = require("core.paths")
local Shell = require("core.shell")
local JSON = require("core.json")

local tmp = os.tmpname()
os.remove(tmp)
assert(os.execute("mkdir -p " .. Shell.shq(tmp)) == 0)
Paths.root_emu = tmp

local function mkdir(path)
    local ok = os.execute("mkdir -p " .. Shell.shq(path))
    assert(ok == true or ok == 0, "mkdir failed: " .. path)
end

local function write(path, body)
    local f = assert(io.open(path, "wb"))
    f:write(body)
    f:close()
end

local function metadata(title, author)
    return JSON.encode({meta = {title = title, author = author or "Fixture"}, groups = {}, features = {}, assets = {}})
end

local sys = tmp .. "/Sys/Load/GraphicMods"
local user = tmp .. "/Load/GraphicMods"
local bloom = sys .. "/All Games Bloom Removal"
local galaxy = sys .. "/Super Mario Galaxy"
local zelda = sys .. "/Zelda Only"
local custom = user .. "/All User Shaders"

for _, dir in ipairs({bloom, galaxy .. "/gameids", zelda .. "/gameids", custom}) do mkdir(dir) end
write(bloom .. "/metadata.json", metadata("Bloom Removal", "Dolphin Team"))
write(bloom .. "/all.txt", "")
write(galaxy .. "/metadata.json", metadata("Super Mario Galaxy Bloom"))
write(galaxy .. "/gameids/RMGE01.txt", "")
write(zelda .. "/metadata.json", metadata("Zelda Only"))
write(zelda .. "/gameids/RMGE01.txt.disabled", "")
write(custom .. "/metadata.json", metadata("User Shader Pack", "Test Author"))
write(custom .. "/all.txt", "")

local Graphics = require("core.graphics_mods")
local game = {id = "RMGE01", title = "Super Mario Galaxy"}

local function by_name(items, name)
    for _, item in ipairs(items) do
        if item.name == name then return item end
    end
end

local catalog = Graphics.list_for(nil)
assert(by_name(catalog, "All Games Bloom Removal"), "all-games system mod appears in catalog")
assert(by_name(catalog, "Super Mario Galaxy"), "game-specific system mod appears in catalog")
assert(by_name(catalog, "Zelda Only"), "non-matching game mod appears in global catalog")
assert(by_name(catalog, "All User Shaders"), "user all-games mod appears in catalog")

local rows = Graphics.list_for(game)
local bloom_item = assert(by_name(rows, "All Games Bloom Removal"), "all-games marker matches game")
local galaxy_item = assert(by_name(rows, "Super Mario Galaxy"), "nested GameID marker matches game")
assert(by_name(rows, "All User Shaders"), "user all-games marker matches game")
assert(not by_name(rows, "Zelda Only"), "non-matching game mod is excluded")
for _, item in ipairs(rows) do
    assert(item.enabled == false, "mods are disabled by default: " .. item.name)
end

assert(Graphics.set_enabled(game, bloom_item, true), "enable built-in mod")
rows = Graphics.list_for(game)
assert(by_name(rows, "All Games Bloom Removal").enabled, "per-game profile enables selected built-in mod")
assert(not by_name(rows, "Super Mario Galaxy").enabled, "other mods remain disabled")

assert(Graphics.set_enabled(game, by_name(rows, "All User Shaders"), true), "enable user mod")
rows = Graphics.list_for(game)
assert(by_name(rows, "All User Shaders").enabled, "user mod state is also per-game")
assert(by_name(rows, "All Games Bloom Removal").enabled, "saving another mod preserves earlier choice")

assert(Graphics.set_all(game, rows, false), "disable all mods")
rows = Graphics.list_for(game)
for _, item in ipairs(rows) do
    assert(not item.enabled, "set_all(false) disables " .. item.name)
end

local selected = { ["All Games Bloom Removal"] = true }
assert(Graphics.set_selection(game, rows, selected), "write selected set")
rows = Graphics.list_for(game)
assert(by_name(rows, "All Games Bloom Removal").enabled, "selection persists")
assert(not by_name(rows, "All User Shaders").enabled, "unselected user mods stay disabled")

local profile_path = Graphics.config_path(game.id)
local profile = JSON.decode(assert((function()
    local f = assert(io.open(profile_path, "rb"))
    local raw = f:read("*a"); f:close(); return raw
end)()))
assert(type(profile) == "table" and type(profile.mods) == "table", "Dolphin profile JSON shape")
local found_system, found_user = false, false
for _, entry in ipairs(profile.mods) do
    assert(type(entry.source) == "string" and type(entry.path) == "string", "native source/path fields")
    if entry.source == "system" and entry.path == "All Games Bloom Removal" and entry.enabled == true then
        found_system = true
    elseif entry.source == "user" and entry.path == "All User Shaders" and entry.enabled == false then
        found_user = true
    end
end
assert(found_system, "built-in mod saved with source=system and relative path")
assert(found_user, "user mod saved with source=user and relative path")

-- The official Sys tree must never be moved, rewritten or parked.
assert(io.open(bloom .. "/metadata.json", "rb"), "built-in metadata remains in Sys")
assert(io.open(bloom .. "/all.txt", "rb"), "built-in all-games marker remains in Sys")

os.execute("rm -rf " .. Shell.shq(tmp))
print("Native Dolphin Graphics Mods: matching and per-game profile tests passed")
