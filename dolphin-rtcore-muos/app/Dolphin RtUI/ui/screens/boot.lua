-- ui/screens/boot.lua — brand intro: the cyber-dolphin circles the handheld,
-- lightning hits the screen, the logo types in. Meanwhile the boot job
-- (update check, ROM scan, rtid cards) runs; the intro never delays a boot
-- that is already ready by more than the animation itself.
--   Settings > Boot intro:  full (about 5 s) | quick (about 2.5 s) | off
-- [A] skips after a short grace period.
local K        = require("ui.kit")
local Mascot   = require("ui.mascot")
local Settings = require("core.settings")
local ok_bi, BI = pcall(require, "core.boot_initializer")

local S = {}
local LABEL = { update_check = "Checking for updates", scan_roms = "Scanning ROM folders",
                build_rtid = "Building game cards", done = "Ready", idle = "Starting" }
local END_FRAME = Mascot.FRAMES             -- complete the full 2.5D animation once

function S.enter()
    S.t, S.going, S.flash = 0, false, 0
    S.mode = Settings.get("boot_anim") or "full"
    S.speed = (S.mode == "quick") and 2 or 1
    S.have = (S.mode ~= "off") and Mascot.load()
    K.set_accent("gc")
end

function S.leave() Mascot.release() end

local function proceed()
    if S.going then return end
    S.going = true
    local target = "library"
    -- Do the first-run mount probe at the end of the intro as well. The boot
    -- worker may still be downloading metadata; ROM setup must not depend on
    -- that network work finishing before the animation does.
    if Settings.get("rom_discovery_done") ~= true then
        pcall(Settings.auto_discover_rom_paths)
    end
    if Settings.get("rom_discovery_done") ~= true
       or (ok_bi and BI.needs_rom_setup and BI.needs_rom_setup()) then
        target = "folders"
    end
    require("ui").go(target, nil, { no_push = true })
end

function S.update(dt)
    S.t = S.t + dt
    local frame = S.t * Mascot.FPS * S.speed
    if S.mode == "off" or not S.have then
        -- The intro is presentation, not a gate: never require controller input
        -- or wait for network/update jobs before entering the application.
        if S.t >= 0.20 then proceed() end
        return
    end
    -- lightning flash around the hit frame
    local d = math.abs(frame - Mascot.HIT)
    S.flash = d < 5 and (1 - d / 5) or 0
    if frame >= END_FRAME then proceed() end
end

function S.pad(b) if b == "A" and S.t > 0.5 then proceed() end end

local function glow(cx, cy, r, c, a)
    for i = 16, 1, -1 do
        K.color(c, a * 0.045)
        love.graphics.circle("fill", cx, cy, r * i / 16)
    end
end

function S.draw()
    local cx = K.W / 2
    local frame = S.have and math.min(Mascot.FRAMES - 1, math.floor(S.t * Mascot.FPS * S.speed)) or 0
    -- stage glow behind the scene (reacts to the lightning)
    glow(cx, 190, 190, K.acc, 0.5 + S.flash * 1.2)
    if S.have then
        local fade = math.min(1, S.t / 0.35)
        Mascot.draw(frame, cx, 52, 1.5, fade)
    end
    if S.flash > 0 then
        K.color({ 0.75, 0.65, 1.0 }, 0.20 * S.flash)
        love.graphics.rectangle("fill", 0, 0, K.W, K.H)
    end
    -- logo: types in
    local word = "DOLPHIN"
    local shown = math.min(#word, math.floor(math.max(0, S.t - 0.4) / 0.07))
    local f = K.font("title")
    love.graphics.setFont(f)
    local spacing = 6
    local total = 0
    for i = 1, #word do total = total + f:getWidth(word:sub(i, i)) + spacing end
    local x = cx - (total - spacing) / 2
    for i = 1, shown do
        local ch = word:sub(i, i)
        K.color(K.C.text, 1)
        love.graphics.print(ch, x, 322)
        x = x + f:getWidth(ch) + spacing
    end
    local uw = 220 * math.min(1, math.max(0, S.t - 0.9) / 0.5)
    K.color(K.acc, 1); love.graphics.rectangle("fill", cx - uw / 2, 356, uw, 3)
    K.text("h", "Rt:UI  ·  muOS", 0, 366, K.acc, math.min(1, math.max(0, S.t - 1.2) / 0.4), K.W, "center")
    -- progress + status
    local step = ok_bi and BI.step and BI.step() or "idle"
    local prog = S.have and math.min(1, frame / END_FRAME) or math.min(1, S.t / 2)
    if not (step == "done") then prog = math.min(prog, 0.96) end
    K.bar(cx - 130, 414, 260, 4, prog, K.acc)
    K.text("small", (LABEL[step] or step) .. "…", 0, 424, K.C.dim, 1, K.W, "center")
    local ok_v, V = pcall(require, "version")
    if ok_v and V then K.text("mono", "v" .. V.string, 0, K.H - 24, K.C.faint, 1, K.W, "center") end
end

return S
