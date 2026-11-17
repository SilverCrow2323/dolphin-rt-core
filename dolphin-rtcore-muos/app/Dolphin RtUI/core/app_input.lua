-- core/app_input.lua — App-level input remapping.
--
-- Due layer:
--   1. Keyboard:    delegato a core.key_bindings (key -> action)
--   2. App Pad:     logical -> SDL button index, per questo modulo
--
-- Storage: data/app_input.json
--   {
--     "active_device": null,          -- GUID o nome, null = primo connesso
--     "pad": { "A": 1, "B": 0, ... }  -- logical -> zero-based SDL button ID
--   }
--
-- I default riflettono ui/input.lua originale.

local JSON = require("core.json")
local FS   = require("core.fs")

local M = {}
local PATH = "data/app_input.json"

-- Numeric values are the zero-based SDL button IDs consumed by
-- love.joystickpressed and written to Dolphin profiles as `Button n`.
-- They are NOT Linux EV_KEY codes or /dev/input/jsN joydev button indices.
-- The standardized love.gamepadpressed path uses the names in GAMEPAD_TO_LOGICAL.
M.ACTIONS = {
    { id = "A",      label = "Confirm",       default = 1  },
    { id = "B",      label = "Back",          default = 0  },
    { id = "X",      label = "Action X",      default = 2  },
    { id = "Y",      label = "Action Y",      default = 3  },
    { id = "L1",     label = "Page Left",     default = 4  },
    { id = "R1",     label = "Page Right",    default = 5  },
    { id = "L2",     label = "L2",            default = 9  },
    { id = "R2",     label = "R2",            default = 12 },
    { id = "SELECT", label = "Select",        default = 6  },
    { id = "START",  label = "Start",         default = 7  },
    { id = "MENU",   label = "Menu",          default = 8  },
    { id = "L3",     label = "Left Stick Click", default = 11 },
    { id = "R3",     label = "Right Stick Click", default = nil },
    { id = "UP",     label = "D-Pad Up",      default = nil },
    { id = "DOWN",   label = "D-Pad Down",    default = nil },
    { id = "LEFT",   label = "D-Pad Left",    default = nil },
    { id = "RIGHT",  label = "D-Pad Right",   default = nil },
}

M.data = nil

local function defaults()
    local p = {}
    for _, a in ipairs(M.ACTIONS) do p[a.id] = a.default end
    return { active_device = nil, pad = p }
end

function M.init()
    M.data = defaults()
    local changed = false
    local raw = FS.read(PATH)
    if raw then
        local ok, d = pcall(JSON.decode, raw)
        if ok and type(d) == "table" then
            if type(d.pad) == "table" then
                -- Migrate only the complete known-bad joydev-as-SDL signature.
                -- Partial/custom mappings are ambiguous and must remain untouched.
                local mistaken_joydev = {
                    A = 0, B = 1, X = 2, Y = 3, L1 = 4, R1 = 5,
                    L2 = 6, R2 = 7, SELECT = 8, START = 9, MENU = 10, L3 = 11,
                }
                local signature = {
                    "A", "B", "X", "Y", "L1", "R1",
                    "L2", "R2", "SELECT", "START", "MENU", "L3",
                }
                local mistaken = true
                for _, logical in ipairs(signature) do
                    if d.pad[logical] ~= mistaken_joydev[logical] then
                        mistaken = false
                        break
                    end
                end
                -- R3 was added after the original App Pad schema. When present,
                -- accept only the known bad default; otherwise preserve it as a
                -- custom remap and do not rewrite the user's configuration.
                if mistaken and d.pad.R3 ~= nil and d.pad.R3 ~= 12 then
                    mistaken = false
                end
                -- A matching legacy core mapping is not enough if the user has
                -- additional persisted controls. Migrate only the exact known
                -- signature; never discard custom D-pad or extension mappings.
                if mistaken then
                    local allowed = {}
                    for _, logical in ipairs(signature) do
                        allowed[logical] = true
                    end
                    if d.pad.R3 == 12 then allowed.R3 = true end
                    for logical in pairs(d.pad) do
                        if not allowed[logical] then
                            mistaken = false
                            break
                        end
                    end
                end
                if mistaken then
                    changed = true
                else
                    for k, v in pairs(d.pad) do
                        M.data.pad[k] = v
                    end
                end
            end
            if d.active_device ~= nil then
                M.data.active_device = d.active_device
            end
        end
    end
    if changed then M.save() end
end

function M.save()
    FS.mkdir_p("data")
    FS.atomic_write(PATH, JSON.encode(M.data))
end

function M.pad_map() return M.data.pad end

function M.set_pad(logical, raw_index)
    local exists = false
    for _, a in ipairs(M.ACTIONS) do
        if a.id == logical then exists = true; break end
    end
    if not exists then return false end
    -- Un raw_index può essere assegnato a una sola azione: se già in uso, sgancia l'altra
    for k, v in pairs(M.data.pad) do
        if k ~= logical and v == raw_index then
            M.data.pad[k] = nil
        end
    end
    M.data.pad[logical] = raw_index
    M.save()
    return true
end

function M.reset_pad()
    M.data.pad = defaults().pad
    M.save()
end

-- SDL GameController string names (love.gamepadpressed button param).
-- User remap: if a value in data.pad is a string, it overrides the default.
M.GAMEPAD_TO_LOGICAL = {
    a = "A", b = "B", x = "X", y = "Y",
    leftstick = "L3", rightstick = "R3",
    start = "START", back = "SELECT", guide = "MENU",
    leftshoulder = "L1", rightshoulder = "R1",
    lefttrigger = "L2", righttrigger = "R2",
    dpup = "UP", dpdown = "DOWN", dpleft = "LEFT", dpright = "RIGHT",
}

function M.from_gamepad(name)
    if type(name) ~= "string" then return nil end
    local pad = (M.data and M.data.pad) or {}
    for logical, v in pairs(pad) do
        if type(v) == "string" and v == name then return logical end
    end
    return M.GAMEPAD_TO_LOGICAL[name]
end

M.GAMEPAD_AXIS_TO_LOGICAL = {
    lefttrigger = "L2", righttrigger = "R2",
    triggerleft = "L2", triggerright = "R2",
}

function M.from_gamepad_axis(axis)
    return M.GAMEPAD_AXIS_TO_LOGICAL[axis]
end

function M.active_device() return M.data.active_device end

function M.set_active_device(guid)
    M.data.active_device = guid
    M.save()
end

-- Traduce un raw SDL button index in logical, o nil se non mappato.
-- Se logical è già passato (es. da dpad hat), restituisce quello.
function M.from_raw(raw_index)
    if type(raw_index) ~= "number" then return nil end
    for logical, idx in pairs(M.data.pad) do
        if idx == raw_index then return logical end
    end
    return nil
end

return M