-- Run with: luajit tests/test_cheats_screen_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local entries={
 {slug="boost-a",name="Boost A",group="perf",pclass="video",enabled=false,codes={"A"},notes={}},
 {slug="fps-a",name="FPS A",group="fps",enabled=false,codes={"B"},notes={}},
 {slug="cheat-a",name="Cheat A",group="cheat",enabled=false,codes={"C"},notes={}},
}
local applied=0
love={graphics={},timer={}}
package.preload["ui.kit"]=function()
 local function list()
  local l={items={},sel=1,y=180}
  function l:set(items) self.items=items; self.sel=1 end
  function l:cur() return self.items[self.sel] end
  function l:update() end
  function l:move(d) self.sel=math.max(1,math.min(#self.items,self.sel+d)); return true end
  function l:_aim() end
  return l
 end
 return {W=640,H=480,MARGIN=20,BOT=460,ACC={boost={},wii={},hot={}},C={},
  List=list,set_accent=function() end}
end
package.preload["ui.sfx"]=function() return {play=function() end} end
package.preload["ui.notify"]=function() return {show=function() end} end
package.preload["core.rtcheats"]=function()
 return {PCLASS_LABEL={video="Video"},load_for=function() return entries end,
  missing=function() return {} end,sync=function() return true end,
  sync_status=function() return {state="idle"} end,reload=function() end,
  in_index=function() return true end,
  set_enabled=function(_,slug,on)
   for _,e in ipairs(entries) do if e.slug==slug then e.enabled=on; return true end end
   return false
  end,
  set_many=function(_,batch)
   for _,b in ipairs(batch) do for _,e in ipairs(entries) do if e.slug==b.slug then e.enabled=b.on end end end
   return true
  end,
  apply=function() applied=applied+1; return true,2 end}
end
package.loaded["ui"]={back=function() end}
local Screen=require("ui.screens.cheats")
local actions={}
local UI={register_action=function(id,run,meta)
 if actions[id] then return false,"duplicate action" end
 actions[id]={run=run,meta=meta}; return true
end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"cheats.refresh","cheats.switch_tab","cheats.select","cheats.toggle_selected",
 "cheats.bulk_toggle","cheats.apply","cheats.state"}) do assert(actions[id],"missing "..id) end
Screen.enter({game_id="GAME-1",title="Test Game"})
local state=actions["cheats.state"].run()
assert(state.game_id=="GAME-1" and state.title=="Test Game" and state.boost_count==1)
assert(actions["cheats.select"].run(2)==false,"category headers must not be selectable")
assert(actions["cheats.toggle_selected"].run()==false,"header row must not toggle")
assert(actions["cheats.switch_tab"].run("fps"))
assert(actions["cheats.select"].run(1))
assert(actions["cheats.toggle_selected"].run())
state=actions["cheats.state"].run()
assert(state.selected_slug=="fps-a" and state.selected_enabled and state.changed)
assert(actions["cheats.apply"].run())
assert(applied==1 and actions["cheats.state"].run().changed==false)
assert(actions["cheats.switch_tab"].run("boost"))
assert(actions["cheats.bulk_toggle"].run())
assert(actions["cheats.state"].run().boost_enabled==1)
local bad,bad_err=actions["cheats.switch_tab"].run("unknown")
assert(bad==false and tostring(bad_err):match("boost, fps, cheats"))
assert(actions["cheats.refresh"].run())
print("Per-game Cheats NEXUS actions: all tests passed")
