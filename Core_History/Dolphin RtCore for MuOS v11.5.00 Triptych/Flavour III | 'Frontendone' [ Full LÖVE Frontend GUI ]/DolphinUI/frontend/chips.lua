-- frontend/chips.lua — launch options chip row.
-- Dynamic profile lists, feat-aware coloring.
--
-- Performance: profile scans (io.popen ls on workshop/) are expensive
-- on SD cards. They are cached with a 60-second TTL. `invalidate()`
-- forces a rebuild on next draw.
--
-- Theme awareness: the controller profile list is built from
-- workshop/controller/Wii/ or workshop/controller/GameCube/ depending
-- on State.theme_name. A GC ↔ Wii flip therefore has to drop the cache
-- immediately, not wait for the TTL to expire. ensure_chips() watches
-- State.theme_name and invalidates itself when it changes.

local SFX    = require("sfx")
local State  = require("state")
local Modal  = require("modal")

local M = {}
local CHIPS = nil
local CHIPS_AT = 0
local CHIPS_THEME = nil
-- The rescan (io.popen on workshop/) happens inside draw(), so keep the
-- TTL long: every place that changes a profile already calls
-- M.invalidate().
local CHIPS_TTL = 60   -- seconds

local function shq(s)
    if s == nil then return "''" end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- ── Profile scanners ────────────────────────────────────────
local function scan_rtcore_profiles()
    local list = {}
    local h = io.popen('timeout 2 ls -1 ' .. shq("workshop/rtcoreprofile") ..
                       ' 2>/dev/null')
    if h then
        for name in h:lines() do
            name = name:match("^%s*(.-)%s*$")
            if name ~= "" and name:sub(1, 1) ~= "." then
                local f = io.open("workshop/rtcoreprofile/" .. name ..
                                  "/rtprofile_data.ini", "r")
                if f then
                    f:close()
                    table.insert(list, name)
                end
            end
        end
        h:close()
    end
    table.sort(list, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a:lower() < b:lower()
    end)
    if #list == 0 then list = { "Default" } end
    return list
end

local function scan_controller_profiles()
    local sys = (State.theme_name == "wii") and "Wii" or "GameCube"
    local list = {}
    local base = "workshop/controller/" .. sys
    local h = io.popen('timeout 2 ls -1 ' .. shq(base) .. ' 2>/dev/null')
    if h then
        for name in h:lines() do
            name = name:match("^%s*(.-)%s*$")
            if name ~= "" and name:sub(1, 1) ~= "." then
                local f = io.open(base .. "/" .. name .. "/rtcontroller_data.ini", "r")
                if f then
                    f:close()
                    table.insert(list, name)
                end
            end
        end
        h:close()
    end
    table.sort(list, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a:lower() < b:lower()
    end)
    if #list == 0 then list = { "Default" } end
    return list
end

-- ── Chip catalogue ──────────────────────────────────────────
local function build_chips()
    return {
        { key = "core",       label = "Core",     type = "cycle",
          feat = "dolphin",   values = { "local", "external" } },
        { key = "hotkeys",    label = "Hotkeys",  type = "toggle", feat = "hotkeys" },
        { key = "livemenu",   label = "LiveMenu", type = "toggle", feat = "livemenu" },
        { key = "logging",    label = "Logging",  type = "toggle", feat = "logging" },
        { key = "controller", label = "Ctrl",     type = "cycle",  feat = "controller",
          values = scan_controller_profiles() },
        { key = "profile",    label = "Profile",  type = "cycle",  feat = "profile",
          values = scan_rtcore_profiles() },
    }
end

local function ensure_chips()
    local now = os.time()

    -- Theme flip: the controller list is built from a per-theme
    -- directory. Invalidate immediately so the chip row never shows
    -- the previous theme's profiles for up to 60 s after a GC↔Wii
    -- switch (the user sees "Default" of the wrong system).
    if CHIPS and CHIPS_THEME ~= State.theme_name then
        CHIPS = nil
        CHIPS_AT = 0
    end

    if not CHIPS or (now - CHIPS_AT) > CHIPS_TTL then
        CHIPS = build_chips()
        CHIPS_AT = now
        CHIPS_THEME = State.theme_name
    end
    return CHIPS
end

-- Force rebuild on next draw (call from workshop after applying/creating
-- a profile).
function M.invalidate()
    CHIPS = nil
    CHIPS_AT = 0
    CHIPS_THEME = nil
end

-- ── Rendering helpers ───────────────────────────────────────
local function chip_w(text, font)
    return font:getWidth(text) + 34
end

local function display(chip)
    if chip.type == "cycle" then
        return chip.label .. ": " .. (State.opts[chip.key] or "?")
    end
    return chip.label
end

local function chip_state(chip)
    local feat = State.features[chip.feat]
    local available = feat and feat.available
    local active = false
    if chip.type == "toggle" then
        active = (State.opts[chip.key] == true)
    elseif chip.type == "cycle" then
        active = true
    end
    return available, active
end

function M.draw(x, y, font)
    local chips = ensure_chips()
    local th = State.theme
    local cx = x

    for _, chip in ipairs(chips) do
        local text = display(chip)
        local w = chip_w(text, font)
        local available, active = chip_state(chip)

        if not available then
            love.graphics.setColor(0.15, 0.15, 0.18, 0.7)
        elseif active then
            love.graphics.setColor(th.panel[1], th.panel[2], th.panel[3], 0.95)
        else
            love.graphics.setColor(th.panel[1]*0.6, th.panel[2]*0.6,
                                   th.panel[3]*0.6, 0.7)
        end
        love.graphics.rectangle("fill", cx, y, w, 22, 11, 11)

        if not available then
            love.graphics.setColor(0.30, 0.30, 0.30, 0.5)
        elseif active then
            love.graphics.setColor(th.focus)
        else
            love.graphics.setColor(th.accent[1], th.accent[2], th.accent[3], 0.5)
        end
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", cx, y, w, 22, 11, 11)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(available and th.text or { 0.45, 0.45, 0.48 })
        love.graphics.setFont(font)
        love.graphics.printf(text, cx, y + 4, w, "center")

        cx = cx + w + 6
    end

    return cx - x
end

function M.hit_test(x, y, font)
    local chips = ensure_chips()
    local hits = {}
    local cx = x
    for _, chip in ipairs(chips) do
        local text = display(chip)
        local w = chip_w(text, font)
        hits[#hits + 1] = { chip = chip, x = cx, y = y, w = w, h = 22 }
        cx = cx + w + 6
    end
    return hits
end

-- ── Activation ──────────────────────────────────────────────
local function cycle_value(values, current)
    local idx = 1
    for i, v in ipairs(values) do
        if v == current then idx = i break end
    end
    return values[(idx % #values) + 1]
end

function M.activate(chip)
    local feat = State.features[chip.feat]
    if not feat or not feat.available then
        Modal.show("Feature not available",
            (chip.label or "?") .. " cannot be enabled.\n\n" ..
            (feat and feat.reason or "File missing."))
        SFX.play("menu_back")
        return
    end

    if chip.type == "toggle" then
        State.opts[chip.key] = not State.opts[chip.key]
        SFX.play("menu_toggleoption")
    elseif chip.type == "cycle" then
        local values = chip.values or {}
        if #values == 0 then return end
        State.opts[chip.key] = cycle_value(values, State.opts[chip.key])
        SFX.play("menu_toggleoption")

        if chip.key == "profile" then
            pcall(function()
                local PM = require("profile_manager")
                PM.apply("rtcoreprofile", State.opts.profile)
                PM.set_active("rtcoreprofile", State.opts.profile)
            end)
        end
    end
end

return M