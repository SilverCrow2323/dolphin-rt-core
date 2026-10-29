-- core/launcher.lua — v0.4
-- Passes every launch.sh flag through: profile, variant, controller,
-- gamesettings, mods, logging, hotkeys, show-fps/vps/speed/osd.
--
-- v0.4 (2026-10-23): no more detached spawn. When mux_launch.sh is driving
-- us in loop mode (DOLPHINUI_LOOP=1) we write data/launch_cmd.sh,
-- data/launch.ret and data/launch.request, then quit LÖVE. mux_launch.sh
-- stays the muOS "app" for the whole cycle: no menu flash, no overlapping
-- CAFFEINE / OSD / gptokeyb2 transitions between LÖVE and Dolphin.

local Notify = require("ui.notify")
local State  = require("core.state")

local M = {}

local LAUNCH_CANDIDATES = {
    "launch.sh",
    "tools/launch.sh",
    "scripts/launch.sh",
}

local function find_launch_script()
    for _, p in ipairs(LAUNCH_CANDIDATES) do
        local f = io.open(p, "r")
        if f then f:close(); return p end
    end
    return nil
end

local function is_muos_device()
    local h = io.popen("[ -d /opt/muos/share/emulator/dolphin ] && echo 1")
    if not h then return false end
    local r = h:read("*a"); h:close()
    return r and r:match("1") ~= nil
end

local function shq(s)
    if s == nil then return "''" end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function b01(v) return v and "1" or "0" end


-- rtid_card_reader — pull [LAUNCH] values from workshop/gameslibrary/rtid_<ID>.ini
local function _read_rtid_launch(game_id)
  if not game_id or game_id == "" then return nil end
  local path = "workshop/gameslibrary/rtid_" .. game_id .. ".ini"
  local f = io.open(path, "r")
  if not f then return nil end
  local out, section = {}, nil
  for line in f:lines() do
    local s = line:match("^%s*%[([^%]]+)%]")
    if s then section = s
    elseif section == "LAUNCH" then
      local k, v = line:match("^%s*([^=]+)%s*=%s*(.*)$")
      if k then
        k = k:gsub("%s+$", "")
        v = v:gsub("^%s+", "")
        out[k] = v
      end
    end
  end
  f:close()
  return out
end

-- Write the launch request. mux_launch.sh will read these files, run
-- launch.sh synchronously and re-launch LÖVE when Dolphin exits.
local function write_launch_request(parts, return_to)
    -- 1) shell script with the full, properly quoted command
    local sf = io.open("data/launch_cmd.sh", "w")
    if not sf then
        Notify.show("error", "Cannot write data/launch_cmd.sh")
        return false
    end
    sf:write("#!/bin/bash\n")
    sf:write("exec " .. table.concat(parts, " ") .. "\n")
    sf:close()
    os.execute("chmod +x data/launch_cmd.sh 2>/dev/null")

    -- 2) the screen to return to when LÖVE comes back
    local rf = io.open("data/launch.ret", "w")
    if not rf then
        os.remove("data/launch_cmd.sh")
        Notify.show("error", "Cannot write data/launch.ret")
        return false
    end
    rf:write(tostring(return_to or "library"))
    rf:close()

    -- 3) the marker mux_launch.sh checks after LÖVE exits
    local mf = io.open("data/launch.request", "w")
    if not mf then
        os.remove("data/launch_cmd.sh")
        os.remove("data/launch.ret")
        Notify.show("error", "Cannot write data/launch.request")
        return false
    end
    mf:write("1")
    mf:close()

    return true
end

local function wipe_launch_request()
    os.remove("data/launch_cmd.sh")
    os.remove("data/launch.ret")
    os.remove("data/launch.request")
end

