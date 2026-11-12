-- core/muos.lua — Rt:UI integration with muOS core registration.
--
-- The manifest helper is the single source of truth for GameCube/Wii
-- registration and the Standard Only / All Tiers profile mode. No Task
-- Toolkit files are needed by the current frontend.
--
-- DOLPHINUI_MUOS_ROOT prefixes /opt paths for isolated contract tests.

local Shell = require("core.sh")
local M = {}

local ROOT = os.getenv("DOLPHINUI_MUOS_ROOT") or ""
local EMU = os.getenv("RT_EMUDIR") or "/opt/muos/share/emulator/dolphin"

local function resolve(path)
    if ROOT ~= "" and path:match("^/opt/") then
        return ROOT .. path
    end
    return path
end

local TOOL = resolve(EMU .. "/RtSys/manifest_tool.sh")
local MODE_FILE = resolve(EMU .. "/RtSys/switch_weapon/mode.conf")
local LOG_FILE = resolve(EMU .. "/RtSys/logs/rtui-manifest.log")

local function read_mode()
    local f = io.open(MODE_FILE, "r")
    if not f then return nil end
    local data = f:read("*a") or ""
    f:close()
    local mode = tonumber(data:match("^%s*MODE%s*=%s*([12])[%s\r\n]*$"))
    if mode == 1 or mode == 2 then return mode end
    return nil
end

local cached_mode = read_mode() or 1

function M.profile_mode_id()
    cached_mode = read_mode() or cached_mode or 1
    return cached_mode
end

function M.profile_mode()
    return M.profile_mode_id() == 2 and "All Tiers" or "Standard Only"
end

local function read_log()
    local f = io.open(LOG_FILE, "r")
    if not f then return nil end
    local data = f:read("*a") or ""
    f:close()
    data = data:gsub("%s+$", "")
    if data == "" then return nil end
    return data
end

local function run(arguments)
    local log_dir = LOG_FILE:match("^(.*)/[^/]+$") or "."
    local command = "mkdir -p " .. Shell.shq(log_dir) ..
        " && if [ ! -f " .. Shell.shq(TOOL) .. " ]; then " ..
        "echo 'manifest_tool.sh is missing' > " .. Shell.shq(LOG_FILE) ..
        "; exit 127; fi; sh " .. Shell.shq(TOOL) .. " " .. arguments ..
        " > " .. Shell.shq(LOG_FILE) .. " 2>&1"

    local a, b, c = os.execute(command)
    local ok = a == true or a == 0 or c == 0
    if not ok then
        return false, read_log() or ("manifest_tool.sh " .. arguments .. " failed")
    end
    cached_mode = read_mode() or cached_mode
    return true, read_log()
end

function M.ensure()
    return run("ensure")
end

function M.apply_profile_mode(mode)
    local n = tonumber(mode)
    if n ~= 1 and n ~= 2 then
        return false, "profile mode must be 1 (Standard Only) or 2 (All Tiers)"
    end
    local ok, detail = run("apply " .. tostring(n))
    if not ok then return false, detail end
    cached_mode = n
    return true, detail
end

return M
