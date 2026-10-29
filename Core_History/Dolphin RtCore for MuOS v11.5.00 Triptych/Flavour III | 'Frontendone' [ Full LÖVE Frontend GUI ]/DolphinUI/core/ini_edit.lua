-- core/ini_edit.lua — line-based INI editor.
-- Used by workshop_rtprofiles_editor for cheap get/set without parsing.

local M = {}

function M.read_lines(path)
    local f = io.open(path, "rb")
    if not f then return {} end
    local lines = {}
    for line in f:lines() do lines[#lines+1] = (line:gsub("\r$", "")) end
    f:close()
    return lines
end

function M.write_lines(path, lines)
    local f = io.open(path, "wb")
    if not f then return false end
    for _, l in ipairs(lines or {}) do f:write(l .. "\n") end
    f:close()
    return true
end

local function trim(s) return (s or ""):match("^%s*(.-)%s*$") end

function M.get(lines, section, key)
    local cur = nil
    for _, line in ipairs(lines or {}) do
        local s = line:match("^%s*%[([^%]]+)%]")
        if s then cur = s
        elseif cur == section then
            local k, v = line:match("^%s*([^=;#][^=]*)%s*=%s*(.*)$")
            if k then
                k = trim(k); v = trim(v)
                if k == key then return v end
            end
        end
    end
    return nil
end

function M.set(lines, section, key, value)
    local cur, sec_idx, key_idx = nil, nil, nil
    for i, line in ipairs(lines) do
        local s = line:match("^%s*%[([^%]]+)%]")
        if s then
            cur = s
            if s == section then sec_idx = i end
        elseif cur == section then
            local k = line:match("^%s*([^=;#][^=]*)%s*=")
            if k and trim(k) == key then key_idx = i; break end
        end
    end
    if key_idx then
        lines[key_idx] = key .. " = " .. tostring(value or "")
    elseif sec_idx then
        table.insert(lines, sec_idx + 1, key .. " = " .. tostring(value or ""))
    else
        lines[#lines+1] = "[" .. section .. "]"
        lines[#lines+1] = key .. " = " .. tostring(value or "")
    end
end

return M
