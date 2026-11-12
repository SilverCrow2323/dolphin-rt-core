-- muOS release detection and explicit input-profile override.
local Shell = require("core.shell")
local Settings = require("core.settings")
local M = {}

function M.detect()
    local value = os.getenv("MUOS_VERSION") or ""
    if value == "" then
        local cmd = "sh -c " .. Shell.shq(
            ". /opt/muos/script/var/func.sh >/dev/null 2>&1; GET_VAR system version 2>/dev/null")
        value = Shell.first(cmd, 3) or ""
    end
    if value == "" then
        value = Shell.first("cat /opt/muos/config/system/version 2>/dev/null", 2) or ""
    end
    value = tostring(value):lower()
    return value:find("andromeda", 1, true) and "andromeda" or "not_andromeda"
end

function M.profile()
    local choice = Settings.get("muos_profile") or "auto"
    if choice == "andromeda" then return "andromeda" end
    if choice == "not_andromeda" then return "not_andromeda" end
    return M.detect()
end

function M.label()
    local choice = Settings.get("muos_profile") or "auto"
    local resolved = M.profile()
    return choice:upper() .. " → " .. (resolved == "andromeda" and "ANDROMEDA" or "NON-ANDROMEDA")
end

return M
