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
        gamesettings  = "rtgameset",
    })[kind] or kind

    local chain, seen = {}, {}
    local function add(cur)
        if type(cur) ~= "string" or cur == "" or seen[cur] then return end
        seen[cur] = true
        -- The canonical Default profile is the merge base, not an overlay.
        if kind == "rtcoreprofile" and cur == "Default" then return end

        -- A tier directory inherits its family folder (RtPrime/std inherits
        -- RtPrime) before applying its own patch, matching rt_profile_merge.py.
        if kind == "rtcoreprofile" then
            local parent = cur:match("^(.*)/[^/]+$")
            if parent then add(parent) end
        end

        local meta_path = base_workshop .. "/" .. kind .. "/" .. cur .. "/" .. prefix .. "_data.ini"
        local meta = parse_ini(meta_path)
        local required = meta and meta.data.Runtime and meta.data.Runtime.RequiresBase
        if required and required ~= cur then add(required) end
        table.insert(chain, cur)
    end
    add(name)
    return chain
end

function M.merge_chain(kind, name, target_filename, base_workshop)
    base_workshop = base_workshop or "workshop"
    local base_path
    if kind == "rtcoreprofile" then
        -- Keep the editor/applicator on the same canonical Default as launch.sh.
        base_path = base_workshop .. "/rtcoreprofile/Default/" .. target_filename
    else
        -- Other workshop families (controllers/hotkeys/logging) keep their
        -- shared baseline, then apply the selected named patch.
        base_path = base_workshop .. "/base/" .. target_filename
    end
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
    target_dir = target_dir or (require("core.paths").root_emu .. "/Config")
    files = files or { "Dolphin.ini", "GFX.ini" }
    local all_ok = true
    for _, file in ipairs(files) do
        local merged = M.merge_chain(kind, name, file, base_workshop)
        if merged then
            local out = target_dir .. "/" .. file
            local tmp = out .. ".tmp"
            if write_ini(tmp, merged) then
                local f = io.open(tmp, "rb")
                local sz = 0
                if f then f:seek("end"); sz = f:seek(); f:close() end
                if sz and sz > 0 then
                    if not os.rename(tmp, out) then
                        os.execute("cp " .. "'" .. tmp .. "' '" .. out .. "'")
                        os.remove(tmp)
                    end
                else
                    os.remove(tmp)
                    all_ok = false
                end
            else
                all_ok = false
            end
        else
            all_ok = false
        end
    end
    return all_ok
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