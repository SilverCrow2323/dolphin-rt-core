-- Run with: luajit tests/test_game_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local card, launched, navigation = {}, 0, nil
local modal
love={graphics={newImage=function() return nil end},timer={}}
package.preload["ui.kit"]=function()
 local function list()
  local l={items={},sel=1}
  function l:set(items) self.items=items; self.sel=1 end
  function l:cur() return self.items[self.sel] end
  function l:update() end
  function l:move(d) self.sel=math.max(1,math.min(#self.items,self.sel+d)); return true end
  return l
 end
 return {W=640,H=480,MARGIN=20,BOT=460,ACC={gc={},wii={},boost={},teal={},hot={},mods={}},C={warn={}},
  List=list,set_accent=function() end}
end
package.preload["ui.sfx"]=function() return {play=function() end} end
package.preload["ui.util"]=function()
 return {card_get=function(_,_,k)return card[k] end,card_set=function(_,_,k,v)card[k]=v end,
  ls=function(path) if path:match("hotkeys") then return {"Default"} end; return {"Default","ProfileA"} end,
  is_wii=function()return false end,is_family=function()return false end,yes=function(v)return v=="yes" end,
  memo=function(_,_,fn)return fn() end,mods_save=function()end,vault_set_off=function()end,
  launch=function()launched=launched+1;return true end}
end
package.preload["ui.notify"]=function() return {show=function() end} end
package.preload["ui.modal"]=function() return {show=function(title,body,opts)modal={title=title,opts=opts}end} end
package.preload["core.rtcheats"]=function() return {load_for=function()return{}end} end
package.preload["core.mods"]=function() return {CATS={}} end
package.loaded["ui"]={go=function(target,params)navigation={target,params};return true end}
local Screen=require("ui.screens.game")
local actions={}
local UI={register_action=function(id,run,meta)
 if actions[id] then return false,"duplicate action" end
 actions[id]={run=run,meta=meta};return true
end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"game.launch","game.select_row","game.change_selected","game.set_choice",
 "game.set_overlay","game.run_selected","game.open_editor","game.request_reset","game.state"}) do
 assert(actions[id],"missing "..id)
end
Screen.enter({game={id="GAME-1",title="Test Game"}})
local state=actions["game.state"].run()
assert(state.game_id=="GAME-1" and state.title=="Test Game" and #state.rows>0)
local invalid,invalid_err=actions["game.select_row"].run(2)
assert(invalid==false and tostring(invalid_err):match("section header"))
assert(actions["game.set_choice"].run("Profile","ProfileA"))
assert(card.RtProfile=="ProfileA")
local bad_choice,bad_choice_err=actions["game.set_choice"].run("Profile","../../bad")
assert(bad_choice==false and tostring(bad_choice_err):match("not available"))
assert(actions["game.set_overlay"].run("OverlayFPS",true))
assert(card.OverlayFPS=="yes")
assert(actions["game.launch"].run() and launched==1)
state=actions["game.state"].run()
local hotkey_index
for _,row in ipairs(state.rows) do if row.label=="Hotkeys" then hotkey_index=row.index end end
assert(hotkey_index and actions["game.select_row"].run(hotkey_index))
assert(actions["game.open_editor"].run())
assert(navigation and navigation[1]=="hotkeys")
assert(actions["game.request_reset"].run())
assert(modal and modal.title=="Reset options")
modal.opts.on_accept()
assert(card.RtProfile=="Default" and card.OverlayFPS=="no")
local bad_overlay,bad_overlay_err=actions["game.set_overlay"].run("OverlaySecret",true)
assert(bad_overlay==false and tostring(bad_overlay_err):match("unknown game overlay"))
print("Game screen NEXUS actions: all tests passed")
