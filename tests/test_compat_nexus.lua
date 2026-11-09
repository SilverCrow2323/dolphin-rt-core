-- Run with: luajit tests/test_compat_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local games = {
    {id="ABCD01",title="Mario",playable_rank=3,system="GC",region="EU",entries={{norm={note="",rating=4}}}},
    {id="ABCD02",title="Zelda",playable_rank=1,system="Wii",region="US",entries={{norm={note="",rating=2}}}},
    {id="ABCD03",title="Metroid",playable_rank=2,system="GC",region="EU",entries={{norm={note="",rating=3}}}},
}
local owned_game={id="ABCD01",title="Mario"}
local loads,navigations=0,{}
package.preload["ui.kit"] = function()
    return {W=640,H=480,MARGIN=20,BOT=460,ACC={sys={},lime={},boost={},hot={},gc={},wii={}},
        C={dim={},ok={},warn={},line={},text={},faint={},surf2={},bad={}},
        List=function()
            local l={items={},sel=1}
            function l:set(items) self.items=items; self.sel=1 end
            function l:cur() return self.items[self.sel] end
            function l:update() end
            function l:_aim() end
            function l:move(d) self.sel=math.max(1,math.min(#self.items,self.sel+d)); return true end
            function l:page() end
        return l end,set_accent=function() end}
end
package.preload["ui.sfx"] = function() return {play=function() end} end
package.preload["ui.util"] = function() return {} end
package.preload["core.library"] = function() return {games={owned_game}} end
package.preload["core.compatibility"] = function()
    return {
        games=games,count=#games,error=nil,
        load=function() loads=loads+1; return true end,
        summary=function(g) return {play_label=g.playable_rank==3 and "Playable" or "Not Playable",
            play_kind="ok",has_fps=false,fps=nil,boot_label="Native",stars=3,rating_text="3.0",n=1,
            profiles="",devices=""} end,
    }
end
package.loaded["ui"]={back=function() end}
local Screen=require("ui.screens.compat_list")
local actions={}
local UI={register_action=function(id,run,meta)
    if actions[id] then return false,"duplicate action" end
    actions[id]={run=run,meta=meta}; return true
end,go=function(name,params) navigations[#navigations+1]={name=name,params=params}; return true end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"compat.refresh","compat.set_filter","compat.set_mine_only",
    "compat.jump_letter","compat.open_selected","compat.state"}) do assert(actions[id],"missing "..id) end

Screen.enter()
local state=actions["compat.state"].run()
assert(state.filter=="all" and state.result_count==3 and state.selected_owned)
assert(actions["compat.open_selected"].run())
assert(navigations[#navigations].name=="game" and navigations[#navigations].params.game==owned_game)
assert(actions["compat.set_filter"].run("not_playable"))
state=actions["compat.state"].run()
assert(state.filter=="not_playable" and state.result_count==1 and state.selected_id=="ABCD02")
local blocked,blocked_err=actions["compat.open_selected"].run()
assert(blocked==false and tostring(blocked_err):match("not in the local library"))
assert(actions["compat.set_mine_only"].run(true))
assert(actions["compat.state"].run().result_count==0)
assert(actions["compat.set_filter"].run("all"))
assert(actions["compat.state"].run().result_count==1)
assert(actions["compat.set_mine_only"].run(false))
assert(actions["compat.state"].run().result_count==3)
local invalid,invalid_err=actions["compat.set_filter"].run("missing")
assert(invalid==false and tostring(invalid_err):match("unknown compatibility filter"))
assert(actions["compat.refresh"].run())
assert(loads==2,"refresh should reload the database")
print("Compatibility NEXUS actions: all tests passed")
