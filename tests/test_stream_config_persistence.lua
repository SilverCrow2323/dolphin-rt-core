-- Run with: luajit tests/test_stream_config_persistence.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

package.preload["core.stream_lib"] = function()
    return {
        parse_conf = function() return {} end,
        parse_stats = function() return {} end,
        parse_library = function() return {} end,
        serialize_conf = function(settings)
            local keys = {}
            for key in pairs(settings) do keys[#keys + 1] = key end
            table.sort(keys)
            local out = {}
            for _, key in ipairs(keys) do out[#out + 1] = key .. "=" .. tostring(settings[key]) end
            return table.concat(out, "\n")
        end,
        serialize_stats = function() return "" end,
    }
end

local old_open, old_rename = io.open, os.rename
local fail_rename = true
io.open = function(_, mode)
    if mode == "wb" then
        local file = { data = "" }
        function file:write(value) self.data = self.data .. value; return self end
        function file:close() return true end
        return file
    end
    return nil
end
os.rename = function() return not fail_rename end

local Stream = require("core.stream")
Stream.s = {
    HOST = "old.local", SYNC_PORT = "8765", WIDTH = "640", HEIGHT = "480",
}

local ok, err = Stream.set("HOST", "new.local")
assert(ok == false and tostring(err):match("could not persist"))
assert(Stream.s.HOST == "old.local", "failed single-setting write must roll back")

local batch_ok, batch_err = Stream.set_many({ WIDTH = "1280", HEIGHT = "720", NEW_FIELD = "value" })
assert(batch_ok == false and tostring(batch_err):match("could not persist"))
assert(Stream.s.WIDTH == "640" and Stream.s.HEIGHT == "480", "failed batch write must roll back all fields")
assert(Stream.s.NEW_FIELD == nil, "failed batch write must remove keys that did not exist before")

fail_rename = false
local saved, save_err = Stream.set("HOST", "new.local")
assert(saved, save_err)
assert(Stream.s.HOST == "new.local", "successful single-setting write should commit")

local batch_saved, batch_save_err = Stream.set_many({ WIDTH = "1280", HEIGHT = "720" })
assert(batch_saved, batch_save_err)
assert(Stream.s.WIDTH == "1280" and Stream.s.HEIGHT == "720", "successful batch write should commit both fields")

local invalid, invalid_err = Stream.set("HOST", "http://bad")
assert(invalid == false and tostring(invalid_err):match("characters not allowed"))
assert(Stream.s.HOST == "new.local", "validation failure must not change the setting")

io.open, os.rename = old_open, old_rename
print("Stream config persistence: rollback checks passed")
