-- Run with: luajit tests/test_settings_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local values = { confirm_quit = false, fx = "lite" }
local scans, card_resets = 0, 0
package.preload["ui.kit"] = function()
    return { W=640,H=480,MARGIN=20,BOT=460,
        ACC={blue={},boost={},teal={},lime={},hot={},gc={}}, C={ok={},warn={}},
        List=function()
            local l={items={},sel=1}
            function l:set(items) self.items=items; self.sel=1 end
            function l:cur() return self.items[self.sel] end
            function l:move(d) self.sel=math.max(1,math.min(#self.items,self.sel+d)); return true end
            function l:update() end
            return l
        end,
        set_accent=function() end }
end
package.preload["ui.sfx"] = function() return {play=function() end} end
package.preload["ui.util"] = function() return {card_reset=function() card_resets=card_resets+1 end} end
package.preload["ui.notify"] = function() return {show=function() end} end
package.preload["core.settings"] = function()
    return {get=function(k) return values[k] end,set=function(k,v) values[k]=v; return true end}
end
package.preload["core.library"] = function()
    return {games={},scan=function() scans=scans+1; return true end}
end
package.preload["core.rtcheats"] = function()
    return {has_boost=function() return false end,missing=function() return {} end,
        library=function() return {} end,sync=function() end}
end
package.preload["core.rtcore_triage"] = function() return {scan=function() return {} end} end
package.preload["core.updater"] = function()
    return {latest=function() return nil end,poll=function() end,check_async=function(cb) if cb then cb({tag="test"}) end end}
end
package.loaded["ui"] = {go=function() return true end,back=function() return true end}

local Screen=require("ui.screens.settings")
local actions={}
local UI={register_action=function(id,run,meta)
    if actions[id] then return false,"duplicate action" end
    actions[id]={run=run,meta=meta}; return true
end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"settings.switch_section","settings.change_selected","settings.run_selected","settings.state"}) do
    assert(actions[id],"missing action: "..id)
end

Screen.enter()
local state=actions["settings.state"].run()
assert(state.section=="LIBRARY" and state.selected=="ROM folders")
local bad,bad_err=actions["settings.switch_section"].run("missing")
assert(bad==false and tostring(bad_err):match("unknown settings section"))
assert(actions["settings.switch_section"].run("DISPLAY"))
Screen.list.sel=3
local changed,change_err=actions["settings.change_selected"].run(1)
assert(changed,change_err)
assert(values.fx=="full","choice action should reuse the setting's setter")
state=actions["settings.state"].run()
assert(state.section=="DISPLAY" and state.selected=="Effects" and state.value=="full")

assert(actions["settings.switch_section"].run("SYSTEM"))
Screen.list.sel=1
assert(actions["settings.change_selected"].run(1))
assert(values.confirm_quit==true,"toggle action should set the selected value")
assert(actions["settings.switch_section"].run("LIBRARY"))
Screen.list.sel=2
assert(actions["settings.run_selected"].run())
assert(scans==1 and card_resets==1,"selected library action should run once")

Screen.list.sel=1
local not_action,not_action_err=actions["settings.run_selected"].run()
assert(not_action==false and tostring(not_action_err):match("not an action"))
print("Settings NEXUS actions: all tests passed")
