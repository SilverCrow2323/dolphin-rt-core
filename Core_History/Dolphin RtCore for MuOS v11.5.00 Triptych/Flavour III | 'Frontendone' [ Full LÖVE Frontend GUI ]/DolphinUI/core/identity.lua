-- core/identity.lua — Rt:Identity bundle.
-- One JSON file per identity in data/identities/<slug>.json.
local json = require("core.json")
local sh   = require("core.sh")

local M = {}
local DIR = "workshop/identities"

local function slugify(name)
    name = tostring(name or "identity")
    name = name:gsub("[^%w_%-]", "_"):gsub("_+", "_")
    name = name:gsub("^_+", ""):gsub("_+$", "")
    if name == "" then name = "identity" end
    return name:sub(1, 40)
end

local function path_for(slug) return DIR .. "/" .. slug .. ".json" end

local function read_json(p)
    local f = io.open(p, "r"); if not f then return nil end
    local c = f:read("*a"); f:close()
    local ok, d = pcall(json.decode, c)
    if not ok or type(d) ~= "table" then return nil end
    return d
end

function M.list()
    sh.mkdir_p(DIR)
    local out = {}
    local h = io.popen('ls -1 ' .. sh.shq(DIR) .. '/*.json 2>/dev/null')
    if not h then return out end
    for line in h:lines() do
        local name = line:match("([^/]+)%.json$")
        if name then
            local d = read_json(line)
            if d then d._slug = name; out[#out + 1] = d end
        end
    end
    h:close()
    table.sort(out, function(a, b)
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)
    return out
end

function M.load(slug)
    if not slug then return nil end
    return read_json(path_for(slug))
end

function M.save(id)
    if type(id) ~= "table" or not id.name then return false end
    sh.mkdir_p(DIR)
    local slug = id._slug or slugify(id.name)
    id._slug = slug
    return sh.atomic_write(path_for(slug), json.encode(id))
end

function M.delete(slug)
    if not slug then return false end
    os.remove(path_for(slug))
    return true
end

function M.default()
    return {
        name = "Default", color = "#8C59F2", icon = "star",
        created = os.date("%Y-%m-%dT%H:%M:%S"),
        rtcoreprofile = "Default", rtcoreprofile_variant = "std",
        controller = "Default", hotkeys = "Default", logger = "Disabled",
        gamesettings_mode = "all", gamesettings_list = {},
        cheats = false, mods = {},
        overlay_fps = true, overlay_vps = false,
        overlay_speed = false, overlay_osd = true,
    }
end

function M.ensure_default()
    sh.mkdir_p(DIR)
    local f = io.open(path_for("Default"), "r")
    if f then f:close(); return end
    M.save(M.default())
end

-- Snapshot of the current runtime settings → identity table.
function M.from_prefs(prefs, extra)
    local d = M.default()
    if type(prefs) == "table" then
        for k, v in pairs(prefs) do d[k] = v end
    end
    if type(extra) == "table" then
        for k, v in pairs(extra) do d[k] = v end
    end
    return d
end

return M
