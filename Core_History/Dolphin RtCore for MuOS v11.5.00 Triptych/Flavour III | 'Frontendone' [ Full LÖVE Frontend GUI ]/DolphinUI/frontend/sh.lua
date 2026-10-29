-- frontend/sh.lua
-- Central shell helper. POSIX single-quote escaping, exit-code
-- normalization, output read, TTL cache.

local M = {}

function M.shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function normalize_exit(a, b, c)
  if type(a) == "number" then return a end
  if a == true  then return tonumber(c) or 0 end
  if a == false then return tonumber(c) or 1 end
  return 0
end

function M.exec(cmd)
  return normalize_exit(os.execute(cmd))
end

function M.run_async(cmd)
  return M.exec("setsid sh -c " .. M.shq(cmd) ..
                " </dev/null >/dev/null 2>&1 &") == 0
end

local _cache = {}

local function now()
  if love and love.timer then return love.timer.getTime() end
  return os.time()
end

local function cache_get(key)
  local entry = _cache[key]
  if not entry then return nil end
  if entry.expires and now() > entry.expires then
    _cache[key] = nil
    return nil
  end
  return entry.value
end

local function cache_set(key, value, ttl)
  if not ttl or ttl <= 0 then
    _cache[key] = { value = value, expires = nil }
  else
    _cache[key] = { value = value, expires = now() + ttl }
  end
end

function M.invalidate(key_or_prefix)
  if not key_or_prefix or key_or_prefix == "" then return end
  _cache[key_or_prefix] = nil
  local prefix = key_or_prefix .. ":"
  local n = #prefix
  for k in pairs(_cache) do
    if k:sub(1, n) == prefix then _cache[k] = nil end
  end
end

function M.clear_cache()
  _cache = {}
end

function M.read(cmd, ttl, cache_key)
  local key = cache_key or ("cmd:" .. cmd)
  if ttl and ttl > 0 then
    local hit = cache_get(key)
    if hit ~= nil then return hit end
  end

  local h = io.popen(cmd .. " 2>/dev/null")
  if not h then return nil end
  local out = h:read("*a") or ""
  h:close()

  if ttl and ttl > 0 then cache_set(key, out, ttl) end
  return out
end

function M.lines(cmd, ttl, cache_key)
  local out = M.read(cmd, ttl, cache_key)
  if not out then return nil end
  local t = {}
  for line in out:gmatch("[^\r\n]+") do
    if line ~= "" then t[#t + 1] = line end
  end
  return t
end

function M.exists(path)
  if not path or path == "" then return false end
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return M.exec("[ -e " .. M.shq(path) .. " ]") == 0
end

function M.is_dir(path)
  if not path or path == "" then return false end
  return M.exec("[ -d " .. M.shq(path) .. " ]") == 0
end

function M.is_file(path)
  if not path or path == "" then return false end
  return M.exec("[ -f " .. M.shq(path) .. " ]") == 0
end

function M.mkdir_p(path)
  if not path or path == "" then return false end
  return M.exec("mkdir -p " .. M.shq(path)) == 0
end

function M.atomic_copy(src, dst)
  local tmp = dst .. ".tmp"
  os.remove(tmp)
  if M.exec("cp " .. M.shq(src) .. " " .. M.shq(tmp)) ~= 0 then
    os.remove(tmp)
    return false
  end
  local f = io.open(tmp, "rb")
  if not f then
    os.remove(tmp); return false
  end
  f:seek("end")
  local sz = f:seek()
  f:close()
  if not sz or sz == 0 then
    os.remove(tmp); return false
  end
  if os.rename(tmp, dst) then return true end
  if M.exec("cp " .. M.shq(tmp) .. " " .. M.shq(dst)) == 0 then
    os.remove(tmp)
    return true
  end
  os.remove(tmp)
  return false
end

function M.atomic_write(path, content)
  local tmp = path .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return false end
  f:write(content)
  f:close()
  if os.rename(tmp, path) then return true end
  if M.exec("cp " .. M.shq(tmp) .. " " .. M.shq(path)) == 0 then
    os.remove(tmp)
    return true
  end
  os.remove(tmp)
  return false
end

return M