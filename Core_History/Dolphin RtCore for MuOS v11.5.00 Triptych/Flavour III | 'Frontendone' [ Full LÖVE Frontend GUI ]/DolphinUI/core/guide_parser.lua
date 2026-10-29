-- core/guide_parser.lua — v3.0 "Definitive"
--
-- Single-format parser for the annotated guide files.
--
--   # KEY - Default: V | Type: T | muOS: FLAG | Recommended: R
--   # Description: text
--   # Effects: text
--   # Hints: text (may continue on indented comment lines)
--   KEY = V
--
-- Dash variants (em/en dash, arrows) are normalized to ASCII before
-- matching, so Lua's byte-based pattern matcher never trips over
-- multi-byte UTF-8. Unknown label prefixes and unannotated options
-- are recorded in `warnings` rather than silently dropped.

local M = {}

-- ── Path resolution ─────────────────────────────────────────
local CANDIDATE_PREFIXES = {
    "data/guide/",
    "frontend/data/guide/",
    "../data/guide/",
    "../frontend/data/guide/",
}

local function basename(p) return (p:gsub("^.*/", "")) end

local function read_any(rel)
    local f = io.open(rel, "r")
    if f then
        local c = f:read("*a"); f:close()
        if c and #c > 0 then return c, rel end
    end
    if love and love.filesystem then
        local ok, c = pcall(love.filesystem.read, rel)
        if ok and type(c) == "string" and #c > 0 then
            return c, "love.fs:" .. rel
        end
    end
    return nil, nil
end

local function resolve_guide(path)
    if not path or path == "" then return nil, nil end
    if path:sub(1, 1) == "/" then return read_any(path) end
    local name = basename(path)
    local c, p = read_any(path)
    if c then return c, p end
    for _, prefix in ipairs(CANDIDATE_PREFIXES) do
        local cc, pp = read_any(prefix .. name)
        if cc then return cc, pp end
    end
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

-- ── String helpers ──────────────────────────────────────────
local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Normalize dashes / arrows to ASCII. Lua's pattern matcher is byte
-- based; normalizing once up front is much safer than trying to put
-- multi-byte characters inside a Lua character class.
local function normalize(s)
    return (s
        :gsub("\226\128\148", "-")   -- em dash
        :gsub("\226\128\147", "-")   -- en dash
        :gsub("\226\128\146", "-")   -- figure dash
        :gsub("\226\134\146", "->")  -- rightwards arrow
        :gsub("\239\188\154", ":")   -- fullwidth colon
        :gsub("\227\128\128", " "))  -- ideographic space
end

-- ── Header pipe labels ─────────────────────────────────────
local KNOWN_LABELS = {
    ["Default"]     = "_default",
    ["Type"]        = "declared_type",
    ["muOS"]        = "muos",
    ["Recommended"] = "recommend",
}

local KNOWN_FIELDS = {
    ["Description"] = "desc",
    ["Effects"]     = "effects",
    ["Hints"]       = "hints",
}

local function parse_pipe_labels(rest)
    local out = {}
    for part in rest:gmatch("[^|]+") do
        local label, val = part:match("^%s*([^:]+)%s*:%s*(.*)$")
        if label then
            label = trim(label); val = trim(val)
            local key = KNOWN_LABELS[label]
            if key then
                if key == "muos" then
                    -- "RECOMMENDED: True"  OR  "IGNORE" / "REQUIRED" / etc.
                    local sub, subval = val:match("^([^:]+)%s*:%s*(.*)$")
                    if sub and subval then
                        out.muos      = trim(sub):lower()
                        out.recommend = trim(subval):gsub("%s*%b()%s*$", "")
                    else
                        out.muos = val:lower()
                    end
                else
                    out[key] = val:gsub("%s*%b()%s*$", "")
                end
            end
        end
    end
    return out
end

local function is_field_continuation(line)
    return line:match("^#%s%s") ~= nil or line:match("^#\t") ~= nil
end

