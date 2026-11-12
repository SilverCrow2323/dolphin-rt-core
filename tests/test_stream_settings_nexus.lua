-- Run with: luajit tests/test_stream_settings_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local stream = {
    HOST = "", SYNC_PORT = "8765", MAC = "", WIDTH = "1280", HEIGHT = "720",
    FPS = "60", BITRATE = "15000", CODEC = "auto", REMOTE = "auto", SOPS = "yes",
}
local set_calls, jobs, killed = {}, {}, 0
local fail_set = false

love = { graphics = {}, timer = {} }
local old_remove = os.remove
os.remove = function() return true end

package.preload["ui.kit"] = function()
    return {
        W = 640, H = 480, MARGIN = 20, BOT = 460, ACC = { wii = {}, boost = {} }, C = {},
        List = function()
            local list = { items = {}, sel = 1 }
            function list:set(items) self.items = items; self.sel = 1 end
            function list:cur() return self.items[self.sel] end
            function list:update() end
            function list:_aim() end
            function list:move(direction)
                self.sel = math.max(1, math.min(#self.items, self.sel + direction))
                return true
            end
            return list
        end,
        set_accent = function() end,
    }
end
package.preload["ui.sfx"] = function() return { play = function() end } end
package.preload["ui.notify"] = function() return { show = function() end } end
package.preload["core.stream"] = function()
    return {
        DIR = "/tmp/stream-settings-test",
        s = stream,
        init = function() end,
        configured = function() return stream.HOST ~= "" end,
        set = function(key, value)
            if fail_set then return false, "disk full" end
            stream[key] = tostring(value)
            set_calls[#set_calls + 1] = { key, value }
            return true
        end,
        set_many = function(values)
            if fail_set then return false, "disk full" end
            for key, value in pairs(values) do stream[key] = tostring(value) end
            return true
        end,
        run_job = function(script) jobs[#jobs + 1] = script end,
        read = function() return nil end,
        job_done = function() return false end,
        kill_pair = function() killed = killed + 1 end,
    }
end
package.loaded["ui"] = { back = function() end }

local Screen = require("ui.screens.stream_settings")
local actions = {}
local UI = {
    register_action = function(id, run, metadata)
        if actions[id] then return false, "duplicate action" end
        actions[id] = { run = run, metadata = metadata }
        return true
    end,
}
local registered, register_err = Screen.register_actions(UI)
assert(registered, register_err)
for _, id in ipairs({
    "stream_settings.select",
    "stream_settings.change_selected",
    "stream_settings.set_text",
    "stream_settings.open_text_editor",
    "stream_settings.run_selected",
    "stream_settings.cancel_mode",
    "stream_settings.discover_hosts",
    "stream_settings.pair",
    "stream_settings.select_discovered_host",
    "stream_settings.connection_status",
    "stream_settings.state",
}) do
    assert(actions[id], "missing action " .. id)
end

Screen.enter()
local state = actions["stream_settings.state"].run()
assert(state.mode == "list" and not state.configured and not state.host_is_set)

local bad_host, bad_host_err = actions["stream_settings.set_text"].run("HOST", "http://pc.local")
assert(bad_host == false and tostring(bad_host_err):match("invalid PC address"))
local good_host, host_err = actions["stream_settings.set_text"].run("HOST", " pc.local ")
assert(good_host, host_err)
assert(stream.HOST == "pc.local" and actions["stream_settings.state"].run().configured)

local bad_port, bad_port_err = actions["stream_settings.set_text"].run("SYNC_PORT", "70000")
assert(bad_port == false and tostring(bad_port_err):match("65535"))
assert(actions["stream_settings.set_text"].run("SYNC_PORT", "8888"))
assert(actions["stream_settings.set_text"].run("MAC", "AA:BB:CC:DD:EE:FF"))
local bad_mac, bad_mac_err = actions["stream_settings.set_text"].run("MAC", "xyz")
assert(bad_mac == false and tostring(bad_mac_err):match("12 hexadecimal"))

local secret = actions["stream_settings.state"].run()
assert(secret.host_is_set and secret.host == nil and secret.mac == nil and secret.token == nil)
assert(secret.sync_port == nil, "state must not expose the configured port")

local invalid_key, invalid_key_err = actions["stream_settings.set_text"].run("TOKEN", "secret")
assert(invalid_key == false and tostring(invalid_key_err):match("only HOST"))

assert(actions["stream_settings.select"].run(5))
fail_set = true
local failed_change, failed_change_err = actions["stream_settings.change_selected"].run(1)
assert(failed_change == false and tostring(failed_change_err):match("disk full"))
assert(stream.WIDTH == "1280" and stream.HEIGHT == "720", "failed resolution update must not mutate state")
fail_set = false
assert(actions["stream_settings.change_selected"].run(1))
assert(stream.WIDTH == "640" and stream.HEIGHT == "480", "resolution update must be committed atomically")

assert(actions["stream_settings.select"].run(6))
assert(actions["stream_settings.change_selected"].run(1))
assert(stream.FPS == "30", "frame-rate action must cycle to next value")

assert(actions["stream_settings.select"].run(2))
assert(actions["stream_settings.open_text_editor"].run())
state = actions["stream_settings.state"].run()
assert(state.mode == "osk" and state.osk_label == "PC address")
assert(actions["stream_settings.cancel_mode"].run())

assert(actions["stream_settings.select"].run(13))
assert(actions["stream_settings.run_selected"].run())
state = actions["stream_settings.state"].run()
assert(state.mode == "viewer" and state.viewer_title == "Connection test" and jobs[1] == "test.sh")
assert(actions["stream_settings.cancel_mode"].run())

local no_cancel, no_cancel_err = actions["stream_settings.cancel_mode"].run()
assert(no_cancel == false and tostring(no_cancel_err):match("already active"))
assert(actions["stream_settings.select"].run(999) == false, "out-of-range selection must be rejected")
assert(killed == 0, "non-pair connection test must not kill pairing process")

os.remove = old_remove
print("Stream Settings NEXUS actions: all tests passed")
