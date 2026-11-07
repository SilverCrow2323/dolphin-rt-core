-- frontend/sh.lua
-- Central shell helper. POSIX single-quote escaping, exit-code
-- normalization, output read, TTL cache.

local M = {}

function M.shq(s)
  if s == nil then return "''" end
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- ── Absolute path helpers ──────────────────────────────────
-- LÖVE non cambia la CWD quando si invoca `love frontend/`.
-- Rileva il source dir una volta sola e prepend ai path relativi.
local _SRC = nil
local function _detect_src()
  if _SRC ~= nil then return _SRC end
  if love and love.filesystem and love.filesystem.getSource then
    local ok, s = pcall(love.filesystem.getSource)
    if ok and type(s) == "string" and s ~= "" and s:sub(1, 1) == "/" then
      _SRC = s
      return _SRC
    end
  end
  _SRC = ""
  return _SRC
end

function M.abs(p)
  if type(p) ~= "string" or p == "" then return p end
  if p:sub(1, 1) == "/" then return p end
  local s = _detect_src()
  if s == "" then return p end
  return s .. "/" .. p
end

function M.workshop(sub)
  if sub and sub ~= "" then return M.abs("workshop/" .. sub) end
  return M.abs("workshop")
end

function M.data(sub)
  if sub and sub ~= "" then return M.abs("data/" .. sub) end
  return M.abs("data")
end

-- ── Filesystem counters ────────────────────────────────
-- Conta le directory dentro `path`, con profondita' fissa.
function M.count_dirs(path, min_depth, max_depth)
  min_depth = min_depth or 1
  max_depth = max_depth or min_depth
  if not path or path == "" then return 0 end
  local cmd = "find " .. M.shq(path) ..
    " -mindepth " .. min_depth .. " -maxdepth " .. max_depth ..
    " -type d 2>/dev/null | wc -l"
  local h = io.popen(cmd)
  if not h then return 0 end
  local n = tonumber((h:read("*a") or ""):match("(%d+)")) or 0
  h:close()
  return n
end

-- Conta i file dentro `path` che matchano `pattern`.
function M.count_files(path, pattern)
  if not path or path == "" then return 0 end
  pattern = pattern or "*"
  local cmd = "find " .. M.shq(path) ..
    " -maxdepth 1 -type f -name " .. M.shq(pattern) ..
    " 2>/dev/null | wc -l"
  local h = io.popen(cmd)
  if not h then return 0 end
  local n = tonumber((h:read("*a") or ""):match("(%d+)")) or 0
  h:close()
  return n
end

local function normalize_exit(a, b, c)
  if type(a) == "number" then return a end
  if a == true  then return tonumber(c) or 0 end
  if a == false then return tonumber(c) or 1 end
  return 0
end

function M.exec(cmd)
  local a, b, c = os.execute(cmd)
  return normalize_exit(a, b, c)
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
  if type(src) ~= "string" or src == "" then return false end
  if type(dst) ~= "string" or dst == "" then return false end
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
  if type(path) ~= "string" or path == "" then return false end
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