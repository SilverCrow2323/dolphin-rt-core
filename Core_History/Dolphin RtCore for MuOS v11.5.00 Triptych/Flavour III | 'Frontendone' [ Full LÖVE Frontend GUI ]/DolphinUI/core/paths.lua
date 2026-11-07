-- Unico posto dove vivono i path. Nessun hardcode altrove.
local M = {}

local ROOT_EMU_DEFAULT = "/opt/muos/share/emulator/dolphin"

M.root_emu = ROOT_EMU_DEFAULT

function M.init()
  -- se esiste un override locale, usalo
  local f = io.open("data/paths.ini", "r")
  if f then
    for line in f:lines() do
      local k, v = line:match("^%s*([%w_]+)%s*=%s*(.*)$")
      if k == "root_emu" and v and v ~= "" then
        M.root_emu = v
      end
    end
    f:close()
  end
end

function M.emu(...)  return table.concat({ M.root_emu, ... }, "/") end
function M.data(...) return table.concat({ "data", ... }, "/") end
function M.asset(...)return table.concat({ "assets", ... }, "/") end

return M
