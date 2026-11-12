-- muOS release detection and explicit firmware-family override.
local Shell = require("core.shell")
local Settings = require("core.settings")
local M = {}
local detected

-- Jacaranda and every non-Andromeda build resolve to the initial profile.
-- Keep the test pure so firmware-family logic can be checked without a device.
function M.resolve(version)
    local value = tostring(version or ""):lower()
    return value:find("andromeda", 1, true) and "andromeda" or "not_andromeda"
end

function M.detect()
    if detected then return detected end
    local value = os.getenv("MUOS_VERSION") or ""
    if value == "" then
        local cmd = "sh -c " .. Shell.shq(
            ". /opt/muos/script/var/func.sh >/dev/null 2>&1; GET_VAR system version 2>/dev/null")
        value = Shell.first(cmd, 3) or ""
    end
    if value == "" then
        value = Shell.first("cat /opt/muos/config/system/version 2>/dev/null", 2) or ""
    end
    detected = M.resolve(value)
    return detected
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
    if choice == "andromeda" then return "FORCE = ANDROMEDA" end
    if choice == "not_andromeda" then return "FORCE != ANDROMEDA" end
    return resolved == "andromeda" and "AUTO → ANDROMEDA" or "AUTO → != ANDROMEDA"
end

return M
