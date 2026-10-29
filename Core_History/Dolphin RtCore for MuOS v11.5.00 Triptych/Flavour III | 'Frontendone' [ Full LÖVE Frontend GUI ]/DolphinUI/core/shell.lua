-- Unico gateway a os.execute / io.popen. Timeout, quoting, logging.
local M = {}

local DEFAULT_TIMEOUT = 3

function M.shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

function M.popen(cmd, timeout)
  local t = timeout or DEFAULT_TIMEOUT
  local full = ("timeout %d %s"):format(t, cmd)
  local h = io.popen(full .. " 2>/dev/null")
  if not h then return nil end
  local out = h:read("*a")
  h:close()
  return out
end

function M.exec(cmd)
  return os.execute(cmd)
end

-- Legge la prima riga non vuota di un comando.
function M.first(cmd, timeout)
  local out = M.popen(cmd, timeout)
  if not out then return nil end
  return out:match("^([^\n]+)")
end


-- == AUTOPATCH v2 ==
-- Primitive richieste da snapshot_manager, profile_manager,
-- key_bindings, profile_validator. Aggiunte automaticamente.

function M.mkdir_p(p)
  if not p or p == "" then return false end
  return os.execute("mkdir -p " .. M.shq(p))
end

function M.is_dir(p)
  if not p or p == "" then return false end
  local h = io.popen("[ -d " .. M.shq(p) .. " ] && echo 1 2>/dev/null")
  if not h then return false end
  local r = h:read("*a"); h:close()
  return r:match("1") ~= nil
end

function M.is_file(p)
  if not p or p == "" then return false end
  local f = io.open(p, "rb")
  if f then f:close(); return true end
  return false
end

function M.atomic_write(path, content)
  if not path then return false end
  local tmp = path .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return false end
  f:write(content or "")
  f:close()

  local vf = io.open(tmp, "rb")
  if not vf then os.remove(tmp); return false end
  vf:seek("end"); local sz = vf:seek(); vf:close()
  if not sz or sz == 0 then os.remove(tmp); return false end

  os.remove(path)
  if os.rename(tmp, path) then return true end
  local rc = os.execute("cp -f " .. M.shq(tmp) .. " " .. M.shq(path))
  os.remove(tmp)
  return rc == true or rc == 0
end

function M.atomic_copy(src, dst)
  if not M.is_file(src) then return false end
  local tmp = dst .. ".tmp"
  os.remove(tmp)
  local rc = os.execute("cp " .. M.shq(src) .. " " .. M.shq(tmp))
  if rc ~= true and rc ~= 0 then os.remove(tmp); return false end

  local vf = io.open(tmp, "rb")
  if not vf then os.remove(tmp); return false end
  vf:seek("end"); local sz = vf:seek(); vf:close()
  if not sz or sz == 0 then os.remove(tmp); return false end

  os.remove(dst)
  if os.rename(tmp, dst) then return true end
  rc = os.execute("cp -f " .. M.shq(tmp) .. " " .. M.shq(dst))
  os.remove(tmp)
  return rc == true or rc == 0
end

function M.workshop(...)
  return table.concat({ "workshop", ... }, "/")
end

function M.data(...)
  return table.concat({ "data", ... }, "/")
end

function M.downloads(...)
  return table.concat({ "data/downloads", ... }, "/")
end

return M
