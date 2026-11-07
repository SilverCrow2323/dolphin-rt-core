local M = {}
local cache = {}
local fallback_cache = {}

function M.get(path, size)
  size = math.max(6, math.floor(size or 12))
  local key = path .. "|" .. size
  if cache[key] ~= nil then return cache[key] end
  local f = love.graphics.newFont(path, size)
  cache[key] = f
  return f
end

function M.fallback(size)
  size = math.max(6, math.floor(size or 12))
  if fallback_cache[size] then return fallback_cache[size] end
  local f = love.graphics.newFont(size)
  fallback_cache[size] = f
  return f
end

function M.clear() cache = {}; fallback_cache = {} end

return M
