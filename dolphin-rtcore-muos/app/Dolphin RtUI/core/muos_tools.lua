-- core/muos_tools.lua — UI-owned actions for muOS Dolphin Rt:Core registration.
local sh = require("core.sh")
local M = {}
local TOOL = "/opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh"
local LOG = "data/logs/muos-manifest.log"

local function read(path)
    local f = io.open(path, "rb")
    if not f then return "" end
    local s = f:read("*a") or ""
    f:close()
    return s
end

function M.apply(mode)
    if mode ~= nil then
        mode = tonumber(mode)
        if mode ~= 1 and mode ~= 2 then return false, "invalid catalogue mode" end
    end
    local f = io.open(TOOL, "r")
    if not f then return false, "manifest_tool.sh not found; reinstall Dolphin Rt:Core" end
    f:close()
    os.execute("mkdir -p data/logs 2>/dev/null")
    local command = "sh " .. sh.shq(TOOL) .. " apply"
    if mode then command = command .. " " .. tostring(mode) end
    command = command .. " > " .. sh.shq(LOG) .. " 2>&1; rc=$?; sync; exit $rc"
    local a, b, c = os.execute(command)
    local ok = a == true or a == 0 or c == 0
    local output = read(LOG)
    if not ok then return false, output ~= "" and output or tostring(a) end
    return true, output
end

return M
