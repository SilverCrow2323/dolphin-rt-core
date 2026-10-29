local M = {}

local subs = {}

function M.init()
  subs = {}
end

function M.on(name, fn)
  subs[name] = subs[name] or {}
  table.insert(subs[name], fn)
end

function M.emit(name, ...)
  local list = subs[name]
  if not list then return end
  for _, fn in ipairs(list) do
    local ok, err = pcall(fn, ...)
    if not ok then
      print(("[events] handler error on '%s': %s"):format(name, err))
    end
  end
end

return M
