-- core/tier_compare.lua — LITE / STD / MAX comparison matrix.
-- Legge le varianti dentro <family_dir>/<tier>/ e costruisce una tabella
-- riga-per-chiave con i tre valori affiancati.

local PMerger = (function()
    local ok, m = pcall(require, "core.profile_merger")
    if ok and m and m.parse_ini then return m end
    -- minimal fallback
    return { parse_ini = function(p)
        local f = io.open(p, "r")
        if not f then return nil end
        local data, order, sec = {}, {}, nil
        for line in f:lines() do
            local s = line:match("^%s*%[([^%]]+)%]")
            if s then
                sec = s; data[sec] = data[sec] or {}; order[sec] = order[sec] or {}
            elseif sec then
                local k, v = line:match("^%s*([^=]+)%s*=%s*(.*)$")
                if k then
                    k = k:gsub("%s+$", ""); v = v:gsub("^%s+", "")
                    if not data[sec][k] then table.insert(order[sec], k) end
                    data[sec][k] = v
                end
            end
        end
        f:close()
        return { data = data, order = order }
    end }
end)()

local M = {}

local FILES = { "Dolphin.ini", "GFX.ini" }
local TIERS = { "lite", "std", "max" }

local function read_pair(tier_dir)
    local out = {}
    for _, f in ipairs(FILES) do
        out[f] = PMerger.parse_ini(tier_dir .. "/" .. f)
             or { data = {}, order = {} }
    end
    return out
end

local function tier_present(family_dir, tier)
    for _, f in ipairs(FILES) do
        local fh = io.open(family_dir .. "/" .. tier .. "/" .. f, "r")
        if fh then fh:close(); return true end
    end
    return false
end

function M.tiers_present(family_dir)
    local out = {}
    for _, t in ipairs(TIERS) do
        out[t] = tier_present(family_dir, t)
    end
    for _, f in ipairs(FILES) do
        local fh = io.open(family_dir .. "/" .. f, "r")
        if fh then fh:close(); out.base = true; break end
    end
    return out
end

local function is_num(v)
    return v and tostring(v):match("^%-?%d+%.?%d*$") ~= nil
end

function M.build_matrix(family_dir)
    if not family_dir or family_dir == "" then return nil end
    local present = M.tiers_present(family_dir)

    -- STD fallback: usa base/ se std/ non esiste.
    if not present.std and present.base then present.std = true end

    local pairs_by_tier = {}
    for _, t in ipairs(TIERS) do
        if present[t] then
            pairs_by_tier[t] = read_pair(family_dir .. "/" .. t)
        end
    end
    if not pairs_by_tier.std and present.base then
        pairs_by_tier.std = read_pair(family_dir)
    end

    local rows, seen = {}, {}
    for tier_name, pair in pairs(pairs_by_tier) do
        for _, fname in ipairs(FILES) do
            local parsed = pair[fname]
            for sec, kv in pairs(parsed.data or {}) do
                for k, v in pairs(kv) do
                    local key = fname .. "|" .. sec .. "|" .. k
                    if not seen[key] then
                        seen[key] = {
                            file = fname, section = sec, key = k,
                            lite = nil, std = nil, max = nil,
                        }
                    end
                    seen[key][tier_name] = v
                end
            end
        end
    end

    for _, r in pairs(seen) do
        r.is_numeric = is_num(r.lite) and is_num(r.std) and is_num(r.max)
        if r.is_numeric then
            local li = tonumber(r.lite) or 0
            local si = tonumber(r.std)  or 0
            local mi = tonumber(r.max)  or 0
            r.order_ok = (li <= si and si <= mi)
                      or (li >= si and si >= mi)
        else
            r.order_ok = true
        end
        rows[#rows + 1] = r
    end

    table.sort(rows, function(a, b)
        if a.file ~= b.file then return a.file < b.file end
        if a.section ~= b.section then return a.section < b.section end
        return a.key < b.key
    end)

    return { rows = rows, family_dir = family_dir, present = present }
end

function M.export_text(matrix)
    if not matrix then return "" end
    local lines = { "# Tier compare — " .. (matrix.family_dir or "?") }
    lines[#lines + 1] = string.format(
        "%-42s | %-14s | %-14s | %-14s",
        "KEY", "LITE", "STD", "MAX")
    lines[#lines + 1] = string.rep("-", 92)
    for _, r in ipairs(matrix.rows) do
        local k = r.section .. "." .. r.key
        if #k > 42 then k = k:sub(1, 40) .. ".." end
        lines[#lines + 1] = string.format(
            "%-42s | %-14s | %-14s | %-14s",
            k,
            r.lite and tostring(r.lite):sub(1, 14) or "—",
            r.std  and tostring(r.std ):sub(1, 14) or "—",
            r.max  and tostring(r.max ):sub(1, 14) or "—")
    end
    return table.concat(lines, "\n")
end

-- Detect the tier-family context of a directory.
-- Returns { family_dir, current_tier, presence } or nil.
function M.detect(dir)
    if not dir then return nil end

    -- Is `dir` itself a tier folder?
    local parent, tier = dir:match("^(.+)/([^/]+)$")
    if tier and (tier == "lite" or tier == "std" or tier == "max") then
        local presence = M.tiers_present(parent)
        if presence.lite or presence.std or presence.max then
            return { family_dir = parent, current_tier = tier, presence = presence }
        end
    end

    -- Is `dir` a family root?
    local presence = M.tiers_present(dir)
    if presence.lite or presence.std or presence.max then
        return { family_dir = dir, current_tier = "std", presence = presence }
    end

    return nil
end

return M
