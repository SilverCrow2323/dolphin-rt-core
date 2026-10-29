-- frontend/guide_parser.lua
-- Parses the reference guides in data/guide/config_*.txt into structured
-- data used by the INI editor popup and by the wizard.
--
-- Format expected (per option) in the source .txt:
--
--   # Key : Description.
--   # Key Parameters : v1, v2.
--   # Key Recommend : recommended_value          (optional)
--   # Key Why : short rationale                  (optional)
--   Key = value
--
-- Output shape:
--   {
--     path = "...",
--     sections = {
--       [name] = {
--         desc    = "...",
--         order   = { key1, key2, ... },
--         options = {
--           [key] = {
--             value, desc, params,
--             recommend = "..." or nil,
--             why       = "..." or nil,
--           }
--         }
--       }
--     },
--     section_order = { name1, name2, ... }
--   }
--
-- Path resolution: tries several candidates so the file works whether the
-- CWD is the project root or frontend/. Falls back to love.filesystem.read
-- when io.open can't find the file.

local M = {}

-- ── Path resolution ─────────────────────────────────────────
local CANDIDATE_PREFIXES = {
    "data/guide/",
    "frontend/data/guide/",
    "../data/guide/",
    "../frontend/data/guide/",
}

local function basename(p)
    return (p:gsub("^.*/", ""))
end

-- Try to read a file given a relative path. Returns content, absolute_path
-- or nil, nil.
local function read_any(rel)
    -- 1) direct relative path
    local f = io.open(rel, "r")
    if f then
        local c = f:read("*a"); f:close()
        if c and #c > 0 then return c, rel end
    end
    -- 2) love.filesystem sandbox
    if love and love.filesystem then
        local ok, c = pcall(love.filesystem.read, rel)
        if ok and type(c) == "string" and #c > 0 then
            return c, "love.fs:" .. rel
        end
    end
    return nil, nil
end

-- Resolve a guide file by name, searching all candidate prefixes plus
-- the LÖVE source directory (for absolute fallback).
local function resolve_guide(path)
    if not path or path == "" then return nil, nil end

    -- Absolute path? Try directly first.
    if path:sub(1, 1) == "/" then
        return read_any(path)
    end

    local name = basename(path)

    -- Try exact path first
    local c, p = read_any(path)
    if c then return c, p end

    -- Try each candidate prefix with the basename
    for _, prefix in ipairs(CANDIDATE_PREFIXES) do
        local cand = prefix .. name
        local cc, pp = read_any(cand)
        if cc then return cc, pp end
    end

    -- Try resolving relative to the LÖVE source root (for absolute fallback)
    if love and love.filesystem and love.filesystem.getSource then
        local ok, src = pcall(love.filesystem.getSource)
        if ok and type(src) == "string" and src ~= "" then
            for _, prefix in ipairs({ "data/guide/", "frontend/data/guide/" }) do
                local abs = src .. "/" .. prefix .. name
                local f = io.open(abs, "r")
                if f then
                    local cc = f:read("*a"); f:close()
                    if cc and #cc > 0 then return cc, abs end
                end
            end
        end
    end

    return nil, nil
end

-- ── Parsing helpers ─────────────────────────────────────────
local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function is_comment(line)
    return line:match("^%s*#") ~= nil
end

local function is_blank(line)
    return line:match("^%s*$") ~= nil
end

