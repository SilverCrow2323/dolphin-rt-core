-- Run with: luajit tests/test_diagnostics_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local setting_values={log_level="info",log_retention_days=7,log_max_kb=512,log_auto_clear=true}
local modal,deleted= nil,0
love={graphics={},timer={}}
local old_popen,old_execute=io.popen,os.execute
io.popen=function(command)
  local h={closed=false}
  function h:read() return "0\n" end
  function h:lines() return function() return nil end end
  function h:close() self.closed=true end
  return h
end
os.execute=function() deleted=deleted+1; return 0 end
package.preload["ui.kit"]=function()
  local function list()
    local l={items={},sel=1}
    function l:set(items) self.items=items; self.sel=1 end
    function l:cur() return self.items[self.sel] end
    function l:update() end
    function l:move(d) self.sel=math.max(1,math.min(#self.items,self.sel+d)); return true end
    return l
  end
  return {W=640,H=480,MARGIN=20,BOT=460,ACC={gc={},wii={},boost={}},C={bad={},text={},dim={},faint={},line={},ok={}},
    List=list,set_accent=function() end,color=function() end,text=function() end,width=function() return 0 end,
    panel=function() end,draw_tool_icon=function() end,bg_workshop=function() end,footer=function() end}
end
package.preload["ui.sfx"]=function() return {play=function() end end end
package.preload["ui.notify"]=function() return {show=function() end end end
package.preload["ui.modal"]=function() return {show=function(title,body,opts) modal={title=title,body=body,opts=opts} end} end
package.preload["core.settings"]=function()
  return {get=function(k) return setting_values[k] end,set=function(k,v) setting_values[k]=v end}
end
package.preload["core.sh"]=function() return {shq=function(v) return "'"..v.."'" end} end

local Screen=require("ui.screens.diagnostics")
local actions={}
local UI={register_action=function(id,run,meta)
  if actions[id] then return false,"duplicate action" end
  actions[id]={run=run,meta=meta}; return true
end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"diagnostics.refresh","diagnostics.select_category","diagnostics.open_selected",
 "diagnostics.scroll_viewer","diagnostics.close_viewer","diagnostics.request_clear_selected",
 "diagnostics.request_clear_all","diagnostics.switch_mode","diagnostics.select_setting",
 "diagnostics.change_setting","diagnostics.state"}) do assert(actions[id],"missing "..id) end
Screen.enter()
local state=actions["diagnostics.state"].run()
assert(state.mode=="list" and state.category_count==4 and state.setting_count==4)
assert(actions["diagnostics.select_category"].run(2))
assert(actions["diagnostics.request_clear_selected"].run())
assert(modal and modal.title=="Clear Dolphin Log?" and deleted==0,"cleanup must require confirmation")
modal.opts.on_accept()
assert(deleted==1,"confirmed cleanup should execute")
assert(actions["diagnostics.switch_mode"].run("settings"))
assert(actions["diagnostics.select_setting"].run(1))
assert(actions["diagnostics.change_setting"].run(1))
assert(setting_values.log_level=="verbose")
local invalid,invalid_err=actions["diagnostics.switch_mode"].run("danger")
assert(invalid==false and tostring(invalid_err):match("list or settings"))
assert(actions["diagnostics.request_clear_all"].run())
assert(modal and modal.title=="Clear all logs?" and deleted==1)
modal.opts.on_accept()
assert(deleted==2,"all-log cleanup should run only after confirmation")
local no_view,no_view_err=actions["diagnostics.scroll_viewer"].run(1)
assert(no_view==false and tostring(no_view_err):match("not open"))
io.popen,os.execute=old_popen,old_execute
print("Diagnostics NEXUS actions: all tests passed")
