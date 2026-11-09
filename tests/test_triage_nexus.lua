-- Run with: luajit tests/test_triage_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local begins, reports = 0, 0
local function new_job()
    return {done=false,score=0,verdict=nil,pass=0,total=3,flavours={
        {id="I",checks={{label="Emulator folder"},{label="Core files"}}},
        {id="II",checks={{label="Bash tools"},{label="Permissions"}}},
        {id="III",checks={{label="Frontend"},{label="Assets"}}},
    }}
end
package.preload["ui.kit"] = function()
    return {set_accent=function() end}
end
package.preload["ui.sfx"] = function() return {play=function() end} end
package.preload["ui.notify"] = function() return {show=function() end} end
package.preload["core.rtcore_triage"] = function()
    return {
        begin=function() begins=begins+1; return new_job() end,
        step=function(job)
            job.done=true; job.score=1; job.verdict="HEALTHY"; job.pass=3
            job.flavours[1].state="ok"; job.flavours[2].state="ok"; job.flavours[3].state="ok"
        end,
        progress=function(job) return job.done and 1 or 0.25 end,
        save_report=function() reports=reports+1; return "/tmp/rtcore-triage.txt" end,
    }
end
package.loaded["ui"]={back=function() end}

local Screen=require("ui.screens.triage")
local actions={}
local UI={register_action=function(id,run,meta)
    if actions[id] then return false,"duplicate action" end
    actions[id]={run=run,meta=meta}; return true
end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"triage.rescan","triage.select_flavour","triage.inspect",
    "triage.select_check","triage.save_report","triage.state"}) do assert(actions[id],"missing "..id) end

Screen.enter()
local state=actions["triage.state"].run()
assert(state.done==false and state.mode=="cards" and begins==1)
local early,early_err=actions["triage.save_report"].run()
assert(early==false and tostring(early_err):match("not complete"))
local invalid,invalid_err=actions["triage.select_flavour"].run(0)
assert(invalid==false and tostring(invalid_err):match("out of range"))
assert(actions["triage.select_flavour"].run(2))
assert(actions["triage.state"].run().selected_flavour=="II")
assert(actions["triage.inspect"].run()==false,"scan must finish before inspection")
Screen.update(0.08)
state=actions["triage.state"].run()
assert(state.done and state.verdict=="HEALTHY")
assert(actions["triage.inspect"].run())
assert(actions["triage.select_check"].run(2))
state=actions["triage.state"].run()
assert(state.mode=="checks" and state.selected_check=="Permissions")
assert(actions["triage.save_report"].run())
assert(reports==1 and actions["triage.state"].run().report_path=="/tmp/rtcore-triage.txt")
assert(actions["triage.rescan"].run())
state=actions["triage.state"].run()
assert(not state.done and state.mode=="cards" and begins==2)
print("Triage NEXUS actions: all tests passed")