-- ── Public: parse ───────────────────────────────────────────
function M.parse(path)
    local content, resolved = resolve_guide(path)
    if not content then return nil end

    local data = {
        path = resolved or path,
        sections = {},
        section_order = {},
        warnings = {},
    }
    local cur_section = nil
    local pending     = nil
    local last_field  = nil

    local function ensure_section(name)
        if not name or name == "" then return end
        if not data.sections[name] then
            data.sections[name] = { desc = "", order = {}, options = {} }
            table.insert(data.section_order, name)
        end
    end

    local function warn(msg)
        data.warnings[#data.warnings + 1] = msg
    end

    for raw_line in content:gmatch("([^\n]*)\n?") do
        local line    = normalize((raw_line:gsub("\r$", "")))
        local trimmed = trim(line)

        if trimmed == "" then
            -- blank

        elseif trimmed:match("^%[") and trimmed:match("%]%s*$")
               and not trimmed:match("^#") then
            local sec = trimmed:match("^%[([^%]]+)%]%s*$")
            if sec then
                cur_section = trim(sec)
                ensure_section(cur_section)
                pending, last_field = nil, nil
            end

        elseif trimmed:match("^#") then
            local body = trimmed:match("^#%s?(.*)$") or ""

            if body:match("^[%s%-=]*$") then
                last_field = nil
            else
                local bsec, bdesc = body:match("^%[([^%]]+)%]%s*[%-:]%s*(.+)$")
                if bsec then
                    local sn = trim(bsec)
                    ensure_section(sn)
                    data.sections[sn].desc = trim(bdesc)
                    cur_section = sn
                    pending, last_field = nil, nil
                else
                    local name, rest = body:match("^([A-Za-z_][%w_]*)%s*%-%s*(.+)$")
                    local is_header = false
                    if name and rest then
                        is_header = rest:find("Default%s*:") ~= nil
                                 or rest:find("Type%s*:")    ~= nil
                                 or rest:find("muOS%s*:")    ~= nil
                    end

                    if is_header then
                        pending = { key = name, desc = "", effects = "", hints = "" }
                        local labelled = parse_pipe_labels(rest)
                        for k, v in pairs(labelled) do pending[k] = v end
                        if not pending.recommend and pending._default then
                            pending.recommend = pending._default
                        end
                        if not pending.muos then pending.muos = "other" end
                        last_field = nil
                    else
                        local field, rest2 = body:match("^(%u[%w_]*)%s*:%s*(.*)$")
                        if field and pending and KNOWN_FIELDS[field] then
                            local key = KNOWN_FIELDS[field]
                            pending[key] = trim(rest2)
                            last_field   = key
                        elseif last_field and pending and is_field_continuation(line) then
                            pending[last_field] = (pending[last_field] or "")
                                .. " " .. trim(body)
                        end
                    end
                end
            end

        else
            if cur_section then
                local k, v = trimmed:match("^([A-Za-z_][%w_]*)%s*=%s*(.*)$")
                if k then
                    local sec_tbl = data.sections[cur_section]
                    if not sec_tbl.options[k] then
                        table.insert(sec_tbl.order, k)
                    end
                    if pending and pending.key == k then
                        sec_tbl.options[k] = {
                            value         = v,
                            default       = pending._default,
                            declared_type = pending.declared_type,
                            desc          = trim(pending.desc or ""),
                            effects       = trim(pending.effects or ""),
                            hints         = trim(pending.hints or ""),
                            muos          = pending.muos,
                            recommend     = pending.recommend,
                        }
                    else
                        warn(string.format(
                            "unannotated option %s.%s", cur_section, k))
                        sec_tbl.options[k] = {
                            value = v, default = v,
                            desc = "", effects = "", hints = "",
                            muos = "other", recommend = nil,
                        }
                    end
                    pending, last_field = nil, nil
                end
            end
        end
    end

    return data
end

-- ── Lookup ──────────────────────────────────────────────────
function M.lookup(guide, section, key)
    if not guide or not guide.sections then return nil end
    local s = guide.sections[section]
    if not s then return nil end
    return s.options[key]
end

-- ── Extract enum values from a "Type: 0 (JIT) / 1 (Cached)" string ─
function M.extract_values(params)
    if not params or params == "" then return {} end
    local out = {}
    for v, d in params:gmatch("([%w%.%-_]+)%s*%(([^%)]+)%)") do
        table.insert(out, { value = v, desc = d })
    end
    if #out > 0 then return out end

    local lower = params:lower()
    local has_true  = lower:find("true",     1, true) ~= nil
                   or lower:find("enabled",  1, true) ~= nil
    local has_false = lower:find("false",    1, true) ~= nil
                   or lower:find("disabled", 1, true) ~= nil
    if has_true and has_false then
        return {
            { value = "True",  desc = "enabled"  },
            { value = "False", desc = "disabled" },
        }
    end

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
