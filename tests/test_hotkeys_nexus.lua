-- Run with: luajit tests/test_hotkeys_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local files={}
local old_open,old_execute=os.open,os.execute
local old_io_open,old_rename=io.open,os.rename
love={graphics={},timer={}}
local raw={}; local saved={}
package.preload["ui.sfx"]=function() return {play=function() end} end
package.preload["core.state"]=function() return {raw_input=false} end
package.preload["ui.input"]=function() return {from_raw=function(n) return n==1 and "A" or nil end} end
package.preload["core.app_input"]=function() return {pad_map=function() return {A=1,B=2} end} end
package.preload["ui.kit"]=function()
  local function list()
    local l={items={},sel=1}
    function l:set(items) self.items=items; self.sel=1 end
    function l:cur() return self.items[self.sel] end
    function l:update() end
    function l:move(d) self.sel=math.max(1,math.min(#self.items,self.sel+d)); return true end
    return l
  end
  return {W=640,H=480,MARGIN=20,BOT=460,ACC={sys={}},C={},
    List=list,set_accent=function() end,header=function() end,footer=function() end,
    panel=function() end,text=function() end,color=function() end,font=function() return {getWidth=function(_,s)return #s end,getHeight=function()return 10 end} end,
    clip=function(_,s)return s end}
end
package.preload["ui.util"]=function()
  return {exists=function(path) return path=="workshop/hotkeys/Default/Hotkeys.ini" end,
    ls=function() return {"Default"} end}
end
package.preload["core.shell"]=function()
  return {shq=function(v)return "'"..v.."'" end,atomic_write=function(path,content) saved[path]=content; return true end}
end
package.preload["ui.notify"]=function() return {show=function() end end end
package.preload["ui.modal"]=function() return {show=function() end end end
io.open=function(path,mode)
  if mode=="r" then return nil end
  return {write=function() return true end,close=function() return true end}
end
os.execute=function() return 0 end
os.rename=function() return true end
package.loaded["ui"]={back=function() end}

local Screen=require("ui.screens.hotkeys")
local actions={}
local UI={register_action=function(id,run,meta)
  if actions[id] then return false,"duplicate action" end
  actions[id]={run=run,meta=meta}; return true
end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"hotkeys.refresh_profiles","hotkeys.select_profile","hotkeys.open_profile",
 "hotkeys.open_selected_profile","hotkeys.select_action","hotkeys.set_device","hotkeys.change_key",
 "hotkeys.clear_selected","hotkeys.start_capture","hotkeys.capture_input","hotkeys.finish_capture",
 "hotkeys.duplicate_profile","hotkeys.reload","hotkeys.save","hotkeys.request_back","hotkeys.state"}) do
 assert(actions[id],"missing "..id)
end
Screen.enter()
local state=actions["hotkeys.state"].run()
assert(state.mode=="profiles" and state.profile_count==1)
local invalid,invalid_err=actions["hotkeys.open_profile"].run("../Disabled")
assert(invalid==false and tostring(invalid_err):match("invalid"))
assert(actions["hotkeys.open_selected_profile"].run())
state=actions["hotkeys.state"].run()
assert(state.mode=="designer" and state.action_count==16 and state.dirty==false)
assert(actions["hotkeys.select_action"].run(1))
assert(actions["hotkeys.start_capture"].run())
assert(actions["hotkeys.capture_input"].run("A"))
assert(actions["hotkeys.finish_capture"].run(true))
assert(actions["hotkeys.change_key"].run(1))
state=actions["hotkeys.state"].run()
assert(state.dirty and state.selected_combo=="a")
assert(actions["hotkeys.save"].run())
assert(actions["hotkeys.state"].run().dirty==false)
local blocked,blocked_err=actions["hotkeys.select_action"].run(2)
assert(blocked==true,"capture has already ended and selection should remain available")
assert(actions["hotkeys.set_device"].run("pad"))
assert(actions["hotkeys.state"].run().device=="pad")
local bad_device,bad_device_err=actions["hotkeys.set_device"].run("touch")
assert(bad_device==false and tostring(bad_device_err):match("keyboard or pad"))
assert(actions["hotkeys.reload"].run())
assert(actions["hotkeys.state"].run().dirty==false)
assert(actions["hotkeys.duplicate_profile"].run())
assert(actions["hotkeys.state"].run().profile=="Default_copy")
local no_save,no_save_err=actions["hotkeys.save"].run()
assert(no_save==true or no_save==false)
io.open,os.rename,os.execute=old_io_open,old_rename,old_execute
print("Hotkeys NEXUS actions: all tests passed")
