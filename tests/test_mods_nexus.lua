-- Run with: luajit tests/test_mods_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local saved, initial_off = {}, {}
local categories = {
    {id="textures",label="Textures",short="TEXTURES",icon="mods",acc="gc"},
    {id="wii_sd",label="Wii SD",short="WII SD",icon="folder",acc="wii"},
    {id="riivolution",label="Riivolution",short="RIIVOLUTION",icon="file",acc="boost"},
    {id="dynamic_input",label="Dynamic Input",short="INPUT",icon="gear",acc="hot"},
}
local rows_by_category = {
    textures={{name="HD Textures",kind="id"},{name="Shader Pack",kind="prefix"}},
    wii_sd={},riivolution={},dynamic_input={},
}
package.preload["ui.kit"] = function()
    return {W=640,H=480,MARGIN=20,BOT=460,ACC={gc={},wii={},boost={},hot={}},C={},
        List=function()
            local l={items={},sel=1}
            function l:set(items) self.items=items; self.sel=1 end
            function l:cur() return self.items[self.sel] end
            function l:update() end
            function l:_aim() end
            return l
        end,
        set_accent=function() end}
end
package.preload["ui.sfx"] = function() return {play=function() end} end
package.preload["ui.util"] = function()
    return {
        vault_titles=function() return {} end,
        vault_off=function() local out={}; for k,v in pairs(initial_off) do out[k]=v end; return out end,
        vault_set_off=function(game,cat,off)
            saved[cat]={}; for k,v in pairs(off) do saved[cat][k]=v end; return true
        end,
    }
end
package.preload["core.mods"] = function()
    return {CATS=categories,KIND_LABEL={id="ID",prefix="PREFIX"},
        for_game=function(cat) return rows_by_category[cat.id] or {} end}
end
package.loaded["ui"]={back=function() end}

local Screen=require("ui.screens.mods")
local actions={}
local UI={register_action=function(id,run,meta)
    if actions[id] then return false,"duplicate action" end
    actions[id]={run=run,meta=meta}; return true
end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"mods.switch_tab","mods.toggle_selected","mods.set_all","mods.state"}) do
    assert(actions[id],"missing action: "..id)
end

Screen.enter({})
local state=actions["mods.state"].run()
assert(state.read_only==true and state.category=="textures")
local blocked,blocked_err=actions["mods.toggle_selected"].run()
assert(blocked==false and tostring(blocked_err):match("read%-only"))
assert(actions["mods.switch_tab"].run("wii_sd"))
assert(actions["mods.state"].run().category=="wii_sd")
local bad,bad_err=actions["mods.switch_tab"].run("missing")
assert(bad==false and tostring(bad_err):match("unknown Mod Vault category"))

Screen.enter({game={id="ABCD01",title="Test Game"}})
state=actions["mods.state"].run()
assert(state.read_only==false and state.enabled_count==2 and state.total_count==2)
assert(actions["mods.toggle_selected"].run())
state=actions["mods.state"].run()
assert(state.enabled==false and saved.textures["HD Textures"]==true)
assert(actions["mods.set_all"].run(false))
state=actions["mods.state"].run()
assert(state.enabled_count==0 and state.total_count==2)
assert(actions["mods.set_all"].run(true))
state=actions["mods.state"].run()
assert(state.enabled_count==2 and state.total_count==2)
local invalid,invalid_err=actions["mods.set_all"].run("yes")
assert(invalid==false and tostring(invalid_err):match("boolean"))
print("Mod Vault NEXUS actions: all tests passed")
