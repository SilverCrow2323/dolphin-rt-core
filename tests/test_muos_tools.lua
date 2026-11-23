-- Run with: luajit tests/test_muos_tools.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path
local commands = {}
local old_open, old_execute = io.open, os.execute
package.preload["core.sh"] = function() return { shq = function(s) return "'" .. s:gsub("'", "'\\''") .. "'" end } end
io.open = function(path, mode)
    if path == "/opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh" then return { close = function() end } end
    if path == "data/logs/muos-manifest.log" then return { read = function() return "OK applied" end, close = function() end } end
    return old_open(path, mode)
end
os.execute = function(command) commands[#commands + 1] = command; return true end
local Tools = require("core.muos_tools")
local ok, output = Tools.apply(1)
assert(ok and output == "OK applied", "mode 1 should apply successfully")
assert(commands[#commands]:find("apply 1", 1, true), "mode 1 command")
ok = Tools.apply(2)
assert(ok and commands[#commands]:find("apply 2", 1, true), "mode 2 command")
ok = Tools.apply()
assert(ok and commands[#commands]:match("apply"), "default registration command")
local before = #commands
local bad, err = Tools.apply(3)
assert(not bad and err == "invalid catalogue mode", "invalid mode must be rejected")
assert(#commands == before, "invalid mode must not execute a command")
io.open, os.execute = old_open, old_execute
print("muOS UI tools tests: OK")
