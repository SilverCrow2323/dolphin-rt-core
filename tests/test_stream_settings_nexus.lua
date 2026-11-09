-- Run with: luajit tests/test_stream_settings_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local stream={HOST="",SYNC_PORT="8765",MAC="",WIDTH="1280",HEIGHT="720",FPS="60",
    BITRATE="15000",CODEC="auto",REMOTE="auto",SOPS="yes"}
local set_calls, jobs, killed = {}, {}, 0
love={graphics={},timer={}}
local old_remove=os.remove
os.remove=function() return true end
package.preload["ui.kit"] = function()
    return {W=640,H=480,MARGIN=20,BOT=460,ACC={wii={},boost={}},C={},
        List=function()
            local l={items={},sel=1}
            function l:set(items) self.items=items; self.sel=1 end
            function l:cur() return self.items[self.sel] end
            function l:update() end
            function l:_aim() end
            function l:move(d) self.sel=math.max(1,math.min(#self.items,self.sel+d)); return true end
            return l
        end,set_accent=function() end}
end
package.preload["ui.sfx"] = function() return {play=function() end} end
package.preload["ui.notify"] = function() return {show=function() end} end
package.preload["core.stream"] = function()
    return {
        DIR="/tmp/stream-settings-test",s=stream,
        init=function() end,configured=function() return stream.HOST~="" end,
        set=function(key,value) stream[key]=value; set_calls[#set_calls+1]={key,value}; return true end,
        run_job=function(script) jobs[#jobs+1]=script end,
        read=function() return nil end,job_done=function() return false end,
        kill_pair=function() killed=killed+1 end,
    }
end
package.loaded["ui"]={back=function() end}

local Screen=require("ui.screens.stream_settings")
local actions={}
local UI={register_action=function(id,run,meta)
    if actions[id] then return false,"duplicate action" end
    actions[id]={run=run,meta=meta}; return true
end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"stream_settings.select","stream_settings.change_selected","stream_settings.set_text",
    "stream_settings.open_text_editor","stream_settings.run_selected","stream_settings.cancel_mode",
    "stream_settings.state"}) do assert(actions[id],"missing "..id) end

Screen.enter()
local state=actions["stream_settings.state"].run()
assert(state.mode=="list" and state.configured==false and state.host_is_set==false)
local bad_host,bad_host_err=actions["stream_settings.set_text"].run("HOST","http://pc.local")
assert(bad_host==false and tostring(bad_host_err):match("invalid PC address"))
local good_host,host_err=actions["stream_settings.set_text"].run("HOST"," pc.local ")
assert(good_host,host_err and tostring(host_err))
assert(stream.HOST=="pc.local" and actions["stream_settings.state"].run().configured)
local bad_port,bad_port_err=actions["stream_settings.set_text"].run("SYNC_PORT","70000")
assert(bad_port==false and tostring(bad_port_err):match("65535"))
assert(actions["stream_settings.set_text"].run("SYNC_PORT","8888"))
assert(actions["stream_settings.set_text"].run("MAC","AA:BB:CC:DD:EE:FF"))
local bad_mac,bad_mac_err=actions["stream_settings.set_text"].run("MAC","xyz")
assert(bad_mac==false and tostring(bad_mac_err):match("12 hexadecimal"))
local secret=actions["stream_settings.state"].run()
assert(secret.host_is_set and secret.host==nil and secret.mac==nil and secret.token==nil,
    "state must not leak connection identifiers or secrets")

assert(actions["stream_settings.select"].run(5))
assert(actions["stream_settings.change_selected"].run(1))
assert(stream.FPS=="30" or stream.FPS=="45" or stream.FPS=="60")
assert(actions["stream_settings.select"].run(1))
assert(actions["stream_settings.open_text_editor"].run())
state=actions["stream_settings.state"].run()
assert(state.mode=="osk" and state.osk_label=="PC address")
assert(actions["stream_settings.cancel_mode"].run())
assert(actions["stream_settings.select"].run(12))
assert(actions["stream_settings.run_selected"].run())
state=actions["stream_settings.state"].run()
assert(state.mode=="viewer" and state.viewer_title=="Test connection" and jobs[1]=="test.sh")
assert(actions["stream_settings.cancel_mode"].run())
local invalid,invalid_err=actions["stream_settings.set_text"].run("TOKEN","secret")
assert(invalid==false and tostring(invalid_err):match("only HOST"))
local no_cancel,no_cancel_err=actions["stream_settings.cancel_mode"].run()
assert(no_cancel==false and tostring(no_cancel_err):match("already active"))
os.remove=old_remove
print("Stream Settings NEXUS actions: all tests passed")
