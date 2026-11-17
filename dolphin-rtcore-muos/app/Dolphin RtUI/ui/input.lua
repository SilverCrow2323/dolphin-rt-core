-- Mappa raw LOVE -> logico. La mappa effettiva viene da core.app_input.
local AppInput = require("core.app_input")

local M = {}

M.A      = "A"
M.B      = "B"
M.X      = "X"
M.Y      = "Y"
M.L1     = "L1"
M.R1     = "R1"
M.L2     = "L2"
M.R2     = "R2"
M.L3     = "L3"
M.SELECT = "SELECT"
M.START  = "START"
M.MENU   = "MENU"
M.UP     = "UP"
M.DOWN   = "DOWN"
M.LEFT   = "LEFT"
M.RIGHT  = "RIGHT"

function M.rebuild()
    local pad = AppInput.pad_map() or {}
    M.raw_to_logical = {}
    for logical, idx in pairs(pad) do
        if type(idx) == "number" then
            M.raw_to_logical[idx] = logical
        end
    end
end

function M.from_raw(raw)
    return M.raw_to_logical and M.raw_to_logical[raw] or nil
end

function M.from_gamepad(name)
    return AppInput.from_gamepad(name)
end

function M.from_gamepad_axis(axis)
    if not AppInput.from_gamepad_axis then return nil end
    return AppInput.from_gamepad_axis(axis)
end

-- init lazy (safe)
if not AppInput.data then pcall(AppInput.init) end
pcall(M.rebuild)

return M