function M.launch(game, opts)
    opts = opts or {}
    -- Merge [LAUNCH] from the RTID card (game-specific identity)
    local rtid = _read_rtid_launch(game and game.id)
    if rtid then
      opts.profile      = opts.profile      or rtid.RtProfile
      opts.variant      = opts.variant      or rtid.RtProfileVariant
      opts.controller   = opts.controller   or rtid.Controller
      opts.hotkeys      = opts.hotkeys      or rtid.Hotkeys
      opts.gamesettings = opts.gamesettings or rtid.GameSettings
      opts.cheats       = (opts.cheats == nil) and (rtid.Cheats == "yes") or opts.cheats
      opts.mods         = opts.mods         or ((rtid.Mods == "yes") and "all" or nil)
      opts.logging      = opts.logging      or rtid.Logger
      if opts.show_fps   == nil then opts.show_fps   = (rtid.OverlayFPS   == "yes") end
      if opts.show_vps   == nil then opts.show_vps   = (rtid.OverlayVPS   == "yes") end
      if opts.show_speed == nil then opts.show_speed = (rtid.OverlaySpeed == "yes") end
      if opts.show_osd   == nil then opts.show_osd   = (rtid.OverlayOSD  ~= "no") end
    end
    if type(game) ~= "table" then
        Notify.show("warning", "Nothing to launch"); return false
    end
    local rom = game.path
    local id  = game.id
    local sys = game.system or "GC"
    if not rom or rom == "" then
        Notify.show("error", "Missing ROM path"); return false
    end

    if not is_muos_device() then
        Notify.show("info",
            "Dev mode: would launch " ..
            tostring(game.title or id or "?") ..
            " [" .. sys .. "]", 3.0)
        return false
    end

    local script = find_launch_script()
    if not script then
        Notify.show("error", "launch.sh not found"); return false
    end

    local default_rt = "library"
    pcall(function()
        local S = require("core.settings")
        default_rt = S.get("default_return_to") or "library"
    end)
    local return_to = opts.return_to or State.screen or default_rt
    State.opts = State.opts or {}
    State.opts.return_to = return_to

    -- Run it through its interpreter: works even when the exec bit was lost
    -- while copying the app to the SD card.
    local interp = "/bin/bash"
    do
        local f = io.open(script, "r")
        if f then
            local first = f:read("*l") or ""; f:close()
            local sh_path = first:match("^#!%s*(%S+)")
            if sh_path then interp = sh_path end
        end
        if interp:match("env$") then interp = "/bin/bash" end
        local g = io.open(interp, "r")
        if g then g:close() else interp = "sh" end
    end
    local parts = {
        interp,
        shq(script),
        "--mode=game",
        "--rom="     .. shq(rom),
        "--game-id=" .. shq(id  or ""),
        "--sys="     .. shq(sys),
        "--title="   .. shq(game.title or ""),
        "--profile=" .. shq(opts.profile or "Default"),
        "--return-to=" .. shq(return_to),
        "--show-fps="   .. b01(opts.show_fps),
        "--show-vps="   .. b01(opts.show_vps),
        "--show-speed=" .. b01(opts.show_speed),
        "--show-osd="   .. b01(opts.show_osd ~= false),
    }
    if opts.variant and opts.variant ~= "" then
        parts[#parts+1] = "--variant=" .. shq(opts.variant)
    end
    if opts.controller and opts.controller ~= "" then
        parts[#parts+1] = "--controller=" .. shq(opts.controller)
    end
    if opts.gamesettings and opts.gamesettings ~= "" then
        parts[#parts+1] = "--gamesettings=" .. shq(opts.gamesettings)
    end
    if opts.mods and opts.mods ~= "" and opts.mods ~= false then
        parts[#parts+1] = "--mods=" .. shq(opts.mods)
    end
    if opts.logging and opts.logging ~= "" and opts.logging ~= false then
        parts[#parts+1] = "--logging=" .. shq(opts.logging)
    end
    if opts.hotkeys and opts.hotkeys ~= "" and opts.hotkeys ~= false then
        parts[#parts+1] = "--hotkeys=" .. shq(opts.hotkeys)
    end
    if opts.orient and opts.orient ~= "" then
        parts[#parts+1] = "--orient=" .. shq(opts.orient)
    end
    if opts.cheats == true then
        parts[#parts+1] = "--cheats=1"
    end
    if opts.safe_exit ~= nil then
        parts[#parts+1] = "--safe-exit=" .. (opts.safe_exit and "1" or "0")
    end

    wipe_launch_request()
    if not write_launch_request(parts, return_to) then
        return false
    end

    Notify.show("info", "Launching " .. tostring(game.title or id or "?"), 1.5)
    -- Release ALSA + framebuffer before mux_launch.sh runs launch.sh.
    if love and love.timer and love.timer.sleep then
        love.timer.sleep(0.35)
    end
    love.event.quit()
    return true
end

function M.available()
    return find_launch_script() ~= nil and is_muos_device()
end

function M.script_path() return find_launch_script() end

return M