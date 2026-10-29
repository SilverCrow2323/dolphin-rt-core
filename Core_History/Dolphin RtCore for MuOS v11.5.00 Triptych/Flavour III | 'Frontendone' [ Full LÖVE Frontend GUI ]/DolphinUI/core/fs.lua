local M = {}

function M.exists(p)
  local f = io.open(p, "rb")
  if f then f:close(); return true end
  return false
end

function M.is_dir(p)
  local h = io.popen("[ -d " .. "'" .. tostring(p):gsub("'", "'\\''")
    .. "' ] && echo 1 2>/dev/null")
  if not h then return false end
  local r = h:read("*a"); h:close()
  return r:match("1") ~= nil
end

function M.read(p)
  local f = io.open(p, "r")
  if not f then return nil end
  local c = f:read("*a"); f:close()
  return c
end

function M.mkdir_p(p)
  os.execute("mkdir -p '" .. tostring(p):gsub("'", "'\\''") .. "'")
end

-- Scrittura atomica: tmp + rename (fallback cp per FAT32).
function M.atomic_write(path, content)
  local tmp = path .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return false end
  f:write(content)
  f:close()
  os.remove(path)
  if os.rename(tmp, path) then return true end
  local rc = os.execute("cp -f '" .. tmp:gsub("'", "'\\''")
    .. "' '" .. path:gsub("'", "'\\''") .. "'")
  os.remove(tmp)
  return rc == true or rc == 0
end

return M
