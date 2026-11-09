-- Run with: luajit tests/test_controller_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local files = {
    ["workshop/controller/Default/GCPadNew.ini"] = {
        "[GCPad1]","Device = SDL/0/Gamepad","Buttons/A = `Button 1`","Buttons/B = `Button 0`",
    },
}
local fail_write, writes, navigations = false, 0, {}
local old_popen=io.popen
love={graphics={newImage=function() return nil end}}
package.preload["ui.kit"] = function()
    return {W=640,H=480,MARGIN=20,BOT=460,ACC={gc={},wii={}},C={dim={},text={}},
        List=function()
            local l={items={},sel=1}
            function l:set(items) self.items=items; self.sel=1 end
            function l:cur() return self.items[self.sel] end
            function l:update() end
            function l:move(d) self.sel=math.max(1,math.min(#self.items,self.sel+d)); return true end
            return l
        end,set_accent=function() end}
end
package.preload["ui.sfx"] = function() return {play=function() end} end
package.preload["ui.notify"] = function() return {show=function() end} end
package.preload["core.ini_edit"] = function()
    return {
        read_lines=function(path)
            local src=files[path] or {}
            local out={}; for i,v in ipairs(src) do out[i]=v end; return out
        end,
        set=function(lines,section,key,value)
            local active=false
            for i,line in ipairs(lines) do
                local sec=line:match("^%[([^%]]+)%]")
                if sec then active=(sec==section)
                elseif active and line:match("^%s*"..key:gsub("([^%w])","%%%1").."%s*=") then
                    lines[i]=key.." = "..value; return
                end
            end
            lines[#lines+1]=key.." = "..value
        end,
        write_lines=function(path,lines)
            if fail_write then return false end
            writes=writes+1; files[path]={}; for i,v in ipairs(lines) do files[path][i]=v end; return true
        end,
    }
end
package.loaded["ui"]={back=function() end}
local function registrar(extra)
    local actions={}
    local api={register_action=function(id,run,meta) actions[id]={run=run,meta=meta}; return true end}
    for k,v in pairs(extra or {}) do api[k]=v end
    return actions,api
end

local Map=require("ui.screens.controller_map")
local ma,mu=registrar()
assert(Map.register_actions(mu))
for _,id in ipairs({"controller_map.select","controller_map.start_remap_selected",
    "controller_map.confirm_remap","controller_map.cancel_remap","controller_map.state"}) do
    assert(ma[id],"missing "..id)
end
Map.enter({dir="workshop/controller/Default",name="Default",system="GameCube"})
local state=ma["controller_map.state"].run()
assert(state.mapping_count==2 and state.selected_key=="Buttons/A")
assert(ma["controller_map.start_remap_selected"].run())
assert(Map.raw_pad(2))
state=ma["controller_map.state"].run()
assert(state.capture_phase=="confirm" and state.captured_value=="`Button 2`")
assert(ma["controller_map.confirm_remap"].run())
state=ma["controller_map.state"].run()
assert(state.selected_value=="`Button 2`" and writes==1 and state.capture_phase==nil)

assert(ma["controller_map.start_remap_selected"].run())
assert(Map.raw_pad(3))
fail_write=true
local failed,failed_err=ma["controller_map.confirm_remap"].run()
assert(failed==false and tostring(failed_err):match("could not write"))
state=ma["controller_map.state"].run()
assert(state.selected_value=="`Button 2`","failed write must restore in-memory mapping")
assert(state.capture_phase=="confirm","failed write should leave capture available for retry")
assert(ma["controller_map.cancel_remap"].run())
fail_write=false

-- The profile browser keeps the selected system explicit and delegates opening
-- to the actual mapping editor screen.
package.preload["ui.util"] = function() return {} end
io.popen=function()
    local done=false
    return {lines=function()
        local emitted=false
        return function()
            if not emitted then emitted=true; return "workshop/controller/GameCube/Default/" end
        end
    end,close=function() done=true end}
end
local Profiles=require("ui.screens.controller_profiles")
local opened={}
local pa,pu=registrar({go=function(name,params) opened={name=name,params=params}; return true end})
assert(Profiles.register_actions(pu))
for _,id in ipairs({"controller_profiles.refresh","controller_profiles.switch_system",
    "controller_profiles.open_selected","controller_profiles.state"}) do assert(pa[id],"missing "..id) end
Profiles.enter()
assert(pa["controller_profiles.state"].run().system=="GameCube")
assert(pa["controller_profiles.open_selected"].run())
assert(opened.name=="controller_map" and opened.params.system=="GameCube")
assert(pa["controller_profiles.switch_system"].run("Wii"))
assert(pa["controller_profiles.state"].run().system=="Wii")
local invalid,invalid_err=pa["controller_profiles.switch_system"].run("PS2")
assert(invalid==false and tostring(invalid_err):match("GameCube or Wii"))
io.popen=old_popen
print("Controller NEXUS actions: all tests passed")
