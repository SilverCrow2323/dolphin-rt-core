-- Safe Exit editor.
-- Default is START + SELECT. Multi-button combinations are also
-- supported; the watcher reads the same raw joydev button indices.
local K = require("ui.kit")
local IM = require("ui.input")
local SafeExit = require("core.safe_exit")
local Notify = require("ui.notify")
local SFX = require("ui.sfx")

local S = {}
S.capturing = false
S.capture = {}
S.capture_t = 0
S.capture_idle = 0
S.current = ""

local function refresh()
    S.current = SafeExit.describe()
end

local function commit()
    if #S.capture == 0 then
        S.capturing = false
        Notify.show("info", "No buttons captured")
        return false
    end
    local ok, result = SafeExit.save_names(S.capture)
    if ok then
        S.current = result
        S.capturing = false
        S.capture = {}
        S.capture_t, S.capture_idle = 0, 0
        Notify.show("success", "Safe Exit set to " .. result)
        SFX.play("menu_select")
        return true
    end
    Notify.show("warning", tostring(result))
    S.capture_idle = 0
    return false
end

local function start_capture()
    S.capturing = true
    S.capture = {}
    S.capture_t, S.capture_idle = 0, 0
    SFX.play("menu_select")
end

function S.enter()
    K.set_accent("hot")
    S.capturing = false
    S.capture = {}
    refresh()
end

function S.leave()
    S.capturing = false
    S.capture = {}
end

-- Raw callback runs before logical UI dispatch. While capturing, every button
-- is consumed here so the combo cannot also activate a UI action.
function S.raw_pad(value)
    if not S.capturing then return false end
    local logical
    if type(value) == "number" then
        logical = IM.from_raw(value)
    elseif type(value) == "string" then
        logical = IM.from_gamepad(value)
    end
    if logical then
        logical = tostring(logical):upper()
        local exists = false
        for _, name in ipairs(S.capture) do if name == logical then exists = true end end
        if not exists and #S.capture < 4 then
            S.capture[#S.capture + 1] = logical
            S.capture_idle = 0
        end
    end
    return true
end

function S.key(key)
    if S.capturing and (key == "escape" or key == "esc") then
        S.capturing = false
        S.capture = {}
        Notify.show("info", "Capture cancelled")
    end
end

function S.update(dt)
    if not S.capturing then return end
    S.capture_t = S.capture_t + dt
    if #S.capture > 0 then
        S.capture_idle = S.capture_idle + dt
        if S.capture_idle >= 1.0 then commit() end
    elseif S.capture_t >= 6 then
        S.capturing = false
        Notify.show("info", "Capture timed out")
    end
end

function S.pad(button)
    if S.capturing then return end
    if button == "A" then
        start_capture()
    elseif button == "Y" then
        local ok, err = SafeExit.reset()
        if ok then
            refresh()
            Notify.show("success", "Safe Exit restored to START + SELECT")
        else
            Notify.show("error", tostring(err or "Could not reset Safe Exit"))
        end
    elseif button == "B" then
        require("ui").back()
    end
end

function S.draw()
    K.bg_workshop(0)
    K.header("Safe Exit", "Choose how Dolphin closes without stealing gameplay buttons", nil, { icon = "hotkeys" })

    K.panel(K.MARGIN, 112, K.W - K.MARGIN * 2, 230, { cut = 12 })
    K.text("small", "CURRENT EXIT COMBINATION", K.MARGIN + 22, 137, K.C.dim)
    K.text("xl", S.capturing and (#S.capture > 0 and table.concat(S.capture, " + ") or "PRESS BUTTON(S)…") or S.current,
        K.MARGIN + 22, 168, S.capturing and K.acc or K.C.text, 1, K.W - K.MARGIN * 2 - 44)
    K.text("body", "Default: START + SELECT (hold both together).", K.MARGIN + 22, 226, K.C.text)
    K.text("small", "You can also record 2–4 buttons together, for example L1 + R1.", K.MARGIN + 22, 257, K.C.dim, 1, K.W - K.MARGIN * 2 - 44)
    K.text("small", "The watcher listens to the physical button stream; it does not remap or consume game input.", K.MARGIN + 22, 282, K.C.dim, 1, K.W - K.MARGIN * 2 - 44)

    if S.capturing then
        K.footer({ { key = "PRESS", label = "Buttons to combine" }, { key = "WAIT 1s", label = "Auto-save" }, { key = "ESC", label = "Cancel" } })
    else
        K.footer({ { key = "A", label = "Record combination" }, { key = "Y", label = "Reset to M" }, { key = "B", label = "Back" } })
    end
end

return S
