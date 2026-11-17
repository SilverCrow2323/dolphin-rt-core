package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local MuOS = require("core.muos")

local function eq(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

eq(MuOS.profile_mode_id(), 2, "mode is read from muOS mode.conf")
eq(MuOS.profile_mode(), "All Tiers", "human-readable mode")

local ok, detail = MuOS.apply_profile_mode(1)
eq(ok, true, "switch to Standard Only")
eq(MuOS.profile_mode_id(), 1, "mode cache refreshes after apply")
eq(MuOS.profile_mode(), "Standard Only", "updated human-readable mode")
assert(type(detail) == "string" and detail:match("mode%-1%-applied"), "apply log is returned")

local invalid, reason = MuOS.apply_profile_mode(3)
eq(invalid, false, "invalid profile mode is rejected")
assert(tostring(reason):match("profile mode must be 1"), "invalid mode explains accepted values")
eq(MuOS.profile_mode_id(), 1, "invalid mode does not change state")

local ensured, ensure_detail = MuOS.ensure()
eq(ensured, true, "registration repair")
assert(type(ensure_detail) == "string" and ensure_detail:match("registration%-ensured"),
    "ensure log is returned")

print("muOS Rt:UI integration: all tests passed")
