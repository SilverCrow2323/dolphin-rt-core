-- Folder diagnostics and the explicit "Registratore Z" workflow.
-- The scanner never mutates a ROM folder. Renaming is a separate, confirmed action.
local FS = require("core.fs")
local JSON = require("core.json")
local Shell = require("core.shell")
local Settings = require("core.settings")
local Paths = require("core.paths")

local M = {}

local ROM_EXPR = [[\( -iname '*.iso' -o -iname '*.gcm' -o -iname '*.rvz' -o -iname '*.gcz' -o -iname '*.ciso' -o -iname '*.wbfs' -o -iname '*.wia' \)]]
local ASSIGN_PATH = os.getenv("RT_MUOS_ASSIGN_MAP") or "/run/muos/storage/info/manifest/assign.json"
local SKIP_PATH = os.getenv("RT_MUOS_SKIP_INI") or "/opt/muos/share/info/skip.ini"

function M.normalize_alias(name)
    return tostring(name or ""):lower():gsub("[^a-z0-9]", "")
end

local LUA_PATTERN_ESCAPES = {
    ["^"] = "%", ["$"] = "%", ["("] = "%", [")"] = "%", ["%"] = "%",
    ["."] = "%", ["["] = "%", ["]"] = "%", ["+"] = "%", ["-"] = "%",
}

