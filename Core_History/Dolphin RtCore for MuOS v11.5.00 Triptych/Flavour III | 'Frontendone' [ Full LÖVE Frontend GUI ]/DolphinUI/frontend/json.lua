-- frontend/json.lua — minimal, correct JSON encoder/decoder.
-- Standard-compliant. Handles \", \\, \/, \b, \f, \n, \r, \t, \uXXXX
-- (including UTF-16 surrogate pairs). No LPeg, no external deps.
local json = {}

-- ============================================================
--  DECODE
-- ============================================================
local decode_value

local function skip_ws(s, i)
  while i <= #s do
    local c = s:sub(i, i)
    if c == " " or c == "\t" or c == "\n" or c == "\r" then
      i = i + 1
    else
      return i
    end
  end
  return i
end

local function fail(i, msg)
  -- Use a table to carry the position with the message
  error({ pos = i, msg = msg }, 0)
end

local ESC_MAP = {
  ['"']  = '"',
  ['\\'] = '\\',
  ['/']  = '/',
  ['b']  = '\b',
  ['f']  = '\f',
  ['n']  = '\n',
  ['r']  = '\r',
  ['t']  = '\t',
}

local function parse_hex4(s, i)
  local hex = s:sub(i, i + 3)
  if not hex:match("^%x%x%x%x$") then
    fail(i, "invalid \\u escape")
  end
  return tonumber(hex, 16), i + 4
end

local function utf8_char(cp)
  if cp < 0x80 then
    return string.char(cp)
  elseif cp < 0x800 then
    return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + (cp % 0x40))
  elseif cp < 0x10000 then
    return string.char(
      0xE0 + math.floor(cp / 0x1000),
      0x80 + (math.floor(cp / 0x40) % 0x40),
      0x80 + (cp % 0x40))
  else
    return string.char(
      0xF0 + math.floor(cp / 0x40000),
      0x80 + (math.floor(cp / 0x1000) % 0x40),
      0x80 + (math.floor(cp / 0x40) % 0x40),
      0x80 + (cp % 0x40))
  end
end

