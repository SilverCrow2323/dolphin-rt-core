local M = {}

local function parse_ini(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data, order, section = {}, {}, nil
    for line in f:lines() do
        local stripped = line:match("^%s*(.-)%s*$")
        if stripped ~= "" and not stripped:match("^[;#]") then
            local s = stripped:match("^%[(.+)%]$")
            if s then
                section = s
                data[section] = data[section] or {}
                if not order[section] then order[section] = {} end
            elseif section then
                local k, v = stripped:match("^([^=]+)%s*=%s*(.*)$")
                if k then
                    k = k:match("^%s*(.-)%s*$")
                    v = v:match("^%s*(.-)%s*$")
                    if not data[section][k] then
                        table.insert(order[section], k)
                    end
                    data[section][k] = v
                end
            end
        end
    end
    f:close()
    return { data = data, order = order }
end

M.parse_ini = parse_ini

local function write_ini(path, parsed)
    local f = io.open(path, "w")
    if not f then return false end
    for section, kv in pairs(parsed.data) do
        f:write("[" .. section .. "]\n")
        local keys = parsed.order[section] or {}
        for _, k in ipairs(keys) do
            if kv[k] ~= nil then
                f:write(k .. " = " .. kv[k] .. "\n")
            end
        end
        for k, v in pairs(kv) do
            local found = false
            for _, ok in ipairs(keys) do
                if ok == k then found = true break end
            end
            if not found then
                f:write(k .. " = " .. v .. "\n")
            end
        end
        f:write("\n")
    end
    f:close()
    return true
end

local function merge_into(target, patch)
    for section, kv in pairs(patch.data) do
        target.data[section] = target.data[section] or {}
        target.order[section] = target.order[section] or {}
        for k, v in pairs(kv) do
            if target.data[section][k] == nil then
                table.insert(target.order[section], k)
            end
            target.data[section][k] = v
        end
    end
    return target
end

function M.resolve_chain(kind, name, base_workshop)
    base_workshop = base_workshop or "workshop"
    local prefix = ({
        rtcoreprofile = "rtprofile",
        controller    = "rtcontroller",
        hotkeys       = "rthotkey",
        logging       = "rtlog",
        debug         = "rtdebug",
        gamesettings  = "rtgameset",
    })[kind] or kind

    local chain = {}
    local cur = name
    local seen = {}
    while cur and not seen[cur] do
        seen[cur] = true
        table.insert(chain, 1, cur)
        local meta_path = base_workshop .. "/" .. kind .. "/" .. cur .. "/" .. prefix .. "_data.ini"
        local meta = parse_ini(meta_path)
        if meta and meta.data.Runtime and meta.data.Runtime.RequiresBase then
            cur = meta.data.Runtime.RequiresBase
        else
            cur = nil
        end
    end
    return chain
end

function M.merge_chain(kind, name, target_filename, base_workshop)
    base_workshop = base_workshop or "workshop"
    local base_path = base_workshop .. "/base/" .. target_filename
    local base = parse_ini(base_path)
    if not base then return nil end

    local chain = M.resolve_chain(kind, name, base_workshop)
    for _, step in ipairs(chain) do
        local patch_path = base_workshop .. "/" .. kind .. "/" .. step .. "/" .. target_filename
        local patch = parse_ini(patch_path)
        if patch then
            merge_into(base, patch)
        end
    end
    return base
end

function M.apply_profile(kind, name, target_dir, files, base_workshop)
    target_dir = target_dir or "dolphin-emu/Config"
    files = files or { "Dolphin.ini", "GFX.ini" }
    for _, file in ipairs(files) do
        local merged = M.merge_chain(kind, name, file, base_workshop)
        if merged then
            local out = target_dir .. "/" .. file
            local tmp = out .. ".tmp"
            if write_ini(tmp, merged) then
                os.remove(out)
                os.rename(tmp, out)
            end
        end
    end
end

function M.deep_equal(a, b)
    if not a or not b then return false end
    for section, kv in pairs(a.data) do
        if not b.data[section] then return false end
        for k, v in pairs(kv) do
            if b.data[section][k] ~= v then return false end
        end
    end
    for section, kv in pairs(b.data) do
        if not a.data[section] then return false end
        for k, v in pairs(kv) do
            if a.data[section][k] ~= v then return false end
        end
    end
    return true
end

return M