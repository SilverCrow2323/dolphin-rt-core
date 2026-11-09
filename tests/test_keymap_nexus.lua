-- Run with: luajit tests/test_keymap_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local values, writes, fail_write = {}, 0, false
love={graphics={newImage=function() return nil end},timer={}}
package.preload["ui.kit"]=function()
 local function list()
  local l={items={},sel=1}
  function l:set(items) self.items=items; self.sel=1 end
  function l:cur() return self.items[self.sel] end
  function l:update() end
  function l:move(d) self.sel=math.max(1,math.min(#self.items,self.sel+d));return true end
  return l
 end
 return {W=640,H=480,MARGIN=20,BOT=460,ACC={gc={},wii={}},C={},
  List=list,set_accent=function() end}
end
package.preload["ui.sfx"]=function() return {play=function() end} end
package.preload["ui.util"]=function() return {} end
package.preload["ui.notify"]=function() return {show=function() end} end
package.preload["ui.modal"]=function() return {show=function() end} end
package.preload["core.ini_edit"]=function()
 return {read_lines=function() return {"[GCPad1]","Buttons/A = Button 1"} end,
  get=function(lines,section,key) return values[key] or "Button 1" end,
  set=function(lines,section,key,value) values[key]=value end,
  write_lines=function() writes=writes+1; return not fail_write end}
end
package.loaded["ui"]={back=function() end}
local Screen=require("ui.screens.keymap")
local actions={}
local UI={register_action=function(id,run,meta)
 if actions[id] then return false,"duplicate action" end
 actions[id]={run=run,meta=meta};return true
end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"keymap.switch_system","keymap.select","keymap.start_remap","keymap.capture_input",
 "keymap.confirm_remap","keymap.cancel_remap","keymap.state"}) do assert(actions[id],"missing "..id) end
Screen.enter({system="GameCube",profile="Default"})
local state=actions["keymap.state"].run()
assert(state.system=="GameCube" and state.mapping_count>0)
assert(actions["keymap.start_remap"].run())
assert(actions["keymap.capture_input"].run(7))
state=actions["keymap.state"].run()
assert(state.remap_phase=="confirm" and state.proposed_value:match("Button 7"))
fail_write=true
local failed,failed_err=actions["keymap.confirm_remap"].run()
assert(failed==false and tostring(failed_err):match("write failed"))
assert(actions["keymap.state"].run().remap_phase=="confirm","failed write must preserve confirmation state")
fail_write=false
assert(actions["keymap.confirm_remap"].run())
assert(writes==2 and actions["keymap.state"].run().remap_phase==nil)
assert(actions["keymap.switch_system"].run())
assert(actions["keymap.state"].run().system=="Wii")
assert(actions["keymap.start_remap"].run())
assert(actions["keymap.cancel_remap"].run())
local invalid,invalid_err=actions["keymap.capture_input"].run(7)
assert(invalid==false and tostring(invalid_err):match("not waiting"))
print("Keymap NEXUS actions: all tests passed")
