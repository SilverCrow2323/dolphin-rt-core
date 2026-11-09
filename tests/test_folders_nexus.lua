-- Run with: luajit tests/test_folders_nexus.lua
package.path = "dolphin-rtcore-muos/app/Dolphin RtUI/?.lua;" .. package.path

local paths={{path="/roms/Existing",system="GC"}}
local scans,backs=0,0
local old_popen=io.popen
package.preload["ui.kit"] = function()
    return {W=640,H=480,MARGIN=20,BOT=460,ACC={sys={},gc={},wii={}},C={},
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
package.preload["ui.util"] = function()
    return {exists=function(path) return path=="/mnt/sdcard/roms/." end,
        ls=function(path) if path=="/mnt/sdcard/roms" then return {"Games"} end return {} end}
end
package.preload["core.settings"] = function()
    return {
        get=function(k) if k=="rom_paths" then return paths end end,
        add_rom_path=function(path,system)
            for _,p in ipairs(paths) do if p.path==path and p.system==system then return false end end
            paths[#paths+1]={path=path,system=system}; return true
        end,
        remove_rom_path=function(idx) table.remove(paths,idx); return true end,
    }
end
package.preload["core.library"] = function() return {scan=function() scans=scans+1; return true end} end
package.loaded["ui"]={back=function() backs=backs+1; return true end}
io.popen=function(cmd)
    return {read=function() return "d" end,close=function() end}
end

local Screen=require("ui.screens.folders")
local actions={}
local UI={register_action=function(id,run,meta)
    if actions[id] then return false,"duplicate action" end
    actions[id]={run=run,meta=meta}; return true
end,back=function() backs=backs+1; return true end}
local ok,err=Screen.register_actions(UI)
assert(ok,err)
for _,id in ipairs({"folders.refresh","folders.start_browse","folders.open_selected",
    "folders.add_selected","folders.remove_selected","folders.finish","folders.state"}) do
    assert(actions[id],"missing action: "..id)
end

Screen.enter()
local state=actions["folders.state"].run()
assert(state.mode=="set" and state.registered_count==1 and state.selected_is_add)
Screen.list.sel=2
assert(actions["folders.remove_selected"].run())
assert(#paths==0,"selected registered path should be removed")
assert(actions["folders.start_browse"].run())
state=actions["folders.state"].run()
assert(state.mode=="browse" and state.cwd=="/mnt/sdcard/roms")
assert(actions["folders.open_selected"].run())
state=actions["folders.state"].run()
assert(state.cwd=="/mnt/sdcard/roms/Games")
assert(actions["folders.add_selected"].run("GC"))
assert(#paths==1 and paths[1].system=="GC")
local duplicate,duplicate_err=actions["folders.add_selected"].run("GC")
assert(duplicate==false and tostring(duplicate_err):match("already registered"))
assert(actions["folders.add_selected"].run("Wii"))
assert(#paths==2 and paths[2].system=="Wii")
local invalid,invalid_err=actions["folders.add_selected"].run("PS2")
assert(invalid==false and tostring(invalid_err):match("GC or Wii"))
assert(actions["folders.finish"].run())
assert(scans==1 and backs==1,"finish should rescan then navigate back")
io.popen=old_popen
print("ROM Folders NEXUS actions: all tests passed")
