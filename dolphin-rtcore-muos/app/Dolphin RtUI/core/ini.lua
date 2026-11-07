-- Parser + serializer INI con ordine preservato.
local M = {}

function M.parse(text)
  local data, order, section = {}, {}, nil
  local function ensure(s)
    if not data[s] then
      data[s]  = {}
      order[s] = {}
    end
  end
  for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
    local line = raw:gsub("\r$", "")
    local s = line:match("^%s*%[([^%]]+)%]%s*$")
    if s then
      section = s
      ensure(section)
    else
      local k, v = line:match("^%s*([^=;#]+)%s*=%s*(.*)$")
      if k and section then
        k = k:gsub("%s+$", "")
        v = v:gsub("^%s+", "")
        if data[section][k] == nil then
          table.insert(order[section], k)
        end
        data[section][k] = v
      end
    end
  end
  return { data = data, order = order }
end

function M.read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local c = f:read("*a"); f:close()
  return M.parse(c)
end

function M.serialize(parsed)
  local out = {}
  for s, kv in pairs(parsed.data) do
    out[#out+1] = "[" .. s .. "]"
    local written = {}
    for _, k in ipairs(parsed.order[s] or {}) do
      if kv[k] ~= nil then
        out[#out+1] = k .. " = " .. kv[k]
        written[k] = true
      end
    end
    for k, v in pairs(kv) do
      if not written[k] then out[#out+1] = k .. " = " .. v end
    end
    out[#out+1] = ""
  end
  return table.concat(out, "\n")
end

function M.write(path, parsed)
  local tmp = path .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return false end
  f:write(M.serialize(parsed))
  f:close()
  os.remove(path)
  if os.rename(tmp, path) then return true end
  local rc = os.execute("cp -f '" .. tmp:gsub("'", "'\\''")
    .. "' '" .. path:gsub("'", "'\\''") .. "'")
  os.remove(tmp)
  return rc == true or rc == 0
end

return M
