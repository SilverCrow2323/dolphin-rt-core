#!/usr/bin/env luajit
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;dolphin-rtcore-muos/app/Dolphin RtUI/?/init.lua;" .. package.path

local Merger = require("core.profile_merger")
local tmp = os.tmpname()
os.remove(tmp)
os.execute("mkdir -p " .. string.format("%q", tmp))

local function write(path, content)
    local parent = path:match("^(.*)/[^/]+$")
    os.execute("mkdir -p " .. string.format("%q", parent))
    local f = assert(io.open(path, "w"))
    f:write(content)
    f:close()
end

local function expect(ok, message)
    if not ok then error(message or "assertion failed", 2) end
end

local root = tmp .. "/workshop"
write(root .. "/rtcoreprofile/Default/Dolphin.ini", [[
[Core]
CPUCore = 4
Overclock = 0.8
]])
write(root .. "/rtcoreprofile/Default/GFX.ini", [[
[Settings]
DisableFog = True
]])
write(root .. "/rtcoreprofile/RtPrime/rtprofile_data.ini", [[
[Profile]
Name = RtPrime
]])
write(root .. "/rtcoreprofile/RtPrime/Dolphin.ini", [[
[Core]
Overclock = 1.0
]])
write(root .. "/rtcoreprofile/RtPrime/std/rtprofile_data.ini", [[
[Profile]
Name = RtPrime Std
]])
write(root .. "/rtcoreprofile/RtPrime/std/Dolphin.ini", [[
[Core]
Overclock = 1.1
CPUThread = False
]])
write(root .. "/base/Dolphin.ini", [[
[Core]
CPUCore = 99
]])

local chain = Merger.resolve_chain("rtcoreprofile", "RtPrime/std", root)
expect(#chain == 2 and chain[1] == "RtPrime" and chain[2] == "RtPrime/std",
    "tier must inherit its family before its own patch")

local merged = Merger.merge_chain("rtcoreprofile", "RtPrime/std", "Dolphin.ini", root)
expect(merged ~= nil, "RtCore profile should merge against its canonical Default base")
expect(merged.data.Core.CPUCore == "4", "RtCore must not read duplicate workshop/base Dolphin.ini")
expect(merged.data.Core.Overclock == "1.1", "tier must override family values")
expect(merged.data.Core.CPUThread == "False", "tier-specific values must survive")

local default_chain = Merger.resolve_chain("rtcoreprofile", "Default", root)
expect(#default_chain == 0, "Default is the immutable base, not a second overlay")
local default = Merger.merge_chain("rtcoreprofile", "Default", "Dolphin.ini", root)
expect(default.data.Core.CPUCore == "4" and default.data.Core.Overclock == "0.8",
    "Default profile should resolve to its own canonical files")

-- Other workshop families still use workshop/base as their shared baseline.
write(root .. "/base/GCPadNew.ini", [[
[GCPad1]
Device = BasePad
]])
write(root .. "/controller/Default/GCPadNew.ini", [[
[GCPad1]
Device = WorkshopPad
]])
local controller = Merger.merge_chain("controller", "Default", "GCPadNew.ini", root)
expect(controller.data.GCPad1.Device == "WorkshopPad",
    "controller profiles must keep their shared workshop/base fallback")

os.execute("rm -rf " .. string.format("%q", tmp))
print("Shared profile merger tests: OK")
