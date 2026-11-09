-- Run with: luajit tests/test_stream_config_persistence.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

package.preload["core.stream_lib"] = function()
    return {
        parse_conf=function() return {} end,
        parse_stats=function() return {} end,
        parse_library=function() return {} end,
        serialize_conf=function(settings)
            local keys={}; for k in pairs(settings) do keys[#keys+1]=k end
            table.sort(keys)
            local out={}
            for _,k in ipairs(keys) do out[#out+1]=k.."="..tostring(settings[k]) end
            return table.concat(out,"\n")
        end,
        serialize_stats=function() return "" end,
    }
end
local old_open,old_rename=io.open,os.rename
local fail_rename=true
io.open=function(path,mode)
    if mode=="wb" then
        local f={data=""}
        function f:write(value) self.data=self.data..value; return self end
        function f:close() return true end
        return f
    end
    return nil
end
os.rename=function() return not fail_rename end

local Stream=require("core.stream")
Stream.s={HOST="old.local",SYNC_PORT="8765"}
local ok,err=Stream.set("HOST","new.local")
assert(ok==false and tostring(err):match("could not persist"))
assert(Stream.s.HOST=="old.local","failed write must roll back in-memory setting")
fail_rename=false
local saved,save_err=Stream.set("HOST","new.local")
assert(saved,save_err)
assert(Stream.s.HOST=="new.local","successful write should commit the setting")
local invalid,invalid_err=Stream.set("HOST","http://bad")
assert(invalid==false and tostring(invalid_err):match("characters not allowed"))
assert(Stream.s.HOST=="new.local","validation failure must not change the setting")
io.open,os.rename=old_open,old_rename
print("Stream config persistence: rollback checks passed")