local function parse_string(s, i)
  -- Precondition: s:sub(i,i) == '"'
  i = i + 1
  local buf = {}
  local start = i
  while i <= #s do
    local c = s:sub(i, i)
    if c == '"' then
      buf[#buf+1] = s:sub(start, i - 1)
      return table.concat(buf), i + 1
    elseif c == '\\' then
      buf[#buf+1] = s:sub(start, i - 1)
      local esc = s:sub(i + 1, i + 1)
      if esc == 'u' then
        local cp, ni = parse_hex4(s, i + 2)
        i = ni
        -- UTF-16 surrogate pair
        if cp >= 0xD800 and cp <= 0xDBFF then
          if s:sub(i, i) == '\\' and s:sub(i + 1, i + 1) == 'u' then
            local lo, ni2 = parse_hex4(s, i + 2)
            if lo >= 0xDC00 and lo <= 0xDFFF then
              cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
              i = ni2
            end
          end
        end
        buf[#buf+1] = utf8_char(cp)
      else
        local mapped = ESC_MAP[esc]
        if not mapped then
          fail(i, "invalid escape \\" .. esc)
        end
        buf[#buf+1] = mapped
        i = i + 2
      end
      start = i
    else
      i = i + 1
    end
  end
  fail(i, "unterminated string")
end

local function parse_number(s, i)
  local j = i
  while j <= #s do
    local c = s:sub(j, j)
    if c:match("[%d%.eE%+%-]") then
      j = j + 1
    else
      break
    end
  end
  local n = tonumber(s:sub(i, j - 1))
  if not n then fail(i, "invalid number") end
  return n, j
end

local function parse_array(s, i)
  i = i + 1
  local arr = {}
  i = skip_ws(s, i)
  if s:sub(i, i) == "]" then return arr, i + 1 end
  while true do
    local v
    v, i = decode_value(s, i)
    table.insert(arr, v)
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "," then
      i = i + 1
    elseif c == "]" then
      return arr, i + 1
    else
      fail(i, "expected , or ]")
    end
  end
end

local function parse_object(s, i)
  i = i + 1
  local obj = {}
  i = skip_ws(s, i)
  if s:sub(i, i) == "}" then return obj, i + 1 end
  while true do
    i = skip_ws(s, i)
    if s:sub(i, i) ~= '"' then
      fail(i, "expected string key")
    end
    local key
    key, i = parse_string(s, i)
    i = skip_ws(s, i)
    if s:sub(i, i) ~= ":" then
      fail(i, "expected :")
    end
    i = i + 1
    local v
    v, i = decode_value(s, i)
    obj[key] = v
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "," then
      i = i + 1
    elseif c == "}" then
      return obj, i + 1
    else
      fail(i, "expected , or }")
    end
  end
end

decode_value = function(s, i)
  i = skip_ws(s, i)
  if i > #s then fail(i, "unexpected end") end
  local c = s:sub(i, i)
  if c == "{" then return parse_object(s, i) end
  if c == "[" then return parse_array(s, i) end
  if c == '"' then return parse_string(s, i) end
  if c == "t" then
    if s:sub(i, i + 3) == "true" then return true, i + 4 end
    fail(i, "invalid literal")
  end
  if c == "f" then
    if s:sub(i, i + 4) == "false" then return false, i + 5 end
    fail(i, "invalid literal")
  end
  if c == "n" then
    if s:sub(i, i + 3) == "null" then return json.null, i + 4 end
    fail(i, "invalid literal")
  end
  if c == "-" or c:match("%d") then
    return parse_number(s, i)
  end
  fail(i, "no valid JSON value")
end

json.null = setmetatable({}, { __tostring = function() return "null" end })

function json.decode(s)
  if type(s) ~= "string" then
    return nil, 0, "input is not a string"
  end
  local ok, v, i = pcall(decode_value, s, 1)
  if not ok then
    -- v is either a table {pos, msg} from fail() or a plain error
    if type(v) == "table" and v.pos then
      return nil, v.pos, v.msg
    end
    return nil, 0, tostring(v)
  end
  -- Reject trailing garbage
  local t = skip_ws(s, i)
  if t <= #s then
    return nil, t, "trailing garbage"
  end
  return v
end

-- ============================================================
--  ENCODE
-- ============================================================
local encode_value

local function escape_string(s)
  return (s:gsub('[%z\1-\31\\"]', function(c)
    if c == '"' then return '\\"' end
    if c == '\\' then return '\\\\' end
    if c == '\b' then return '\\b' end
    if c == '\f' then return '\\f' end
    if c == '\n' then return '\\n' end
    if c == '\r' then return '\\r' end
    if c == '\t' then return '\\t' end
    return string.format("\\u%04x", c:byte())
  end))
end

local function is_array(t)
  local n, max = 0, 0
  for k in pairs(t) do
    if type(k) ~= "number" then return false end
    n = n + 1
    if k > max then max = k end
  end
  return max == n
end

encode_value = function(v)
  local tv = type(v)
  if v == json.null or tv == "nil" then return "null" end
  if tv == "boolean" then return tostring(v) end
  if tv == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    if math.floor(v) == v then return string.format("%d", v) end
    return string.format("%.14g", v)
  end
  if tv == "string" then
    return '"' .. escape_string(v) .. '"'
  end
  if tv == "table" then
    local parts = {}
    if is_array(v) then
      for i, item in ipairs(v) do
        parts[i] = encode_value(item)
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      for k, val in pairs(v) do
        if type(k) == "string" or type(k) == "number" then
          parts[#parts+1] = '"' .. escape_string(tostring(k)) .. '":'
                         .. encode_value(val)
        end
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return "null"
end

function json.encode(v)
  local ok, result = pcall(encode_value, v)
  if not ok then
    error("encode failed: " .. tostring(result), 2)
  end
  return result
end

return json