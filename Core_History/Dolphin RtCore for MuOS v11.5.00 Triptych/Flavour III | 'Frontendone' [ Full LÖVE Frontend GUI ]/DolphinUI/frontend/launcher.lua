-- frontend/launcher.lua — apply profiles then hand off to launch_game.sh.
--
-- SECURITY: every value that ends up inside a shell command is single-
-- quoted via sh.shq().
--
-- Flow:
--   1. Sanity-check the Dolphin binary
--   2. Apply rtcore + controller profiles (local mode only)
--   3. Apply active GameSettings config for this game (if any)
--   4. Hand off to scripts/launch_game.sh with all args safely quoted

local State  = require("state")
local Notify = require("notify")
local PM     = require("profile_manager")
local sh     = require("sh")

local M = {}

local SCRIPT = "scripts/launch_game.sh"

-- ── Apply rtcore profile ─────────────────────────────────────
local function apply_rtcore(profile)
    if not profile or profile == "" then return true end
    local ok, err = pcall(PM.apply, "rtcoreprofile", profile)
    if not ok then
        print("[launcher] rtcore apply failed: " .. tostring(err))
        return false
    end
    PM.set_active("rtcoreprofile", profile)
    return true
end

-- ── Apply controller profile ─────────────────────────────────
-- Copies the INI into dolphin-emu/Config/. sh.atomic_copy verifies the
-- tmp file before replacing the live one, so a partial copy cannot
-- leave Config/<pad>.ini empty.
local function apply_controller(system, name)
    if not name or name == "" then return true end
    local sys = (system == "Wii") and "Wii" or "GameCube"
    local fname = (sys == "Wii") and "WiimoteNew.ini" or "GCPadNew.ini"
    local src = "workshop/controller/" .. sys .. "/" .. name .. "/" .. fname
    local dst = "dolphin-emu/Config/" .. fname

    local f = io.open(src, "r")
    if not f then
        print("[launcher] controller source missing: " .. src)
        return false
    end
    f:close()

    if not sh.atomic_copy(src, dst) then
        print("[launcher] controller copy failed: " .. src .. " -> " .. dst)
        return false
    end
    PM.set_active("controller", name)
    return true
end

-- ── Apply active GameSettings config ────────────────────────
local function apply_gameset(game)
    if not game or not game.id or game.id == "" then return true end

    local ok, GM = pcall(require, "gameset_manager")
    if not ok or not GM then return true end

    local active = GM.get_active(game.id)
    if not active or active == "" then return true end

    local applied, err = GM.apply_active(game.id)
    if not applied then
        print(string.format("[launcher] gameset apply for %s: %s",
            game.id, tostring(err)))
    else
        print(string.format("[launcher] gameset applied: %s / %s",
            game.id, active))
    end
    return true
end

-- ── Resolve emulator executable path ─────────────────────────
local function emu_path(core_mode)
    if core_mode == "external" then
        return "/opt/muos/share/emulator/dolphin/dolphin"
    end
    return "dolphin-emu/dolphin"
end

-- ── Main entry ────────────────────────────────────────────────
function M.launch(game)
    if not game then return end

    local o = State.opts
    local core_mode = o.core or "local"

    -- 1) Sanity check the binary
    local emu = emu_path(core_mode)
    local f = io.open(emu, "rb")
    if not f then
        local Modal = require("modal")
        Modal.show("Dolphin not found",
            "Executable not found at:\n" .. emu ..
            "\n\nMake sure dolphin-emu/ contains the binary, " ..
            "or switch Core to 'external' in the Settings chips row.")
        return
    end
    f:close()

    -- 2) Apply profiles (local mode only)
    if core_mode ~= "external" then
        if not apply_rtcore(o.profile) then
            Notify.show("warning", "Profile apply failed: " ..
                tostring(o.profile))
        end
        apply_controller(game.sys, o.controller or "Default")
    end

    -- 3) Apply active GameSettings config
    apply_gameset(game)

    -- 4) Build the command line
    local mode = ""
    if game.virtual == "gc"  then mode = "--gc-console"
    elseif game.virtual == "wii" then mode = "--wii-menu" end

    local cmd
    if mode ~= "" then
        cmd = table.concat({
            "scripts/launch_game.sh",
            sh.shq(""), sh.shq(""),
            sh.shq(o.profile or "Default"),
            sh.shq(o.controller or ""),
            sh.shq(tostring(o.hotkeys == true)),
            sh.shq(tostring(o.livemenu == true)),
            sh.shq(tostring(o.logging == true)),
            sh.shq(core_mode),
            sh.shq(mode),
        }, " ")
    else
        cmd = table.concat({
            "scripts/launch_game.sh",
            sh.shq(game.path or ""),
            sh.shq(game.id or ""),
            sh.shq(o.profile or "Default"),
            sh.shq(o.controller or ""),
            sh.shq(tostring(o.hotkeys == true)),
            sh.shq(tostring(o.livemenu == true)),
            sh.shq(tostring(o.logging == true)),
            sh.shq(core_mode),
        }, " ")
    end

    -- Copying the app to an SD card (or extracting the archive) can drop
    -- the exec bit: without this the launch silently did nothing.
    sh.exec("chmod +x " .. sh.shq(SCRIPT) .. " 2>/dev/null")

    local code = sh.exec(cmd)
    if code == 126 or code == 127 then
        local Modal = require("modal")
        Modal.show("Launch failed",
            SCRIPT .. " could not be executed.\n\n" ..
            "Check that the file exists and is executable (chmod +x).")
    elseif code == 2 then
        local Modal = require("modal")
        Modal.show("Launch failed",
            "The launcher found no ROM and no virtual mode.\n\n" ..
            "See data/logs/launcher_*.log.")
    end
    -- Any other code is Dolphin's own exit status (143 = quit from the
    -- Live Menu, for instance) and is not an error on our side.
end

return M