local M = {}

function M.parse(path)
  local data, section = {}, nil
  local f = io.open(path, "r")
  if not f then return data end
  for line in f:lines() do
    local t = line:match("^%s*(.-)%s*$")
    if t ~= "" and not t:match("^[;#]") then
      local s = t:match("^%[(.+)%]$")
      if s then
        section = s; data[section] = data[section] or {}
      elseif section then
        local k, v = t:match("^([^=]+)%s*=%s*(.*)$")
        if k then data[section][k:match("^%s*(.-)%s*$")] = v end
      end
    end
  end
  f:close(); return data
end

function M.get(data, section, key, default)
  if data[section] and data[section][key] ~= nil then return data[section][key] end
  return default
end

function M.save(data, path)
  local f = io.open(path, "w"); if not f then return false end
  for section, kv in pairs(data) do
    f:write("[" .. section .. "]\n")
    for k, v in pairs(kv) do f:write(k .. " = " .. tostring(v) .. "\n") end
    f:write("\n")
  end
  f:close(); return true
end

return M
