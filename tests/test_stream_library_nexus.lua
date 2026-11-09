-- Run with: luajit tests/test_stream_library_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local favs, launches, reloads = {}, 0, 0
local games={
    {app="Mario",title="Mario",kind="gc"},
    {app="Zelda",title="Zelda",kind="wii"},
    {app="Metroid",title="Metroid",kind="gc"},
}
local configured=true
local spawn_result=0
local settings={stream_view=1}
love={graphics={},timer={}}
local old_remove=os.remove
os.remove=function() return true end
package.preload["ui.kit"] = function()
    return {W=640,H=480,MARGIN=20,BOT=460,ACC={gc={},wii={}},C={},
        List=function()
            local l={items={},sel=1}
            function l:set(items) self.items=items; self.sel=1 end
            function l:cur() return self.items[self.sel] end
            function l:update() end
            function l:_aim() end
            return l
        end,set_accent=function() end}
end
package.preload["ui.sfx"] = function() return {play=function() end} end
package.preload["ui.notify"] = function() return {show=function() end} end
package.preload["core.settings"] = function()
    return {get=function(k)return settings[k] end,set=function(k,v)settings[k]=v end}
end
package.preload["core.stream"] = function()
    return {
        games=games,DIR="/tmp/stream-test",s={HOST="host.local"},
        init=function() end,reload=function() reloads=reloads+1; return true end,
        stat=function(app) return {fav=favs[app]==true,plays=app=="Zelda" and 4 or 0,last=app=="Zelda" and 10 or 0} end,
        check_health=function() end,poll_health=function() end,last_result=function() return nil end,
        configured=function() return configured end,
        spawn=function() launches=launches+1; return spawn_result end,
        read=function() return nil end,
        toggle_fav=function(app) favs[app]=not favs[app]; return favs[app] end,
        request_launch=function() return true end,
    }
end
package.preload["core.stream_lib"] = function() return {} end
package.loaded["ui"]={back=function() end,is_root=function() return false end,go=function() return true end,go_instant=function() return true end}

local Screen=require("ui.screens.stream_library")
local actions={}
local UI={register_action=function(id,run,meta)
    if actions[id] then return false,"duplicate action" end
    actions[id]={run=run,meta=meta}; return true
end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"stream_library.refresh","stream_library.set_tab","stream_library.set_view",
    "stream_library.set_filter","stream_library.set_sort","stream_library.select",
    "stream_library.toggle_favourite","stream_library.launch_selected",
    "stream_library.cancel_launch","stream_library.state"}) do assert(actions[id],"missing "..id) end

Screen.enter()
local state=actions["stream_library.state"].run()
assert(state.tab=="library" and state.view=="flow" and state.filter=="all" and state.game_count==3)
assert(actions["stream_library.toggle_favourite"].run())
assert(actions["stream_library.state"].run().favourite==true)
assert(actions["stream_library.set_tab"].run("favourites"))
state=actions["stream_library.state"].run()
assert(state.tab=="favourites" and state.game_count==1 and state.selected_app=="Mario")
assert(actions["stream_library.set_filter"].run("wii"))
assert(actions["stream_library.state"].run().game_count==0)
assert(actions["stream_library.set_filter"].run("all"))
assert(actions["stream_library.set_view"].run("list") and settings.stream_view==3)
assert(actions["stream_library.set_sort"].run("most_played"))
local invalid,invalid_err=actions["stream_library.set_tab"].run("unknown")
assert(invalid==false and tostring(invalid_err):match("library, favourites or recent"))
assert(actions["stream_library.set_tab"].run("library"))
assert(actions["stream_library.select"].run(1))
assert(actions["stream_library.state"].run().selected_app=="Zelda")
assert(actions["stream_library.launch_selected"].run())
assert(launches==1 and actions["stream_library.state"].run().launch_phase=="check")
assert(actions["stream_library.cancel_launch"].run())
spawn_result=256
local spawn_failed,spawn_err=actions["stream_library.launch_selected"].run()
assert(spawn_failed==false and tostring(spawn_err):match("health preflight"))
assert(actions["stream_library.state"].run().launch_phase==nil)
configured=false
local blocked,blocked_err=actions["stream_library.launch_selected"].run()
assert(blocked==false and tostring(blocked_err):match("not configured"))
assert(actions["stream_library.refresh"].run())
assert(reloads==1,"refresh should reload Stream data")
local no_launch,no_launch_err=actions["stream_library.cancel_launch"].run()
assert(no_launch==false and tostring(no_launch_err):match("no Stream launch"))
os.remove=old_remove
print("Stream Library NEXUS actions: all tests passed")
