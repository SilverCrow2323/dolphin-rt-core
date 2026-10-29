-- frontend/crash_handler.lua
-- Persistent crash reporter for DolphinUI.
--
-- ── Behaviour ─────────────────────────────────────────────────
--   1. love.errorhandler is replaced with a version that writes
--      a full traceback to data/logs/crash_<timestamp>.log and
--      sets a persistent flag file (data/logs/crash_pending.flag).
--   2. The crash screen is fully interactive: any key press,
--      joystick button press, gamepad button press, or mouse
--      click exits the process. The previous revision drew a
--      "Press any button to exit" message but registered NO
--      input handlers — the process sat in the crash loop
--      forever.
--   3. On the next successful boot, surface_previous() reads the
--      flag, shows a Notify toast, and clears the flag.
--
-- ── Log format ────────────────────────────────────────────────
-- Plain text. Prepend-only. Rotation is handled by main.lua's
-- rotate_all_logs() (keeps the last 20 crash logs).
--
-- ── Why a separate file ───────────────────────────────────────
-- main.lua is the input dispatcher and the navigation core. The
-- crash handler is orthogonal: it runs when nothing else does. A
-- separate module keeps it importable (and testable) without
-- dragging main.lua's entire require tree into the process.

local State   = require("state")

local M = {}

-- Paths
local LOG_DIR     = "data/logs"
local FLAG_PATH   = LOG_DIR .. "/crash_pending.flag"

-- App version is set by main.lua at install() time so the crash
-- log shows the revision that produced it.
local _app_version = "unknown"

-- ── Internal helpers ────────────────────────────────────────
local function ensure_dir(path)
    os.execute("mkdir -p " .. "'" .. tostring(path):gsub("'", "'\\''")
               .. "'")
end

local function touch(path, content)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content or "")
    f:close()
    return true
end