-- ── Public: parse ───────────────────────────────────────────
function M.parse(path)
    local content, resolved = resolve_guide(path)
    if not content then
        -- Uncomment for debugging:
        -- print("[guide_parser] cannot open " .. tostring(path))
        return nil
    end

    local data = {
        path = resolved or path,
        sections = {},
        section_order = {},
    }

    local current_section = nil
    local pending = nil   -- { key, desc, params, recommend, why, field }

    local function ensure_section(name)
        if not name or name == "" then return end
        if not data.sections[name] then
            data.sections[name] = { desc = "", order = {}, options = {} }
            table.insert(data.section_order, name)
        end
    end

    for line in content:gmatch("[^\r\n]*") do
        if is_blank(line) then
            -- blank line: nothing to do
        else
            local sec = line:match("^%[([^%]]+)%]%s*$")
            if sec and not is_comment(line) then
                current_section = trim(sec)
                ensure_section(current_section)
                pending = nil
            elseif is_comment(line) then
                local body = line:match("^%s*#%s?(.*)$") or ""

                -- Section banner: "# [Section] — Description"
                local bsec, bdesc = body:match("^%[([^%]]+)%]%s*[%-—]%s*(.+)$")
                if bsec and bdesc then
                    ensure_section(trim(bsec))
                    data.sections[trim(bsec)].desc = trim(bdesc)
                elseif not body:match("^=+%s*$") then
                    -- "Key Field : value"
                    local key, field, rest =
                        body:match("^([%w_]+)%s+(Parameters|Recommend|Why)%s*:%s*(.*)$")
                    if key then
                        local fname = field:lower()
                        if pending and pending.key == key then
                            pending.field = fname
                            pending[fname] = (pending[fname] or "") .. trim(rest)
                        else
                            pending = {
                                key = key,
                                desc = "", params = "",
                                recommend = nil, why = nil,
                                field = fname,
                            }
                            pending[fname] = trim(rest)
                        end
                    else
                        -- "Key : Description"
                        local k, d = body:match("^([%w_]+)%s*:%s*(.*)$")
                        if k then
                            if pending and pending.key == k then
                                pending.field = "desc"
                                pending.desc = (pending.desc or "") .. trim(d)
                            else
                                pending = {
                                    key = k,
                                    desc = trim(d),
                                    params = "",
                                    recommend = nil, why = nil,
                                    field = "desc",
                                }
                            end
                        elseif pending then
                            -- Continuation lines (indented under the same option)
                            if line:match("^%s*#%s%s") or line:match("^%s*#\t") then
                                local f = pending.field
                                if f == "desc" then
                                    pending.desc = (pending.desc or "") .. " " .. body
                                elseif f == "params" then
                                    pending.params = (pending.params or "") .. " " .. body
                                elseif f == "recommend" then
                                    pending.recommend = (pending.recommend or "") .. " " .. body
                                elseif f == "why" then
                                    pending.why = (pending.why or "") .. " " .. body
                                end
                            end
                        end
                    end
                end
            else
                -- Option line "Key = value"
                if current_section then
                    local k, v = line:match("^%s*([%w_]+)%s*=%s*(.*)$")
                    if k then
                        local sec_tbl = data.sections[current_section]
                        if not sec_tbl.options[k] then
                            table.insert(sec_tbl.order, k)
                        end
                        if pending and pending.key == k then
                            sec_tbl.options[k] = {
                                value     = v,
                                desc      = trim(pending.desc or ""),
                                params    = trim(pending.params or ""),
                                recommend = pending.recommend and trim(pending.recommend) or nil,
                                why       = pending.why and trim(pending.why) or nil,
                            }
                            pending = nil
                        else
                            sec_tbl.options[k] = { value = v, desc = "", params = "" }
                        end
                    end
                end
            end
        end
    end

    return data
end

-- ── Public: lookup ──────────────────────────────────────────
function M.lookup(guide, section, key)
    if not guide or not guide.sections then return nil end
    local s = guide.sections[section]
    if not s then return nil end
    return s.options[key]
end

-- ── Public: extract_values ──────────────────────────────────
-- Extract candidate values from a "params" string, e.g.:
--   "0 (JIT64), 1 (JITARM64), 2 (Interpreter), 3 (Cached)"
--   -> { {value="0", desc="JIT64"}, ... }
-- Also handles boolean formats:
--   "True, False."  -> { {value="True",  desc="enabled"},
--                        {value="False", desc="disabled"} }
function M.extract_values(params)
    if not params or params == "" then return {} end
    local out = {}

    -- Format: value (description)
    for v, d in params:gmatch("([%w%.%-_]+)%s*%(([^%)]+)%)") do
        table.insert(out, { value = v, desc = d })
    end
    if #out > 0 then return out end

    -- Boolean formats
    local lower = params:lower()
    local has_true  = lower:find("true",  1, true) ~= nil
                     or lower:find("on",   1, true) ~= nil
                     or lower:find("enabled", 1, true) ~= nil
    local has_false = lower:find("false", 1, true) ~= nil
                     or lower:find("off",  1, true) ~= nil
                     or lower:find("disabled", 1, true) ~= nil

    if has_true and has_false then
        return {
            { value = "True",  desc = "enabled"  },
            { value = "False", desc = "disabled" },
        }
    end

    -- Fallback: split on commas, clean up dots
    local count = 0
    for piece in params:gmatch("[^,]+") do
        local v = trim(piece):gsub("%.$", "")
        if v ~= "" then
            table.insert(out, { value = v, desc = "" })
            count = count + 1
            if count >= 8 then break end
        end
    end

    return out
end

return M