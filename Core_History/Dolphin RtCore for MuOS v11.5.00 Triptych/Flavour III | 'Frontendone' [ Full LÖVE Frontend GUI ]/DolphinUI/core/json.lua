-- JSON minimale, corretto, senza dipendenze.
local json = {}
json.null = setmetatable({}, { __tostring = function() return "null" end })

local decode_value

local function skip_ws(s, i)
  while i <= #s do
    local c = s:sub(i, i)
    if c == " " or c == "\t" or c == "\n" or c == "\r" then i = i + 1
    else return i end
  end
  return i
end

local ESC = { ['"']='"', ['\\']='\\', ['/']='/',
              b='\b', f='\f', n='\n', r='\r', t='\t' }

local function utf8_char(cp)
  if cp < 0x80 then return string.char(cp) end
  if cp < 0x800 then
    return string.char(0xC0 + math.floor(cp/0x40), 0x80 + (cp % 0x40))
  end
  if cp < 0x10000 then
    return string.char(0xE0 + math.floor(cp/0x1000),
      0x80 + (math.floor(cp/0x40) % 0x40), 0x80 + (cp % 0x40))
  end
  return string.char(0xF0 + math.floor(cp/0x40000),
    0x80 + (math.floor(cp/0x1000) % 0x40),
    0x80 + (math.floor(cp/0x40) % 0x40), 0x80 + (cp % 0x40))
end

local function parse_string(s, i)
  i = i + 1
  local buf, start = {}, i
  while i <= #s do
    local c = s:sub(i, i)
    if c == '"' then
      buf[#buf+1] = s:sub(start, i - 1)
      return table.concat(buf), i + 1
    elseif c == '\\' then
      buf[#buf+1] = s:sub(start, i - 1)
      local esc = s:sub(i + 1, i + 1)
      if esc == 'u' then
        local hex = s:sub(i + 2, i + 5)
        if not hex:match("^%x%x%x%x$") then error("bad \\u") end
        local cp = tonumber(hex, 16)
        i = i + 6
        if cp >= 0xD800 and cp <= 0xDBFF then
          if s:sub(i, i) == '\\' and s:sub(i + 1, i + 1) == 'u' then
            local lo = tonumber(s:sub(i + 2, i + 5), 16)
            if lo and lo >= 0xDC00 and lo <= 0xDFFF then
              cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
              i = i + 6
            end
          end
        end
        buf[#buf+1] = utf8_char(cp)
      else
        local m = ESC[esc]
        if not m then error("bad escape") end
        buf[#buf+1] = m
        i = i + 2
      end
      start = i
    else
      i = i + 1
    end
  end
  error("unterminated string")
end

local function parse_number(s, i)
  local j = i
  while j <= #s and s:sub(j, j):match("[%d%.eE%+%-]") do j = j + 1 end
  local n = tonumber(s:sub(i, j - 1))
  if not n then error("bad number") end
  return n, j
end

local function parse_array(s, i)
  i = i + 1
  local arr = {}
  i = skip_ws(s, i)
  if s:sub(i, i) == "]" then return arr, i + 1 end
  while true do
    local v; v, i = decode_value(s, i)
    table.insert(arr, v)
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "," then i = i + 1
    elseif c == "]" then return arr, i + 1
    else error("expected , or ]") end
  end
end

local function parse_object(s, i)
  i = i + 1
  local obj = {}
  i = skip_ws(s, i)
  if s:sub(i, i) == "}" then return obj, i + 1 end
  while true do
    i = skip_ws(s, i)
    if s:sub(i, i) ~= '"' then error("expected key") end
    local k; k, i = parse_string(s, i)
    i = skip_ws(s, i)
    if s:sub(i, i) ~= ":" then error("expected :") end
    i = i + 1
    local v; v, i = decode_value(s, i)
    obj[k] = v
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "," then i = i + 1
    elseif c == "}" then return obj, i + 1
    else error("expected , or }") end
  end
end

decode_value = function(s, i)
  i = skip_ws(s, i)
  local c = s:sub(i, i)
  if c == "{" then return parse_object(s, i) end
  if c == "[" then return parse_array(s, i) end
  if c == '"' then return parse_string(s, i) end
  if c == "t" then return true,  i + 4 end
  if c == "f" then return false, i + 5 end
  if c == "n" then return json.null, i + 4 end
  if c == "-" or c:match("%d") then return parse_number(s, i) end
  error("no value")
end

-- Tollerante: toglie il BOM UTF-8 (file salvati da Windows/editor) e accetta
-- spazi/CRLF iniziali. Ritorna nil (mai un errore) se il JSON e' rotto.
function json.decode(s)
  if type(s) ~= "string" then return nil end
  if s:sub(1, 3) == "\239\187\191" then s = s:sub(4) end
  local ok, v = pcall(decode_value, s, 1)
  if not ok then return nil end
  return v
end

-- Come decode, ma restituisce anche il motivo dell'errore (per i log).
function json.decode_err(s)
  if type(s) ~= "string" then return nil, "not a string" end
  if s:sub(1, 3) == "\239\187\191" then s = s:sub(4) end
  local ok, v = pcall(decode_value, s, 1)
  if not ok then return nil, tostring(v) end
  return v
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

local function esc(s)
  return (s:gsub('[%z\1-\31\\"]', function(c)
    local m = { ['"']='\\"', ['\\']='\\\\', ['\b']='\\b',
                ['\f']='\\f', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t' }
    return m[c] or string.format("\\u%04x", c:byte())
  end))
end

local function enc(v)
  local tv = type(v)
  if v == json.null or tv == "nil" then return "null" end
  if tv == "boolean" then return tostring(v) end
  if tv == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    if math.floor(v) == v then return string.format("%d", v) end
    return string.format("%.14g", v)
  end
  if tv == "string" then return '"' .. esc(v) .. '"' end
  if tv == "table" then
    if is_array(v) then
      local parts = {}
      for i, x in ipairs(v) do parts[i] = enc(x) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local parts = {}
    for k, x in pairs(v) do
      if type(k) == "string" or type(k) == "number" then
        parts[#parts+1] = '"' .. esc(tostring(k)) .. '":' .. enc(x)
      end
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

function json.encode(v) return enc(v) end

return json
