-- Run with: luajit tests/test_cheatdb_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local index_calls, navigations = 0, {}
local games={
    {id="ABCD01",title="Mario"},
}
local index={
    ABCD={boost=true},
    EFGH={boost=false},
    IJKL={boost=true},
}
local titles={ABCD={"Mario",true},EFGH={"Metroid",true},IJKL={"Zelda",true}}
package.preload["ui.kit"] = function()
    return {W=640,H=480,MARGIN=20,BOT=460,ACC={lime={},boost={}},C={},
        List=function()
            local l={items={},sel=1}
            function l:set(items) self.items=items; self.sel=1 end
            function l:cur() return self.items[self.sel] end
            function l:update() end
            function l:_aim() end
            function l:move(d) self.sel=math.max(1,math.min(#self.items,self.sel+d)); return true end
            function l:page() end
            return l
        end,set_accent=function() end}
end
package.preload["ui.sfx"] = function() return {play=function() end} end
package.preload["ui.util"] = function()
    return {title_for=function(id) local t=titles[id]; return t and t[1],t and t[2] end,
        clean_title=function(s) return s end}
end
package.preload["core.rtcheats"] = function()
    return {index=function() index_calls=index_calls+1; return index end}
end
package.preload["core.library"] = function() return {games=games} end
package.loaded["ui"]={back=function() end}
local Screen=require("ui.screens.cheatdb")
local actions={}
local UI={register_action=function(id,run,meta)
    if actions[id] then return false,"duplicate action" end
    actions[id]={run=run,meta=meta}; return true
end,go=function(name,params) navigations[#navigations+1]={name=name,params=params}; return true end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"cheatdb.refresh","cheatdb.set_filter","cheatdb.jump_letter",
    "cheatdb.open_selected","cheatdb.state"}) do assert(actions[id],"missing "..id) end

Screen.enter()
local state=actions["cheatdb.state"].run()
assert(state.filter=="ALL" and state.database_count==3 and state.result_count==3)
assert(state.selected_id=="ABCD" and state.selected_owned and state.selected_boost)
assert(actions["cheatdb.open_selected"].run())
assert(navigations[#navigations].name=="cheats" and navigations[#navigations].params.game_id=="ABCD")
assert(actions["cheatdb.set_filter"].run("boost"))
state=actions["cheatdb.state"].run()
assert(state.result_count==2 and state.filter=="BOOST")
assert(actions["cheatdb.set_filter"].run("mine"))
state=actions["cheatdb.state"].run()
assert(state.result_count==1 and state.selected_owned)
local invalid,invalid_err=actions["cheatdb.set_filter"].run("invalid")
assert(invalid==false and tostring(invalid_err):match("all, boost or mine"))
assert(actions["cheatdb.refresh"].run())
assert(index_calls==2,"refresh should rebuild the database index")
print("Cheat Database NEXUS actions: all tests passed")
