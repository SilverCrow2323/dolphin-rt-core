-- Run with: luajit tests/test_gamesettings_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local library = { games = {
    { id = "ABCD01", title = "Zelda" },
    { id = "ABCD02", title = "Mario" },
} }
local configs = {
    { file = "Default.ini", active = true },
    { file = "Custom.ini", active = false },
}
local modal_options, navigations = nil, {}
local ui = { go = function(name, params) navigations[#navigations+1]={name=name,params=params}; return true end,
    back = function() return true end }
package.loaded["ui"] = ui
package.preload["ui.kit"] = function()
    return { W=640,H=480,MARGIN=20,BOT=460,ACC={gc={},boost={},wii={}},C={},
        List=function()
            local l={items={},sel=1}
            function l:set(items) self.items=items; self.sel=1 end
            function l:cur() return self.items[self.sel] end
            function l:update() end
            return l
        end,
        set_accent=function() end }
end
package.preload["ui.sfx"] = function() return {play=function() end} end
package.preload["ui.util"] = function() return {clean_title=function(s)return s end} end
package.preload["ui.notify"] = function() return {show=function() end} end
package.preload["ui.modal"] = function() return {show=function(_,_,opts) modal_options=opts end} end
package.preload["core.library"] = function() return library end
package.preload["core.gameset_manager"] = function()
    return {
        list_for=function(id)
            local out={}
            for _,c in ipairs(configs) do out[#out+1]={file=c.file,active=c.active} end
            return out
        end,
        set_active=function(id,file)
            for _,c in ipairs(configs) do c.active=(c.file==file) end
            return true
        end,
        clear_active=function() for _,c in ipairs(configs) do c.active=false end; return true end,
        add=function(id,file)
            for _,c in ipairs(configs) do if c.file==file then return false,"file exists" end end
            configs[#configs+1]={file=file,active=false}; return true
        end,
        delete=function(id,file)
            for i,c in ipairs(configs) do if c.file==file then table.remove(configs,i); return true end end
            return false,"not found"
        end,
    }
end
package.preload["core.gameset_loader"] = function()
    return {
        load=function() return {games={{game="Mario",ids={"ABCD02"}},{game="Zelda",ids={"ABCD01"}}}} end,
        for_game=function() return nil end,
    }
end

local function registrar()
    local actions={}
    local api={register_action=function(id,run,meta)
        if actions[id] then return false,"duplicate action" end
        actions[id]={run=run,meta=meta}; return true
    end}
    return actions,api
end

local Browser=require("ui.screens.gameset_browser")
local ba,bu=registrar()
assert(Browser.register_actions(bu))
for _,id in ipairs({"gameset_browser.refresh","gameset_browser.switch_tab",
    "gameset_browser.open_selected","gameset_browser.state"}) do assert(ba[id],"missing "..id) end
Browser.enter()
Browser.list.sel=2
local selected=ba["gameset_browser.state"].run()
assert(selected.game_id=="ABCD01","fixture selection should be Zelda")
library.games[#library.games+1]={id="ABCD03",title="Alpha"}
assert(ba["gameset_browser.refresh"].run())
assert(ba["gameset_browser.state"].run().game_id=="ABCD01","refresh should preserve selected game")
assert(ba["gameset_browser.switch_tab"].run("database"))
assert(ba["gameset_browser.state"].run().tab=="database")
assert(ba["gameset_browser.open_selected"].run(),"group should expand")
local region_index
for i,row in ipairs(Browser.rows) do if row.kind=="region" then region_index=i; break end end
assert(region_index,"expanded database group should expose region")
Browser.list.sel=region_index
assert(ba["gameset_browser.open_selected"].run())
assert(navigations[#navigations].name=="gameset_explorer")

local Explorer=require("ui.screens.gameset_explorer")
local ea,eu=registrar()
assert(Explorer.register_actions(eu))
for _,id in ipairs({"gameset_explorer.refresh","gameset_explorer.open_selected",
    "gameset_explorer.create","gameset_explorer.set_active_selected",
    "gameset_explorer.request_delete_selected","gameset_explorer.state"}) do assert(ea[id],"missing "..id) end
Explorer.enter({game_id="ABCD01",game_title="Zelda"})
local st=ea["gameset_explorer.state"].run()
assert(st.game_id=="ABCD01" and st.config_file=="Default.ini")
assert(ea["gameset_explorer.open_selected"].run())
assert(navigations[#navigations].name=="rt_editor")
assert(ea["gameset_explorer.set_active_selected"].run())
assert(configs[1].active==false,"active config should be toggled off")
assert(ea["gameset_explorer.request_delete_selected"].run())
assert(type(modal_options)=="table" and type(modal_options.on_accept)=="function",
    "delete action must request confirmation rather than deleting immediately")
modal_options.on_accept()
assert(#configs==1,"confirmed deletion should remove selected config")
assert(ea["gameset_explorer.create"].run())
assert(navigations[#navigations].name=="rt_editor","create action should open new config in editor")
print("GameSettings NEXUS actions: all tests passed")
