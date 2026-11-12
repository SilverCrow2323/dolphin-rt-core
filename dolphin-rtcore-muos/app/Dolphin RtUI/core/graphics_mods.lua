-- core/graphics_mods.lua — native Dolphin Graphics Mod catalog and profiles.
--
-- Dolphin discovers built-in mods below Sys/Load/GraphicMods and user mods
-- below Load/GraphicMods. Per-game enablement lives in Config/GraphicMods/<ID>.json.
-- We only edit that user profile; Sys content is never moved or modified.

local JSON = require("core.json")
local FS = require("core.fs")
local Shell = require("core.shell")
local Paths = require("core.paths")

local M = {}
local function emu_root()
    return os.getenv("DOLPHINUI_GRAPHICSMOD_ROOT") or Paths.root_emu
end

local function shq(s) return Shell.shq(s) end
local function join(a, b) return a .. "/" .. b end

local function list_directories(root)
    local out = {}
    local raw = Shell.popen("ls -1Ap " .. shq(root) .. " 2>/dev/null", 2) or ""
    for line in raw:gmatch("[^\n]+") do
        if line:sub(-1) == "/" then
            local name = line:sub(1, -2)
            if name ~= "" and name:sub(1, 1) ~= "." then
                out[#out + 1] = name
            end
        end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

-- Mirrors Dolphin's GetTextureDirectoriesWithGameId matching:
-- folder name == GameID / 3-char prefix, or a nested *.txt marker named
-- GameID, prefix, or all.
local function marker_map(root)
    local map = {}
    local raw = Shell.popen("find " .. shq(root) ..
        " -mindepth 2 -type f -iname '*.txt' -print 2>/dev/null", 2) or ""
    for file in raw:gmatch("[^\n]+") do
        local relative = file:sub(#root + 2)
        local folder = relative:match("^([^/]+)/")
        local marker = relative:match("([^/]+)%.txt$")
        if folder and marker then
            map[folder] = map[folder] or {}
            map[folder][marker] = true
        end
    end
    return map
end

local function match_scope(name, markers, game_id, direct_name, direct_scope)
    if not game_id or game_id == "" then
        return (markers and markers.all) and "all" or "catalog"
    end
    if name == direct_name then return direct_scope end
    local prefix = game_id:sub(1, 3)
    markers = markers or {}
    if markers.all then return "all" end
    if markers[game_id] then return "id" end
    if markers[prefix] then return "prefix" end
    return nil
end

local function read_metadata(folder)
    local f = io.open(join(folder, "metadata.json"), "rb")
    if not f then return nil end
    local raw = f:read("*a") or ""
    f:close()
    local doc = JSON.decode(raw)
    if type(doc) ~= "table" then return nil end
    local meta = type(doc.meta) == "table" and doc.meta or {}
    return {
        title = type(meta.title) == "string" and meta.title or nil,
        author = type(meta.author) == "string" and meta.author or nil,
        description = type(meta.description) == "string" and meta.description or "",
    }
end

local function item_key(source, path)
    return tostring(source) .. "|" .. tostring(path)
end

-- One-time recovery of folders parked by the previous Rt:Core --mods switch.
-- Only user data is restored; the official Sys tree is never touched.
function M.restore_legacy_user_mods()
    local active = join(emu_root(), "Load/GraphicMods")
    local parked = active .. ".off"
    if not FS.is_dir(parked) then return 0 end
    FS.mkdir_p(active)
    local restored = 0
    for _, name in ipairs(list_directories(parked)) do
        local source = join(parked, name)
        local destination = join(active, name)
        if FS.is_dir(source) and not FS.exists(destination) and not FS.is_dir(destination) then
            local command = "mv " .. shq(source) .. " " .. shq(active) .. " 2>/dev/null"
            local ok = os.execute(command)
            if ok == true or ok == 0 then
                if FS.is_dir(destination) then restored = restored + 1 end
            end
        end
    end
    os.execute("rmdir " .. shq(parked) .. " 2>/dev/null")
    return restored
end

local function profile_path(game_id)
    return join(emu_root(), "Config/GraphicMods/" .. game_id .. ".json")
end

local function load_profile(game_id)
    local path = profile_path(game_id)
    local raw = FS.read(path)
    if not raw then return {mods = {}}, path end
    local profile, err = JSON.decode_err(raw)
    if type(profile) ~= "table" then
        return nil, "Dolphin Graphics Mods profile is invalid: " .. tostring(err or path)
    end
    if profile.mods == nil then profile.mods = {} end
    if type(profile.mods) ~= "table" then
        return nil, "Dolphin Graphics Mods profile has an invalid mods list"
    end
    return profile, path
end

local function enabled_map(profile)
    local result = {}
    for _, entry in ipairs(profile.mods or {}) do
        if type(entry) == "table" and type(entry.source) == "string" and
           type(entry.path) == "string" then
            result[item_key(entry.source, entry.path)] = entry.enabled == true
        end
    end
    return result
end

function M.list_for(game)
    local emu = emu_root()
    local game_id = game and tostring(game.id or ""):upper() or nil
    if game_id and not game_id:match("^[A-Z0-9]+$") then return {} end

    local profile = {mods = {}}
    if game_id and game_id ~= "" then
        local loaded, err = load_profile(game_id)
        if not loaded then return {}, err end
        profile = loaded
    end
    local enabled = enabled_map(profile)
    local out = {}
    local roots = {
        {source = "system", path = join(emu, "Sys/Load/GraphicMods")},
        {source = "user", path = join(emu, "Load/GraphicMods")},
    }

    for _, spec in ipairs(roots) do
        local markers = marker_map(spec.path)
        local direct_name, direct_scope
        if game_id and game_id ~= "" then
            if FS.is_dir(join(spec.path, game_id)) then
                direct_name, direct_scope = game_id, "id"
            else
                local prefix = game_id:sub(1, 3)
                if FS.is_dir(join(spec.path, prefix)) then
                    direct_name, direct_scope = prefix, "prefix"
                end
            end
        end
        for _, name in ipairs(list_directories(spec.path)) do
            local scope = match_scope(name, markers[name], game_id, direct_name, direct_scope)
            if scope then
                local folder = join(spec.path, name)
                local meta = read_metadata(folder)
                if meta then
                    local item = {
                        name = name,
                        title = meta.title or name,
                        author = meta.author or (spec.source == "system" and "Dolphin" or "User"),
                        description = meta.description or "",
                        source = spec.source,
                        path = name,
                        scope = scope,
                        enabled = false,
                    }
                    if game_id then
                        item.enabled = enabled[item_key(item.source, item.path)] == true
                    end
                    out[#out + 1] = item
                end
            end
        end
    end

    table.sort(out, function(a, b)
        if a.scope ~= b.scope then
            local order = {id = 1, prefix = 2, all = 3, catalog = 4}
            return (order[a.scope] or 9) < (order[b.scope] or 9)
        end
        if a.title:lower() == b.title:lower() then
            if a.source ~= b.source then return a.source == "system" end
            return a.name:lower() < b.name:lower()
        end
        return a.title:lower() < b.title:lower()
    end)
    return out
end

local function save_changes(game, changes)
    if not game or type(game.id) ~= "string" or
       not game.id:upper():match("^[A-Z0-9]+$") then
        return false, "a valid Game ID is required"
    end
    local id = game.id:upper()
    local profile, path_or_error = load_profile(id)
    if not profile then return false, path_or_error end
    local path = path_or_error
    local found = {}
    for _, entry in ipairs(profile.mods) do
        if type(entry) == "table" then
            found[item_key(entry.source, entry.path)] = entry
        end
    end

    for _, change in ipairs(changes or {}) do
        if type(change) == "table" and
           (change.source == "system" or change.source == "user") and
           type(change.path) == "string" and change.path ~= "" and
           not change.path:find("..", 1, true) and not change.path:find("/", 1, true) then
            local key = item_key(change.source, change.path)
            local entry = found[key]
            if not entry then
                entry = {source = change.source, path = change.path, weight = 0}
                profile.mods[#profile.mods + 1] = entry
                found[key] = entry
            end
            entry.enabled = change.enabled == true
        end
    end

    FS.mkdir_p(join(emu_root(), "Config/GraphicMods"))
    if not FS.atomic_write(path, JSON.encode(profile) .. "\n") then
        return false, "could not write " .. path
    end
    return true
end

function M.set_enabled(game, item, enabled)
    return save_changes(game, {{source = item.source, path = item.path, enabled = enabled}})
end

function M.set_all(game, items, enabled)
    local changes = {}
    for _, item in ipairs(items or {}) do
        changes[#changes + 1] = {source = item.source, path = item.path, enabled = enabled}
    end
    if #changes == 0 then return true end
    return save_changes(game, changes)
end

function M.set_selection(game, items, selected)
    selected = selected or {}
    local changes = {}
    for _, item in ipairs(items or {}) do
        local selected_value = selected[item.source .. "|" .. item.path]
        if selected_value == nil then selected_value = selected[item.name] end
        changes[#changes + 1] = {
            source = item.source, path = item.path,
            enabled = selected_value == true,
        }
    end
    if #changes == 0 then return true end
    return save_changes(game, changes)
end

function M.profile_exists(game_id)
    if type(game_id) ~= "string" or not game_id:upper():match("^[A-Z0-9]+$") then
        return false
    end
    return FS.exists(profile_path(game_id:upper()))
end

-- Migrate selections from the old per-game RTID [MODS] Selected field.
-- Only matching user mods are considered; new built-in Sys mods stay disabled.
function M.migrate_legacy_selection(game, legacy_selected)
    if not game or type(game.id) ~= "string" or
       not game.id:upper():match("^[A-Z0-9]+$") then
        return false, "a valid Game ID is required"
    end
    M.restore_legacy_user_mods()
    if M.profile_exists(game.id) then return true, 0 end
    if type(legacy_selected) ~= "table" or next(legacy_selected) == nil then
        return true, 0
    end

    local rows = M.list_for(game)
    local selected, migrated = {}, 0
    for _, item in ipairs(rows) do
        if item.source == "user" and legacy_selected[item.name] then
            selected[item.source .. "|" .. item.path] = true
            migrated = migrated + 1
        end
    end
    if migrated == 0 then return true, 0 end
    local ok, err = M.set_selection(game, rows, selected)
    if not ok then return false, err end
    return true, migrated
end

function M.config_path(game_id)
    return profile_path(tostring(game_id or ""):upper())
end

return M