local function glob_match(glob, value)
    local p = tostring(glob or "")
    local out = { "^" }
    for i = 1, #p do
        local ch = p:sub(i, i)
        if ch == "*" then out[#out + 1] = ".*"
        elseif ch == "?" then out[#out + 1] = "."
        elseif LUA_PATTERN_ESCAPES[ch] then out[#out + 1] = LUA_PATTERN_ESCAPES[ch] .. ch
        else out[#out + 1] = ch end
    end
    out[#out + 1] = "$"
    return tostring(value or ""):match(table.concat(out)) ~= nil
end

local function load_skip()
    local rules = {}
    local raw = FS.read(SKIP_PATH) or ""
    for line in raw:gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and line:sub(1, 1) ~= "#" then rules[#rules + 1] = line end
    end
    return rules
end

local function load_assign()
    local raw = FS.read(ASSIGN_PATH)
    if not raw then return {} end
    local ok, map = pcall(JSON.decode, raw)
    return (ok and type(map) == "table") and map or {}
end

local function infer_system(name)
    local n = M.normalize_alias(name)
    if n:find("gamecube", 1, true) or n == "gc" or n == "ngc"
       or n:find("nintendogc", 1, true) then return "GC" end
    if n:find("wii", 1, true) then return "Wii" end
    return nil
end
M.infer_system = infer_system

local function system_from_map(value)
    local v = tostring(value or ""):lower()
    if v:find("gamecube", 1, true) then return "GC" end
    if v:find("wii", 1, true) then return "Wii" end
    return nil
end

local function has_roms(path)
    local cmd = "find " .. Shell.shq(path) .. " -maxdepth 5 -type f " ..
        ROM_EXPR .. " -print -quit 2>/dev/null"
    local sample = Shell.first(cmd, 10)
    return type(sample) == "string" and sample ~= ""
end

local function is_directory_skip_rule(rule)
    -- Current muOS rules that apply to directories. The remaining entries in
    -- skip.ini are file names/extensions and must not be reported as folder bans.
    return rule == ".*" or rule == "_*" or rule == "/img*"
end

local function skip_reasons(name, full_path, rules, root)
    local reasons = {}
    local relative_path = "/" .. tostring(name or "")
    if type(root) == "string" and root ~= "" then
        local prefix = root:gsub("/+$", "") .. "/"
        if tostring(full_path):sub(1, #prefix) == prefix then
            relative_path = tostring(full_path):sub(#prefix + 1)
            relative_path = "/" .. relative_path
        end
    end
    for _, rule in ipairs(rules) do
        if is_directory_skip_rule(rule) then
            local candidate = rule:sub(1, 1) == "/" and relative_path or name
            if glob_match(rule, candidate) then reasons[#reasons + 1] = rule end
        end
    end
    return reasons
end
M.skip_reasons = skip_reasons

local function assigned_system(assign, alias)
    return system_from_map(assign[alias])
end

local function is_scan_root(path)
    for _, entry in ipairs(Settings.get("rom_paths") or {}) do
        if entry.path and entry.path:gsub("/+$", "") == path:gsub("/+$", "") then return true end
    end
    return false
end

function M.inspect(path)
    if type(path) ~= "string" or path == "" or not FS.is_dir(path) then
        return nil, "selected path is not an accessible directory"
    end
    local name = path:match("([^/]+)$") or path
    local alias = M.normalize_alias(name)
    local root, best_len
    local candidates = {}
    for _, candidate in ipairs(Settings.rom_root_candidates and Settings.rom_root_candidates() or {}) do
        candidates[#candidates + 1] = candidate
    end
    for _, entry in ipairs(Settings.get("rom_paths") or {}) do
        candidates[#candidates + 1] = entry.path
    end
    for _, candidate in ipairs(candidates) do
        if type(candidate) == "string" and candidate ~= "" then
            candidate = candidate:gsub("/+$", "")
            local prefix = candidate .. "/"
            if path:sub(1, #prefix) == prefix and (not best_len or #candidate > best_len) then
                root, best_len = candidate, #candidate
            end
        end
    end
    local reasons = skip_reasons(name, path, load_skip(), root)
    local guess = infer_system(name)
    local mapped = assigned_system(load_assign(), alias)
    local roms = has_roms(path)
    local status
    if #reasons > 0 then status = "skip-match"
    elseif guess and not mapped then status = "unmapped"
    elseif guess and mapped then status = "mapped"
    elseif roms then status = "review"
    else status = "empty" end
    return {
        path = path, name = name, alias = alias,
        inferred_system = guess, mapped_system = mapped,
        has_roms = roms, skip_matches = reasons,
        status = status, is_scan_root = is_scan_root(path),
    }
end

function M.root_report()
    local out, seen = {}, {}
    local roots = {}
    for _, path in ipairs(Settings.rom_root_candidates and Settings.rom_root_candidates() or {}) do
        roots[#roots + 1] = path
    end
    for _, entry in ipairs(Settings.get("rom_paths") or {}) do
        roots[#roots + 1] = entry.path
    end
    for _, path in ipairs(roots) do
        if type(path) == "string" and path ~= "" and not seen[path] then
            seen[path] = true
            local accessible = FS.is_dir(path)
            out[#out + 1] = {
                path = path,
                accessible = accessible,
                has_roms = accessible and has_roms(path) or false,
            }
        end
    end
    return out
end

function M.scan()
    local roots, root_seen = {}, {}
    local function add_root(path)
        if type(path) ~= "string" or path == "" then return end
        path = path:gsub("/+$", "")
        if path ~= "" and not root_seen[path] then
            root_seen[path] = true
            roots[#roots + 1] = path
        end
    end
    for _, path in ipairs(Settings.rom_root_candidates and Settings.rom_root_candidates() or {}) do
        add_root(path)
    end
    -- Also include manually configured roots, which may live outside the
    -- common muOS SD-card mount paths.
    for _, entry in ipairs(Settings.get("rom_paths") or {}) do
        add_root(entry.path)
    end

    local rules, assign, out, seen = load_skip(), load_assign(), {}, {}
    for _, root in ipairs(roots) do
        if FS.is_dir(root) then
            local cmd = "find " .. Shell.shq(root) .. " -mindepth 1 -maxdepth 3 -type d -print 2>/dev/null"
            local listing = Shell.popen(cmd, 8) or ""
            for path in listing:gmatch("[^\r\n]+") do
                local name = path:match("([^/]+)$") or path
                local alias = M.normalize_alias(name)
                local reasons = skip_reasons(name, path, rules, root)
                local guess = infer_system(name)
                local mapped = assigned_system(assign, alias)
                local candidate = (#reasons > 0 or guess ~= nil)
                -- Avoid a recursive search of every artwork/config directory.
                -- Only folders already identified by their name or skip rule are probed for ROM files.
                local roms = candidate and has_roms(path) or false
                if not seen[path] and candidate then
                    seen[path] = true
                    local status
                    if #reasons > 0 then status = "skip-match"
                    elseif guess and not mapped then status = "unmapped"
                    elseif guess and mapped then status = "mapped"
                    else status = "review" end
                    out[#out + 1] = {
                        path = path, name = name, alias = alias,
                        inferred_system = guess, mapped_system = mapped,
                        has_roms = roms, skip_matches = reasons,
                        status = status, is_scan_root = is_scan_root(path),
                    }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.status ~= b.status then
            local rank = { ["skip-match"] = 1, unmapped = 2, review = 3, mapped = 4 }
            return (rank[a.status] or 9) < (rank[b.status] or 9)
        end
        return a.path:lower() < b.path:lower()
    end)
    return out
end

function M.preview(item, system)
    if type(item) ~= "table" or type(item.path) ~= "string" then return nil, "invalid folder" end
    if system ~= "GC" and system ~= "Wii" then return nil, "choose GameCube or Wii" end
    local name = item.path:match("([^/]+)$") or item.path
    if name:sub(1, 2):lower() == "rt" then
        return nil, "folder already starts with Rt; do not prefix it twice"
    end
    local parent = item.path:match("^(.*)/[^/]+$")
    if not parent then return nil, "folder path must be absolute" end
    local target = parent .. "/Rt" .. name
    local alias = M.normalize_alias("Rt" .. name)
    if alias == "" then return nil, "folder name cannot produce a muOS alias" end
    return { source = item.path, target = target, alias = alias, system = system }
end

function M.rename_register(item, system)
    local preview, err = M.preview(item, system)
    if not preview then return false, err end
    if item.is_scan_root or is_scan_root(preview.source) then
        return false, "this folder is already a configured ROM scan root; changing its path would break the library"
    end
    if item.has_roms ~= true then
        return false, "no supported GameCube/Wii disc image was found in this folder; scan it manually before renaming"
    end
    if not FS.is_dir(preview.source) then return false, "source folder no longer exists" end
    if FS.is_dir(preview.target) or FS.exists(preview.target) then return false, "destination already exists: " .. preview.target end
    local symlink = Shell.first("test -L " .. Shell.shq(preview.source) .. " && echo yes", 3)
    if symlink == "yes" then return false, "symbolic-link folders are not renamed" end

    local moved, move_err = os.rename(preview.source, preview.target)
    if not moved then return false, "rename failed: " .. tostring(move_err or "filesystem error") end

    local tool = os.getenv("RT_MUOS_MANIFEST_TOOL") or Paths.emu("RtSys", "manifest_tool.sh")
    local command = "sh " .. Shell.shq(tool) .. " alias-add " ..
        (system == "GC" and "gc" or "wii") .. " " .. Shell.shq(preview.alias)
    local a, b, code = os.execute(command)
    local ok = (a == true or a == 0 or code == 0)
    if not ok then
        os.rename(preview.target, preview.source)
        return false, "folder renamed back because muOS alias registration failed"
    end

    return true, preview
end

return M
