-- Verify the muOS Andromeda raw-button contract used by the frontend.
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

package.preload["core.json"] = function()
    return { decode = function() return nil end, encode = function() return "{}" end }
end
local writes = {}
package.preload["core.fs"] = function()
    return {
        read = function() return nil end,
        mkdir_p = function() return true end,
        atomic_write = function(path, value) writes[path] = value; return true end,
    }
end

local AppInput = require("core.app_input")
AppInput.init()
local expected = {
    B=0, A=1, X=2, Y=3, L1=4, R1=5, SELECT=6, START=7,
    MENU=8, L2=9, L3=11, R2=12,
}
for logical, raw in pairs(expected) do
    assert(AppInput.pad_map()[logical] == raw,
        ("muOS Andromeda %s must be raw button %d"):format(logical, raw))
    assert(AppInput.from_raw(raw) == logical,
        ("raw button %d must resolve to %s"):format(raw, logical))
end
assert(AppInput.from_gamepad("leftstick") == "L3",
    "SDL leftstick must resolve to L3")
assert(AppInput.from_raw(10) == nil,
    "Volume Up must not be misidentified as a controller action")

local Input = require("ui.input")
assert(Input.from_raw(11) == "L3", "UI input bridge must preserve L3")
assert(Input.from_gamepad("leftstick") == "L3",
    "UI input bridge must preserve the SDL leftstick name")

assert(AppInput.set_pad("L3", 11))
assert(writes["data/app_input.json"], "L3 remap must persist")
assert(not AppInput.set_pad("UNKNOWN", 99), "unknown logical keys must be rejected")
AppInput.reset_pad()
assert(AppInput.pad_map().L3 == 11, "reset must restore Andromeda L3 index")

print("muOS Andromeda app input map: all tests passed")