-- ── Public: write a crash log + set the flag ────────────────
-- Returns the path of the written log.
function M.write_log(traceback_text, opts)
    opts = opts or {}
    ensure_dir(LOG_DIR)

    local stamp = os.date("%Y%m%d_%H%M%S")
    local path  = LOG_DIR .. "/crash_" .. stamp .. ".log"

    local f = io.open(path, "w")
    if f then
        f:write("DolphinUI crash @ "
            .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        f:write("Version: " .. tostring(_app_version) .. "\n")
        f:write("Screen : " .. tostring(opts.screen or State.screen) .. "\n")
        if opts.context then
            f:write("Context: " .. tostring(opts.context) .. "\n")
        end
        f:write("\n")
        f:write(tostring(traceback_text) .. "\n")
        f:close()
    end

    -- Flag file: holds the path so the next boot can point at it.
    touch(FLAG_PATH, path .. "\n")
    return path
end

-- ── Public: crash screen ────────────────────────────────────
-- Draws the last error on a red screen. Returns when the user
-- has acknowledged it (or after an auto-timeout of 60 s, as a
-- last-ditch safety so a stuck crash screen doesn't trap the
-- device). Always calls os.exit() before returning.
--
-- This is called from love.errorhandler's returned closure. The
-- closure is invoked by LÖVE's run loop, so we get one call per
-- frame; we do our own event pump + draw + present.
local function draw_crash(traceback_text, path, elapsed)
    local W, H = 640, 480

    love.graphics.origin()
    love.graphics.clear(0.10, 0.02, 0.02)

    -- Panel
    love.graphics.setColor(0.18, 0.04, 0.04, 1)
    love.graphics.rectangle("fill", 12, 12, W - 24, H - 24, 6, 6)
    love.graphics.setColor(0.85, 0.30, 0.30, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 12, 12, W - 24, H - 24, 6, 6)
    love.graphics.setLineWidth(1)

    -- Header
    love.graphics.setColor(1, 0.90, 0.90)
    love.graphics.print("DolphinUI crashed.", 24, 24)

    love.graphics.setColor(0.90, 0.75, 0.75)
    love.graphics.print("Log: " .. tostring(path or "?"), 24, 48)

    -- Countdown
    local remaining = math.max(0, 60 - math.floor(elapsed or 0))
    love.graphics.setColor(0.85, 0.60, 0.60)
    love.graphics.print(
        "Press any button to exit (" .. remaining .. "s)",
        24, 70)

    -- Traceback excerpt
    love.graphics.setColor(0.72, 0.58, 0.58)
    local body = tostring(traceback_text or ""):sub(1, 900)
    love.graphics.printf(body, 24, 100, W - 48, "left")

    love.graphics.setColor(0.55, 0.40, 0.40)
    love.graphics.print("— end —", 24, H - 34)
end

-- Mini event loop: pumps LÖVE's event queue, returns true when
-- the user has asked to quit (any input or the quit event).
local function user_wants_quit()
    love.event.pump()
    for name, a, _b, _c, _d, _e, _f in love.event.poll() do
        if name == "quit" then
            return true
        end
        if name == "keypressed"
           or name == "keyreleased"
           or name == "joystickpressed"
           or name == "gamepadpressed"
           or name == "mousepressed"
           or name == "touchpressed"
        then
            -- Filter out modifier-only keys so accidentally
            -- resting on a shoulder button doesn't exit.
            if name ~= "keypressed" or
               (a ~= "lshift" and a ~= "rshift"
                and a ~= "lctrl" and a ~= "rctrl"
                and a ~= "lalt" and a ~= "ralt")
            then
                return true
            end
        end
    end
    return false
end

-- Minimal cleanup before exit. We deliberately avoid pcall-chains
-- through every manager: the process is already in an undefined
-- state; the goal is to release the framebuffer and ALSA device
-- so the launcher shell can restart cleanly.
local function cleanup_and_exit()
    pcall(function()
        if love and love.audio and love.audio.stop then
            love.audio.stop()
        end
    end)
    pcall(function()
        if love and love.graphics and love.graphics.present then
            love.graphics.present()
        end
    end)
    pcall(function()
        if love and love.event and love.event.quit then
            love.event.quit()
        end
    end)
    -- Hard exit: some ALSA/FB drivers on muOS will not release on
    -- a soft quit when the graphics state is corrupt.
    os.exit(1)
end

-- ── Public: install the error handler ───────────────────────
-- Call from main.lua's love.load() (or from the top of conf).
-- `version` is the APP_VERSION string.
function M.install(version)
    _app_version = version or "unknown"

    function love.errorhandler(msg)
        local traceback_text = debug.traceback(tostring(msg), 2)

        print("CRASH: " .. traceback_text)

        local path = M.write_log(traceback_text)
        print("CRASH log written to " .. path)

        local t0 = love.timer and love.timer.getTime() or 0
        local elapsed = 0

        -- Return a closure. LÖVE's run loop calls it once per
        -- frame. We do our own event pump inside.
        return function()
            if user_wants_quit() then
                cleanup_and_exit()
            end

            elapsed = (love.timer and
                       (love.timer.getTime() - t0)) or (elapsed + 0.1)

            if elapsed > 60 then
                -- Safety net: no user response in 60 s.
                cleanup_and_exit()
            end

            draw_crash(traceback_text, path, elapsed)

            if love.graphics and love.graphics.present then
                love.graphics.present()
            end
            if love.timer and love.timer.sleep then
                love.timer.sleep(0.05)
            end
        end
    end
end

-- ── Public: surface a crash that happened in a prior session ─
-- Call from main.lua's love.load(), AFTER the notify module is
-- available. Reads the flag, shows a toast, clears the flag.
function M.surface_previous()
    local f = io.open(FLAG_PATH, "r")
    if not f then return end
    local path = (f:read("*l") or "?"):gsub("%s+$", "")
    f:close()
    os.remove(FLAG_PATH)

    local ok, Notify = pcall(require, "notify")
    if ok and Notify and Notify.show then
        Notify.show("warning",
            "Previous session crashed — see data/logs", 5.0)
    end

    print("[crash_handler] prior crash surfaced: " .. path)
    return path
end

-- ── Public: has the flag been set? (query, no side effect) ──
function M.has_pending()
    local f = io.open(FLAG_PATH, "r")
    if f then f:close(); return true end
    return false
end

return M